defmodule Vcnl4040 do
  @moduledoc """
  GenServer driver for Ambient Light Sensor and Prox Sensor combo
  See datasheet: https://www.vishay.com/docs/84274/vcnl4040.pdf
  Implementation notes: https://www.vishay.com/docs/84307/designingvcnl4040.pdf
  """
  use GenServer
  require Logger
  alias Vcnl4040.DeviceConfig
  alias Vcnl4040.State
  alias Vcnl4040.Hardware


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

    {:ok, bus_ref} = Hardware.open(state.i2c_bus)

    state =
      state
      |> State.set_bus_ref(bus_ref)
      |> State.set_valid(Hardware.is_valid?(bus_ref))

    if state.valid? do
      state.device_config
      |> DeviceConfig.get_all_registers_for_i2c()
      |> Enum.each(fn register_data ->
        Hardware.write_register(state.bus_ref, register_data)
      end)

      # TODO: Reimplement sensor_check_timer for blockages outside of library

      # Set up interrupt pin
      state =
        if state.interrupt_pin do
          {:ok, interrupt_ref} = Hardware.setup_interrupts(state.interrupt_pin)
          State.set_interrupt_ref(state, interrupt_ref)
        else
          state
        end

      if state.polling_sample_interval do
        # Start the polling
        poll_me_maybe(state)
      end

      {:ok, state}
    else
      {:error, :invalid_device}
    end
  end

  @impl GenServer
  def handle_info(:sample, %State{valid?: true} = state) do
    state = sample_sensors(state)
    poll_me_maybe(state)

    {:noreply, state}
  end

  def handle_info(:sample, state), do: {:noreply, state}

  def handle_info({:circuits_gpio, pin, timestamp, value}, %State{valid?: true} = state) do
    if pin == state.interrupt_pin do
      process_interrupt(timestamp, value, state)
    else
      Logger.warning(
        "Received unexpected pin message from GPIO pin #{pin}: #{inspect(value)}"
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

  def handle_call(:get_ambient_light_lux, _from, state) do
    {:reply, state.ambient_light.latest_lux, state}
  end

  def handle_call(:get_ambient_light_raw, _from, state) do
    {:reply, state.ambient_light.latest_raw, state}
  end

  def handle_call(:get_proximity, _from, state) do
    {:reply, state.proximity.latest_filtered, state}
  end

  def handle_call(:get_proximity_raw, _from, state) do
    {:reply, state.proximity.latest_raw, state}
  end

  defp process_interrupt(_timestamp, _value, %State{} = state) do
    Hardware.clear_interrupts(state.bus_ref)
    state = sample_sensors(state)

    {:noreply, state}
  end

  defp sample_sensors(state) do
    raw_als_value = Hardware.read_ambient_light(state.bus_ref)
    state = State.add_ambient_light_sample(state, raw_als_value)

    proximity_value = Hardware.read_proximity(state.bus_ref)
    state = State.add_proximity_sample(state, proximity_value)

    if state.log_samples do
      state
      |> State.inspect_reading()
      |> Logger.info()
    end

    state
  end

  @doc """
  Returns true if the combo prox/light sensor is present and matches the expected device ID.
  """
  @spec sensor_present?() :: boolean
  def sensor_present? do
    GenServer.call(__MODULE__, :sensor_present?)
  end

  @doc """
  Returns the current filtered reading from the ambient light sensor

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  @spec get_ambient_light_value :: number() | {:error, :no_sensor | :timeout | :noproc}
  def get_ambient_light_value do
    GenServer.call(__MODULE__, :get_ambient_light)
  catch
    :exit, {error, _} -> {:error, error}
  end

  @spec get_ambient_light_value(:lux) :: number() | {:error, :no_sensor | :timeout | :noproc}
  def get_ambient_light_value(:lux) do
    GenServer.call(__MODULE__, :get_ambient_light_lux)
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

  # We use send_after rather than :timer.send_interval to limit the risk of messaging
  # filling up on slow-down
  defp poll_me_maybe(%State{polling_sample_interval: nil}), do: :ok
  defp poll_me_maybe(%State{polling_sample_interval: interval}) when interval > 0 do
    Process.send_after(self(), :sample, interval)
  end
end
