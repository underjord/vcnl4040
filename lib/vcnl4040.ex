defmodule VCNL4040 do
  @moduledoc """
  GenServer-based driver module for ambient light and proximity sensor combo.

  See datasheet: https://www.vishay.com/docs/84274/vcnl4040.pdf
  Implementation notes: https://www.vishay.com/docs/84307/designingvcnl4040.pdf
  """

  use GenServer
  require Logger
  alias VCNL4040.DeviceConfig
  alias VCNL4040.State
  alias VCNL4040.Hardware

  @threshold_max 65535
  @threshold_min 0

  @doc """
  Start the ambient light/proximity sensor driver

  Options:
  * `:name` - regular GenServer registration name, makes public API functions more convenient if only using one sensor.
  * `:i2c_bus` - defaults to `"i2c-0"`
  * `:notify_pid` - PID to notify on every sample pulled. Default: nil
  * `:device_config` - defaults to turning on ambient light sensor and proximity sensor for polling. Pass your own `DeviceConfig` to modify.
  * `:interrupt_pin` - required to enable interrupt-driven sensing, requires the hardware connection for GPIO INT pin set up
  * `:poll_interval` - millisecond interval for polling sensors. Set to `nil` to disable. Default: 1000 (1 second)
  * `:buffer_samples` - size of the internal circular buffer for filtered readings. Default: 9
  * `:als_enable?` - enable the Ambient Light Sensor immediately. Default: true (not hardware default)
  * `:als_integration_time` - integration time for Ambient Light Sensor. Default: 80
  * `:ps_enable?` - enable the Proximity Sensor immediately. Default: true (not hardware default)
  * `:ps_integration_time` - integration time for Proximity Sensor. Default: :t1 (weirdo time units, see data sheet?)
  * `:log_samples?` - always print sample collection to log. Default: false
  * `:als_interrupt_tolerance` - enables automatic following of light level using interrupts. Default: nil
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    {gen_opts, options} = Keyword.split(options, [:name])
    GenServer.start_link(__MODULE__, options, gen_opts)
  end

  @impl GenServer
  def init(options) do
    state = State.from_options(options)

    case Hardware.open(state.i2c_bus, state.i2c_retries) do
      {:ok, bus_ref} ->
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
          result =
            if state.interrupt_pin do
              case Hardware.setup_interrupts(state.interrupt_pin) do
                {:ok, interrupt_ref} ->
                  {:ok, State.set_interrupt_ref(state, interrupt_ref),
                   {:continue, :setup_interrupt_base}}

                {:error, reason} ->
                  Logger.error(
                    "Could not set up VCNL4040 interrupt pin (#{inspect(state.interrupt_pin)}): #{inspect(reason)}"
                  )

                  {:error, reason}
              end
            else
              {:ok, state}
            end

          if state.polling_sample_interval do
            # Start the polling
            poll_me_maybe(state)
          end

          case result do
            {:ok, state} -> {:ok, state}
            {:ok, state, continue} -> {:ok, state, continue}
            {:error, reason} -> {:error, {:open_interrupt_pin_failed, reason}}
          end
        else
          {:error, :invalid_device}
        end

      {:error, reason} ->
        Logger.error(
          "Could not set up VCNL4040 I2C bus (#{inspect(state.i2c_bus)}): #{inspect(reason)}"
        )

        {:error, {:open_failed, reason}}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    Hardware.close(state.bus_ref, state.interrupt_ref)

    :ok
  end

  @impl GenServer
  def handle_continue(:setup_interrupt_base, state) do
    if state.ambient_light.interrupt_tolerance do
      Hardware.clear_interrupts(state.bus_ref)
      raw_als_value = Hardware.read_ambient_light(state.bus_ref)

      {:noreply, set_interrupt_base_value(state, raw_als_value)}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:sample, %State{valid?: true} = state) do
    state = sample_sensors(state)
    poll_me_maybe(state)

    {:noreply, state}
  end

  def handle_info(:sample, %State{} = state), do: {:noreply, state}

  # Goes low when an interrupt is triggered, match pin identifier
  def handle_info(
        {:circuits_gpio, pin, timestamp, 0},
        %State{valid?: true, interrupt_pin: pin} = state
      ) do
    process_interrupt(timestamp, state)
  end

  # Goes high when reset to allow a new interrupt to happen, match pin identifier
  def handle_info(
        {:circuits_gpio, pin, _timestamp, 1},
        %State{valid?: true, interrupt_pin: pin} = state
      ) do
    # No action, these are expected
    {:noreply, state}
  end

  def handle_info(message, %State{} = state) do
    Logger.warning("Unknown message: #{inspect(message)}")
    {:noreply, state}
  end

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

  def handle_call({:get_ambient_light, :direct}, _from, %State{} = state) do
    {:reply, Hardware.read_ambient_light(state.bus_ref), state}
  end

  def handle_call({:get_proximity, :filtered}, _from, %State{} = state) do
    {:reply, state.proximity.latest_filtered, state}
  end

  def handle_call({:get_proximity, :raw}, _from, %State{} = state) do
    {:reply, state.proximity.latest_raw, state}
  end

  def handle_call({:get_proximity, :direct}, _from, %State{} = state) do
    {:reply, Hardware.read_proximity(state.bus_ref), state}
  end

  def handle_call(:close, _from, %State{} = state) do
    Hardware.close(state.bus_ref, state.interrupt_ref)
    {:stop, :closed, :ok, state}
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

  defp process_interrupt(_timestamp, %State{} = state) do
    state =
      state
      |> sample_sensors()
      |> adjust_ambient_light_tolerances()

    Hardware.clear_interrupts(state.bus_ref)

    {:noreply, state}
  end

  defp sample_sensors(state) do
    raw_als_value = Hardware.read_ambient_light(state.bus_ref)
    state = State.add_ambient_light_sample(state, raw_als_value)

    proximity_value = Hardware.read_proximity(state.bus_ref)
    state = State.add_proximity_sample(state, proximity_value)

    if state.notify_pid do
      send(
        state.notify_pid,
        {:vcnl4040_sample,
         %{
           ambient_light:
             Map.take(state.ambient_light, [:latest_raw, :latest_lux, :latest_filtered]),
           proximity: Map.take(state.proximity, [:latest_raw, :latest_filtered])
         }}
      )
    end

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

  This assumes you registered your GenServer with `name: VCNL4040`.

  Returns a boolean indicating whether the sensor is present.
  """
  @spec sensor_present? :: boolean
  def sensor_present?, do: sensor_present?(__MODULE__)

  @doc """
  Returns true if the combo prox/light sensor is present and matches the expected device ID.
  """
  @spec sensor_present?(GenServer.server()) :: boolean
  def sensor_present?(server) when is_server(server) do
    GenServer.call(server, :sensor_present?)
  catch
    :exit, {error, _} ->
      Logger.error("Failed to check if sensor is present: #{inspect(error)}")
      false
  end

  @light_types [:filtered, :lux, :raw, :direct]
  @doc """
  Returns the current reading from the ambient light sensor

  This assumes you registered your GenServer with `name: VCNL4040`.

  The `type` argument can be:

  * `:filtered` - converted to lux and the median of the samples in the buffer, avoiding outliers.
  * `:lux` - latest read, converted to lux.
  * `:raw` - latest read, straight from the sensor. If you have some weird use for it.

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  @spec get_ambient_light(:filtered | :lux | :raw | :direct) ::
          number() | {:error, :no_sensor | :timeout | :noproc}
  def get_ambient_light(type), do: get_ambient_light(__MODULE__, type)

  @doc """
  Returns the current filtered reading from the ambient light sensor.

  The `type` argument can be:

  * `:filtered` - converted to lux and the median of the samples in the buffer, avoiding outliers.
  * `:lux` - latest read, converted to lux.
  * `:raw` - latest read, straight from the sensor. If you have some weird use for it.

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  @spec get_ambient_light(GenServer.server(), :filtered | :lux | :raw) ::
          number() | {:error, :no_sensor | :timeout | :noproc}
  def get_ambient_light(server, type)
      when is_server(server) and type in @light_types do
    GenServer.call(server, {:get_ambient_light, type})
  catch
    :exit, {error, _} -> {:error, error}
  end

  @doc """
  Tell the driver to shut down open resources and exit.

  This assumes you registered your GenServer with `name: VCNL4040`.

  Returns :ok
  """
  @spec close() :: :ok
  def close(), do: close(__MODULE__)

  @doc """
  Tell the driver to shut down open resources and exit.

  Returns :ok
  """
  @spec close(GenServer.server()) :: :ok
  def close(server) do
    GenServer.call(server, :close)
  end

  @proximity_types [:filtered, :raw, :direct]
  @doc """
  Returns the current reading from the ambient light sensor.

  This assumes you registered your GenServer with `name: VCNL4040`.

  The `type` argument can be:

  * `:filtered` - converted to lux and the median of the samples in the buffer, avoiding outliers.
  * `:raw` - latest read, straight from the sensor. If you have some weird use for it.

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  def get_proximity(type), do: get_proximity(__MODULE__, type)

  @doc """
  Returns the current reading from the ambient light sensor.

  The `type` argument can be:

  * `:filtered` - converted to lux and the median of the samples in the buffer, avoiding outliers.
  * `:raw` - latest read, straight from the sensor. If you have some weird use for it.

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  def get_proximity(server, type)
      when is_server(server) and type in @proximity_types do
    GenServer.call(server, {:get_proximity, type})
  catch
    :exit, {error, _} -> {:error, error}
  end

  @doc """
  Returns the current `VCNL4040.DeviceConfig` struct.

  This assumes you registered your GenServer with `name: VCNL4040`.

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  @spec get_device_config() :: map() | {:error, :no_sensor | :timeout | :noproc}
  def get_device_config, do: get_device_config(__MODULE__)

  @doc """
  Returns the current `VCNL4040.DeviceConfig` struct.

  This assumes you registered your GenServer with `name: VCNL4040`.

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  @spec get_device_config(GenServer.server()) :: map() | {:error, :no_sensor | :timeout | :noproc}
  def get_device_config(server) when is_server(server) do
    GenServer.call(server, :get_device_config)
  catch
    :exit, {error, _} -> {:error, error}
  end

  @doc """
  Sets a new `VCNL4040.DeviceConfig` and applies it to the hardware.

  This assumes you registered your GenServer with `name: VCNL4040`.

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  @spec set_device_config(%DeviceConfig{}) :: :ok | {:error, :no_sensor | :timeout | :noproc}
  def set_device_config(%DeviceConfig{} = device_config),
    do: set_device_config(__MODULE__, device_config)

  @doc """
  Sets a new `VCNL4040.DeviceConfig` and applies it to the hardware.

  Returns `:timeout` or `:noproc` if the GenServer times out or isn't running.
  """
  @spec set_device_config(GenServers.server(), %DeviceConfig{}) ::
          :ok | {:error, :no_sensor | :timeout | :noproc}
  def set_device_config(server, %DeviceConfig{} = device_config)
      when is_server(server) do
    GenServer.call(server, {:set_device_config, device_config})
    :ok
  catch
    :exit, {error, _} -> {:error, error}
  end

  # We use send_after rather than :timer.send_interval to limit the risk of messaging
  # filling up on slow-down
  defp poll_me_maybe(%State{polling_sample_interval: nil}), do: :ok

  defp poll_me_maybe(%State{polling_sample_interval: interval}) when interval > 0 do
    Process.send_after(self(), :sample, interval)
  end

  defp adjust_ambient_light_tolerances(
         %State{
           ambient_light: %{
             latest_raw: raw,
             interrupt_base: base,
             interrupt_tolerance: tolerance
           }
         } = state
       ) do
    if raw > base + tolerance or raw < base - tolerance do
      set_interrupt_base_value(state, raw)
    else
      state
    end
  end

  defp set_interrupt_base_value(
         %State{ambient_light: %{interrupt_tolerance: tolerance}} = state,
         raw
       ) do
    state = State.update_ambient_light_interrupt_base(state, raw)

    device_config =
      state.device_config
      |> DeviceConfig.update!(
        :als_thdh,
        clamp_threshold(raw + tolerance)
      )
      |> DeviceConfig.update!(
        :als_thdl,
        clamp_threshold(raw - tolerance)
      )

    device_config
    |> DeviceConfig.get_all_registers_for_i2c()
    |> Hardware.apply_device_config(state.bus_ref)

    %{state | device_config: device_config}
  end

  defp clamp_threshold(threshold) do
    threshold
    |> min(@threshold_max)
    |> max(@threshold_min)
  end
end
