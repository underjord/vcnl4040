defmodule VCNL4040 do
  @moduledoc """
  GenServer driver for Ambient Light Sensor and Prox Sensor combo
  See datasheet: https://www.vishay.com/docs/84274/vcnl4040.pdf
  Implementation notes: https://www.vishay.com/docs/84307/designingvcnl4040.pdf


  There is simulator device at some level of completion: https://github.com/elixir-circuits/circuits_sim/blob/main/lib/circuits_sim/device/vcnl4040.ex
  """
  use GenServer
  require Logger
  alias VCNL4040.DeviceConfig
  alias VCNL4040.State
  alias VCNL4040.Hardware

  @doc """
  Start the ambient light/proximity sensor driver

  Options:
  * `:name` - regular GenServer registration name, makes public API functions more convenient if only using one sensor
  * `:i2c_bus` - defaults to `"i2c-0"`
  * `:device_config` - defaults to turning on ambient light sensor and proximity sensor for polling. Pass your own `DeviceConfig` to modify.
  * `:interrupt_pin` - required to enable interrupt-driven sensing, requires the hardware connection for GPIO INT pin set up
  * `:poll_interval` - millisecond interval for polling sensors. Set to `nil` to disable. Default: 1000 (1 second)
  * `:buffer_samples` - size of the internal circular buffer for filtered readings. Default: 9
  * `:als_enable?` - enable the Ambient Light Sensor immediately. Default: true (not hardware default)
  * `:als_integration_time` - integration time for Ambient Light Sensor. Default: 80
  * `:ps_enable?` - enable the Proximity Sensor immediately. Default: true (not hardware default)
  * `:ps_integration_time` - integration time for Proximity Sensor. Default: :t1 (weirdo time units, see data sheet?)
  * `:log_samples?` - always print sample collection to log. Default: false
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    {gen_opts, options} = Keyword.split(options, [:name])
    GenServer.start_link(__MODULE__, options, gen_opts)
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
      |> Hardware.apply_device_config(bus_ref)

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

  def handle_info(:sample, %State{} = state), do: {:noreply, state}

  def handle_info({:circuits_gpio, pin, timestamp, value}, %State{valid?: true} = state) do
    if pin == state.interrupt_pin do
      process_interrupt(timestamp, value, state)
    else
      Logger.warning("Received unexpected pin message from GPIO pin #{pin}: #{inspect(value)}")

      {:noreply, state}
    end
  end

  def handle_info(_message, %State{} = state), do: {:noreply, state}

  @impl GenServer
  def handle_call(:sensor_present?, _from, %State{} = state) do
    {:reply, state.valid?, state}
  end

  def handle_call(_, _from, %{valid?: false} = %State{} = state) do
    {:reply, {:error, :no_sensor}, state}
  end

  def handle_call({:get_ambient_light, :filtered}, _from, %State{} = state) do
    {:reply, state.ambient_light.latest_filtered, state}
  end

  def handle_call({:get_ambient_light, :lux}, _from, %State{} = state) do
    {:reply, state.ambient_light.latest_lux, state}
  end

  def handle_call({:get_ambient_light, :raw}, _from, %State{} = state) do
    {:reply, state.ambient_light.latest_raw, state}
  end

  def handle_call({:get_proximity, :filtered}, _from, %State{} = state) do
    {:reply, state.proximity.latest_filtered, state}
  end

  def handle_call({:get_proximity, :raw}, _from, %State{} = state) do
    {:reply, state.proximity.latest_raw, state}
  end

  def handle_call(:get_device_config, _from, %State{device_config: dc} = state) do
    {:reply, dc, state}
  end

  def handle_call({:set_device_config, %DeviceConfig{} = device_config}, _from, %State{} = state) do
    device_config
    |> DeviceConfig.get_all_registers_for_i2c()
    |> Hardware.apply_device_config(state.bus_ref)

    {:reply, :ok, %State{state | device_config: device_config}}
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

    if state.log_samples? do
      state
      |> State.inspect_reading()
      |> Logger.info()
    end

    state
  end

  defguard is_server(term) when is_pid(term) or is_atom(term) or is_tuple(term)

  @doc """
  Returns true if the combo prox/light sensor is present and matches the expected device ID.
  """
  @spec sensor_present?(GenServer.server()) :: boolean
  def sensor_present?(server \\ __MODULE__) when is_server(server) do
    GenServer.call(server, :sensor_present?)
  catch
    :exit, {error, _} ->
      Logger.error("Failed to check if sensor is present: #{inspect(error)}")
  end

  @light_types [:filtered, :lux, :raw]
  @doc """
  Returns the current filtered reading from the ambient light sensor

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  @spec get_ambient_light_value(GenServer.server(), :filtered | :lux | :raw) ::
          number() | {:error, :no_sensor | :timeout | :noproc}
  def get_ambient_light_value(server \\ __MODULE__, type \\ :filtered)
      when is_server(server) and type in @light_types do
    GenServer.call(server, {:get_ambient_light, type})
  catch
    :exit, {error, _} -> {:error, error}
  end

  @proximity_types [:filtered, :raw]
  def get_proximity_value(server \\ __MODULE__, type \\ :filtered)
      when is_server(server) and type in @proximity_types do
    GenServer.call(server, {:get_proximity, type})
  catch
    :exit, {error, _} -> {:error, error}
  end

  # TODO: Add get_device_config
  def get_device_config(server \\ __MODULE__) when is_server(server) do
    GenServer.call(server, :get_device_config)
  catch
    :exit, {error, _} -> {:error, error}
  end

  def set_device_config(server \\ __MODULE__, %DeviceConfig{} = device_config)
      when is_server(server) do
    GenServer.call(server, {:set_device_config, device_config})
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
