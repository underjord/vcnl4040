defmodule Vcnl4040 do
  @moduledoc """
  GenServer driver for Ambient Light Sensor and Prox Sensor combo
  See datasheet: https://www.vishay.com/docs/84274/vcnl4040.pdf
  """
  use GenServer
  require Logger
  alias Circuits.I2C

  @expected_device_addr 0x60
  @expected_device_id <<0x86, 0x01>>
  @device_interrupt_register <<0x0B>>
  @interrupt_pin 6

  @als_value_lux_per_step 0.12

  @ps_low_thresh_value 3
  # @ps_low_thresh_value 3000
  @ps_high_thresh_value 7

  @ps_config_register 0x03
  @ps_config_register_2 0x04
  @ps_low_thresh_register 0x06
  @ps_high_thresh_register 0x07
  @ps_data_register 0x08

  @als_config_register 0x00
  @als_low_thresh_register 0x02
  @als_high_thresh_register 0x01
  @als_data_register 0x09

  @sample_interval 1_000
  @samples 9

  # 5 minutes of constant prox "closeness" probably means the sensor is obstructed by something, and therefore will not produce usable data.
  # This timer will fire off an event to the `ActivityState` server disabling it for the rest of the current system's uptime.
  # The timer is set up every time a PS_CLOSE interrupt is caught, and canceled when a PS_AWAY interrupt is caught.
  @check_timer_length_ms 300_000

  @default_state %{
    valid?: false,
    bus_ref: nil,
    interrupt_ref: nil,
    sensor_check_timer: nil,
    als_value_readings: CircularBuffer.new(@samples),
    als_value_filtered: 0,
    log_samples: false
  }

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
    bus_name = Keyword.get(options, :i2c_bus, "i2c-0")

    IO.puts("open i2c")
    {:ok, bus_ref} = I2C.open(bus_name)
    IO.puts("opened i2c")
    interrupt = nil

    # confirm sensor is present and returns correct device ID
    valid? =
      case I2C.write_read(bus_ref, @expected_device_addr, <<0x0C>>, 2) do
        {:ok, dev_id} ->
          dev_id == @expected_device_id

        _ ->
          false
      end

    ps_config = <<
      @ps_config_register,
      #### PS_CONF_1 ####
      # 1/320 Duty Cycle
      1::1,
      1::1,
      # 2 Counts required for INT event
      1::1,
      0::1,
      # 8T integration time (~800us)
      1::1,
      1::1,
      1::1,
      # Enable Prox Sensor
      0::1,
      #### PS_CONF_2 ####
      # reserved
      0::1,
      0::1,
      0::1,
      0::1,
      # 16-bit output
      1::1,
      # reserved
      0::1,
      # no proximity interrupts
      0::1,
      0::1
      # proximity interrupts, both
      # 1::1,
      # 1::1
    >>

    ps_config_2 = <<
      @ps_config_register_2,
      #### PS_CONF3
      # reserved
      0::1,
      # 1 pulse of LED (no multi-pulse)
      0::1,
      0::1,
      # disable "smart" persistence
      0::1,
      # normal operation mode (not one-shot/pulse)
      0::1,
      0::1,
      # reserved
      0::1,
      # enable sunlight cancellation
      1::1,
      #### PS_MS
      # disable white channel
      1::1,
      # normal operation mode with interrupt
      0::1,
      # reserved
      0::1,
      0::1,
      0::1,
      # LED Current = 50mA
      0::1,
      0::1,
      0::1
    >>

    if valid? do
      IO.puts("sensor valid")
      # Configure Prox Sensor Thresholds
      I2C.write!(
        bus_ref,
        @expected_device_addr,
        <<@ps_low_thresh_register, @ps_low_thresh_value::little-16>>
      )

      I2C.write!(
        bus_ref,
        @expected_device_addr,
        <<@ps_high_thresh_register, @ps_high_thresh_value::little-16>>
      )

      I2C.write!(
        bus_ref,
        @expected_device_addr,
        <<@als_low_thresh_register, 100::little-16>>
      )

      I2C.write!(
        bus_ref,
        @expected_device_addr,
        <<@als_high_thresh_register, 300::little-16>>
      )

      I2C.write!(bus_ref, @expected_device_addr, ps_config)
      I2C.write!(bus_ref, @expected_device_addr, ps_config_2)

      # Configure Ambient Light Sensor (Using all default values) NOPE
      # Enable ALS_INT_EN
      als_conf =
        <<
          @als_config_register,
          0::1,
          0::1,
          0::1,
          0::1,
          0::1,
          0::1,
          # Enable Ambient Light Sensor interrupts ALS_INT_EN
          1::1,
          # 0::1, # disabled
          0::1,
          0::1,
          0::1,
          0::1,
          0::1,
          0::1,
          0::1,
          0::1,
          0::1
        >>

      I2C.write!(bus_ref, @expected_device_addr, als_conf)
      # {:ok, _} = :timer.send_interval(@sample_interval, self(), :sample)

      # Read initial prox distance, if beyond threshold start the check timer
      initial_prox_reading = get_prox_reading(bus_ref)

      check_timer =
        if initial_prox_reading > @ps_high_thresh_value do
          Process.send_after(self(), :check_timer_expire, @check_timer_length_ms)
        else
          nil
        end

      IO.puts("configured sensor")

      IO.puts("open GPIO")
      # Set up interrupt pin
      {:ok, interrupt} = Circuits.GPIO.open(@interrupt_pin, :input, pullmode: :pullup)
      IO.puts("set interrupt on GPIO")
      :ok = Circuits.GPIO.set_interrupts(interrupt, :both)
      IO.puts("GPIO ready")

      {:ok,
       %{
         @default_state
         | valid?: true,
           bus_ref: bus_ref,
           interrupt_ref: interrupt,
           # interrupt_ref: nil,
           sensor_check_timer: check_timer,
           log_samples: Keyword.get(options, :log_samples, false)
       }}
    else
      {:error, :invalid_device}
    end

    # rescue
    #   e ->
    #     Logger.error("[Vcnl4040] Error during ambient light and proximity sensor init! Not using it. #{inspect(e)}")
    #     {:ok, @default_state}
  end

  @impl GenServer
  def handle_info(:sample, %{valid?: true} = state) do
    <<raw_als_value::little-16>> =
      I2C.write_read!(state.bus_ref, @expected_device_addr, <<@als_data_register>>, 2)

    # Scale ALS value using the lux-per-step value
    lux_als_value = (raw_als_value * @als_value_lux_per_step) |> round()
    new_readings_als = CircularBuffer.insert(state.als_value_readings, lux_als_value)
    filtered_als = CircularBuffer.to_list(new_readings_als) |> get_median() |> round()

    if state.log_samples do
      Logger.info("""
      Sample:
      raw: #{raw_als_value}
      lux: #{lux_als_value}
      filtered: #{filtered_als}
      samples: #{inspect(CircularBuffer.to_list(new_readings_als), charlists: :as_lists)}

      """)
    end

    current_value = get_prox_reading(state.bus_ref)
    IO.inspect(current_value, label: "sample prox value")

    {:noreply,
     %{
       state
       | als_value_filtered: filtered_als,
         als_value_readings: new_readings_als
     }}
  end

  def handle_info(:sample, state), do: {:noreply, state}

  def handle_info(:check_timer_expire, state) do
    {:noreply, %{state | valid?: false, sensor_check_timer: nil}}
  end

  def handle_info({:circuits_gpio, @interrupt_pin, _timestamp, value}, %{valid?: true} = state) do
    IO.inspect(value, label: "interrupt")
    # <<_, _::6, _::1, _::1>> =
    _ = I2C.read!(state.bus_ref, @expected_device_addr, @device_interrupt_register)

    # # We got an interrupt, so do a quick reading of the actual value
    # current_value = get_prox_reading(state.bus_ref)
    # IO.inspect(current_value, label: "prox value")

    # cond do
    #   ps_close == 1 ->
    #     # TODO: removed call to ActivityState.bump/0 for now
    #     # More tuning needs to be done around the thresholds for proximity values
    #     {:noreply, state}

    #   ps_away == 1 and current_value < @ps_low_thresh_value ->
    #     if state.sensor_check_timer do
    #       _ = Process.cancel_timer(state.sensor_check_timer)
    #       :ok
    #     end

    #     {:noreply, %{state | sensor_check_timer: nil}}

    #   true ->
    #     {:noreply, state}
    # end
    <<raw_als_value::little-16>> =
      I2C.write_read!(state.bus_ref, @expected_device_addr, <<@als_data_register>>, 2)

    # Scale ALS value using the lux-per-step value
    lux_als_value = (raw_als_value * @als_value_lux_per_step) |> round()
    new_readings_als = CircularBuffer.insert(state.als_value_readings, lux_als_value)
    filtered_als = CircularBuffer.to_list(new_readings_als) |> get_median() |> round()

    if state.log_samples do
      Logger.info("""
      Sample:
      raw: #{raw_als_value}
      lux: #{lux_als_value}
      filtered: #{filtered_als}
      samples: #{inspect(CircularBuffer.to_list(new_readings_als), charlists: :as_lists)}

      """)
    end

    current_value = get_prox_reading(state.bus_ref)
    IO.inspect(current_value, label: "interrupt prox value")

    {:noreply,
     %{
       state
       | als_value_filtered: filtered_als,
         als_value_readings: new_readings_als
     }}
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
    {:reply, state.als_value_filtered, state}
  end

  def handle_call(:get_ambient_light_raw, _from, state) do
    {:reply, CircularBuffer.newest(state.als_value_readings), state}
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

  defp get_prox_reading(bus_ref) do
    <<prox_reading::little-16>> =
      I2C.write_read!(bus_ref, @expected_device_addr, <<@ps_data_register>>, 2)

    prox_reading
  end

  defp get_median(list) do
    median_index = length(list) |> div(2)
    Enum.sort(list) |> Enum.at(median_index)
  end
end
