defmodule VCNL4040.State do
  @moduledoc false

  alias VCNL4040.DeviceConfig
  @default_sample_interval 1000
  @default_buffer_size 9

  require Logger

  defstruct i2c_bus: nil,
            notify_pid: nil,
            valid?: false,
            interrupt_pin: nil,
            bus_ref: nil,
            device_config: nil,
            interrupt_ref: nil,
            polling_sample_interval: @default_sample_interval,
            i2c_retries: 0,
            ambient_light: %{
              enable?: true,
              integration_time: 80,
              readings: nil,
              latest_raw: 0,
              latest_lux: 0,
              latest_filtered: 0,
              interrupt_tolerance: nil,
              interrupt_base: nil
            },
            proximity: %{
              enable: true,
              integration_time: :t1,
              readings: nil,
              latest_raw: 0,
              latest_filtered: 0
            },
            log_samples?: false

  @als_integration_to_lux_step %{
    80 => 0.12,
    160 => 0.06,
    320 => 0.03,
    640 => 0.015
  }

  alias VCNL4040.State, as: S

  def max_lux(%S{ambient_light: %{integration_time: it}}) do
    65_536 * @als_integration_to_lux_step[it]
  end

  def als_sample_to_lux(%S{ambient_light: %{integration_time: it}}, sample) do
    @als_integration_to_lux_step[it] * sample
  end

  def from_options(options) do
    interrupt_pin = Keyword.get(options, :interrupt_pin, nil)
    buffer_size = Keyword.get(options, :buffer_samples, @default_buffer_size)

    base_device_config =
      DeviceConfig.merge_configs(DeviceConfig.als_for_polling(), DeviceConfig.ps_for_polling())

    %S{
      i2c_bus: Keyword.get(options, :i2c_bus, "i2c-0"),
      notify_pid: Keyword.get(options, :notify_pid, nil),
      device_config: Keyword.get(options, :device_config, base_device_config),
      interrupt_pin: interrupt_pin,
      i2c_retries: Keyword.get(options, :i2c_retries, 0),
      polling_sample_interval: Keyword.get(options, :poll_interval, 1000),
      ambient_light: %{
        enabled?: Keyword.get(options, :als_enable?, true),
        integration_time: Keyword.get(options, :als_integration_time, 80),
        readings: CircularBuffer.new(buffer_size),
        latest_raw: 0,
        latest_lux: 0.0,
        latest_filtered: 0.0,
        interrupt_tolerance: Keyword.get(options, :als_interrupt_tolerance, nil),
        interrupt_base: nil
      },
      proximity: %{
        enabled?: Keyword.get(options, :ps_enable?, true),
        integration_time: Keyword.get(options, :ps_integration_time, :t1),
        readings: CircularBuffer.new(buffer_size),
        latest_raw: 0,
        latest_filtered: 0
      },
      log_samples?: Keyword.get(options, :log_samples?, false)
    }
  end

  def set_bus_ref(%S{} = s, bus_ref), do: %S{s | bus_ref: bus_ref}
  def set_valid(%S{} = s, valid?), do: %S{s | valid?: valid?}
  def set_interrupt_ref(%S{} = s, interrupt_ref), do: %S{s | interrupt_ref: interrupt_ref}

  def add_ambient_light_sample(%S{ambient_light: %{readings: readings} = a} = s, raw_value) do
    lux_value = als_sample_to_lux(s, raw_value)
    readings = CircularBuffer.insert(readings, lux_value)

    filtered_value =
      readings
      |> CircularBuffer.to_list()
      |> get_median()

    %S{
      s
      | ambient_light: %{
          a
          | readings: readings,
            latest_raw: raw_value,
            latest_lux: lux_value,
            latest_filtered: filtered_value
        }
    }
  end

  def add_proximity_sample(%S{proximity: %{readings: readings} = p} = s, value) do
    readings = CircularBuffer.insert(readings, value)

    filtered_value =
      readings
      |> CircularBuffer.to_list()
      |> get_median()

    %S{
      s
      | proximity: %{
          p
          | readings: readings,
            latest_raw: value,
            latest_filtered: filtered_value
        }
    }
  end

  def update_ambient_light_interrupt_base(
        %S{ambient_light: %{interrupt_base: _base}} = state,
        new_base
      ) do
    %S{state | ambient_light: %{state.ambient_light | interrupt_base: new_base}}
  end

  def inspect_reading(%S{} = state) do
    """
      == Sample ======================

      -- Ambient Light Sensor --------
      raw: #{state.ambient_light.latest_raw}
      lux: #{state.ambient_light.latest_lux}
      filtered: #{state.ambient_light.latest_filtered}
      samples: #{inspect(CircularBuffer.to_list(state.ambient_light.readings), charlists: :as_lists)}

      -- Proximity Sensor ------------
      raw: #{state.proximity.latest_raw}
      filtered: #{state.proximity.latest_filtered}
      samples: #{inspect(CircularBuffer.to_list(state.proximity.readings), charlists: :as_lists)}
    """
  end

  defp get_median(list) do
    median_index = length(list) |> div(2)
    Enum.sort(list) |> Enum.at(median_index)
  end
end
