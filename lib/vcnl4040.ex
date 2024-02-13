defmodule Vcnl4040 do
  @moduledoc """
  GenServer driver for Ambient Light Sensor and Prox Sensor combo
  See datasheet: https://www.vishay.com/docs/84274/vcnl4040.pdf
  Implementation notes: https://www.vishay.com/docs/84307/designingvcnl4040.pdf
  """
  use GenServer
  require Logger
  alias Circuits.I2C
  alias Vcnl4040.DeviceConfig
  alias Vcnl4040.State

  @expected_device_addr 0x60
  @expected_device_id <<0x86, 0x01>>
  @device_interrupt_register <<0x0B>>
  @ps_data_register 0x08
  @als_data_register 0x09
  @device_id_register <<0x0C>>

  @doc """
  Start the ambient light/proximity sensor driver

  Options:
  * `:i2c_bus` - defaults to `"i2c-0"`
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl GenServer
  def init(options) do
    state = State.from_options(options)
    {:ok, bus_ref} = I2C.open(state.i2c_bus)
    state = State.set_bus_ref(state, bus_ref)
    # confirm sensor is present and returns correct device ID
    state =
      case I2C.write_read(state.i2c_bus, @expected_device_addr, @device_id_register, 2) do
        {:ok, dev_id} ->
          State.set_valid?(state, dev_id == @expected_device_id)

        _ ->
          State.set_valid?(state, false)
      end

    if state.valid? do
      state.device_config
      |> DeviceConfig.get_all_registers_for_i2c()
      |> Enum.each(fn register_data ->
        I2C.write!(state.bus_ref, @expected_device_addr, register_data)
      end)

      # TODO: Reimplement sensor_check_timer for blockages outside of library

      # Set up interrupt pin
      state =
        if state.interrupt_pin do
          {:ok, interrupt_ref} = Circuits.GPIO.open(@interrupt_pin, :input, pullmode: :pullup)
          :ok = Circuits.GPIO.set_interrupts(interrupt_ref, :both)
          State.set_interrupt(state, interrupt_ref)
        else
          state
        end

      if state.polling_sample_interval do
        :timer.send_interval(state.polling_sample_interval, :sample)
      end

      {:ok, state}
    else
      {:error, :invalid_device}
    end
  end

  @impl GenServer
  def handle_info(:sample, %State{valid?: true} = state) do
    state = sample_sensors(state)

    {:noreply, state}
  end

  def handle_info(:sample, state), do: {:noreply, state}

  def handle_info({:circuits_gpio, pin, timestamp, value}, %State{valid?: true} = state) do
    if pin == state.interrupt_pin do
      process_interrupt(timestamp, value, state)
    else
      Logger.warning(
        "Received unexpected non-interrupt pin message from GPIO pin #{pin}: #{inspect(value)}"
      )

      {:noreply, state}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl GenServer
  def handle_call(:sensor_present?, _from, state) do
    {:reply, state.valid?, state}
  end

  def handle_call(_, _from, %{valid?: false} = state) do
    {:reply, {:error, :no_sensor}, state}
  end

  def handle_call(:get_ambient_light, _from, state) do
    {:reply, state.ambient_light.latest_filtered, state}
  end

  def handle_call(:get_ambient_light_raw, _from, state) do
    {:reply, state.ambient_light.latest_lux, state}
  end

  def handle_call(:get_proximity, _from, state) do
    {:reply, state.proximity.latest_filtered, state}
  end

  def handle_call(:get_proximity_raw, _from, state) do
    {:reply, state.proximity.latest_value, state}
  end

  defp process_interrupt(_timestamp, _value, %State{} = state) do
    # Clear interrupt flag
    _ = I2C.read!(state.bus_ref, @expected_device_addr, @device_interrupt_register)

    state = sample_sensors(state)

    {:noreply, state}
  end

  defp sample_sensors(state) do
    <<raw_als_value::little-16>> =
      I2C.write_read!(state.bus_ref, @expected_device_addr, <<@als_data_register>>, 2)

    # Scale ALS value using the lux-per-step value
    lux_als_value = State.als_sample_to_lux(state, raw_als_value)
    state = State.add_ambient_light_sample(state, lux_als_value)

    proximity_value = get_prox_reading(state.bus_ref)
    state = State.add_proximity_sample(state, proximity_value)

    if state.log_samples do
      Logger.info("""
      == Sample ======================

      -- Ambient Light Sensor --------
      raw: #{raw_als_value}
      lux: #{lux_als_value}
      filtered: #{state.ambient_light.latest_filtered}
      samples: #{inspect(CircularBuffer.to_list(state.ambient_light.readings), charlists: :as_lists)}

      -- Proximity Sensor ------------
      raw: #{proximity_value}
      filtered: #{state.proximity.latest_filtered}
      samples: #{inspect(CircularBuffer.to_list(state.proximity.readings), charlists: :as_lists)}

      """)
    end

    state
  end

  @doc """
  Returns true if the combo prox/light sensor is present and matches the expected device ID.
  Pass optional keyword list with `:i2c_bus` set to change bus used during check.
  """
  @spec sensor_present?() :: boolean
  def sensor_present?() do
    GenServer.call(__MODULE__, :sensor_present?)
  end

  @doc """
  Returns the current filtered reading from the ambient light sensor

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  @spec get_ambient_light_value() :: number() | {:error, :no_sensor | :timeout | :noproc}
  def get_ambient_light_value() do
    GenServer.call(__MODULE__, :get_ambient_light)
  catch
    :exit, {error, _} -> {:error, error}
  end

  @spec get_ambient_light_value(:raw) :: number() | {:error, :no_sensor | :timeout | :noproc}
  def get_ambient_light_value(:raw) do
    GenServer.call(__MODULE__, :get_ambient_light_raw)
  catch
    :exit, {error, _} -> {:error, error}
  end

  def get_proximity_value do
    GenServer.call(__MODULE__, :get_proximity_value)
  catch
    :exit, {error, _} -> {:error, error}
  end

  def get_proximity_value(:raw) do
    GenServer.call(__MODULE__, :get_proximity_value_raw)
  catch
    :exit, {error, _} -> {:error, error}
  end

  defp get_prox_reading(bus_ref) do
    <<prox_reading::little-16>> =
      I2C.write_read!(bus_ref, @expected_device_addr, <<@ps_data_register>>, 2)

    prox_reading
  end
end
