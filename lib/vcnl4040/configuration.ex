defmodule Vcnl4040.Configuration do
  defstruct registers: %{}

  @registers %{
    # label: {address, byte offset}
    als_conf: {0x00, 0},
    reserved: {0x00, 1},
    als_thdh_l: {0x01, 0},
    als_thdh_m: {0x01, 1},
    als_thdl_l: {0x02, 0},
    als_thdl_m: {0x02, 1},
    ps_conf1: {0x03, 0},
    ps_conf2: {0x03, 1},
    ps_conf3: {0x04, 0},
    ps_ms: {0x04, 1},
    ps_canc_l: {0x05, 0},
    ps_canc_m: {0x05, 1},
    ps_thdl_l: {0x06, 0},
    ps_thdl_m: {0x06, 1},
    ps_thdh_l: {0x07, 0},
    ps_thdh_m: {0x07, 1},
    ps_data_l: {0x08, 0},
    ps_data_m: {0x08, 1},
    als_data_l: {0x09, 0},
    als_data_m: {0x09, 1},
    white_data_l: {0x0A, 0},
    white_data_m: {0x0A, 1},
    reserved_read: {0x0B, 0},
    int_flag: {0x0B, 1},
    id_l: {0x0C, 0},
    id_m: {0x0C, 1}
  }

  @register_labels Map.keys(@registers)

  @write_registers [
    :als_conf,
    :reserved,
    :als_thdh_l,
    :als_thdh_m,
    :als_thdl_l,
    :als_thdl_m,
    :ps_conf1,
    :ps_conf2,
    :ps_conf3,
    :ps_ms,
    :ps_canc_l,
    :ps_canc_m,
    :ps_thdl_l,
    :ps_thdl_m,
    :ps_thdh_l,
    :ps_thdh_m
  ]

  @threshold_registers %{
    als_thdh_l: :als_thdh,
    als_thdh_m: :skip,
    als_thdl_l: :als_thdl,
    als_thdl_m: :skip,
    ps_canc_l: :ps_canc,
    ps_canc_m: :skip,
    ps_thdl_l: :ps_thdl,
    ps_thdl_m: :skip,
    ps_thdh_l: :ps_thdh,
    ps_thdh_m: :skip
  }

  @threshold_pair_labels [
    :als_thdh,
    :als_thdl,
    :ps_canc,
    :ps_thdl,
    :ps_thdh
  ]

  # Only defaults that are not 0x00
  @register_defaults [
    als_conf: 0x01,
    ps_conf1: 0x01,
    id_l: 0x86,
    id_m: 0x01
  ]

  # Ambient Light Sensor, integration time (ms)
  # longer integration time has higher sensitivity
  @als_it %{
    80 => <<0::1, 0::1>>,
    160 => <<0::1, 1::1>>,
    320 => <<1::1, 0::1>>,
    640 => <<1::1, 1::1>>
  }

  # Ambient Light Sensor, persistence
  # number of reading required to trigger
  @als_pers %{
    1 => <<0::1, 0::1>>,
    2 => <<0::1, 1::1>>,
    4 => <<1::1, 0::1>>,
    8 => <<1::1, 1::1>>
  }

  # Ambient Light Sensor, interrupt enable
  @als_int_en %{
    false: <<0::1>>,
    true: <<1::1>>
  }

  # Ambient Light Sensor, shut down
  @als_sd %{
    false: <<0::1>>,
    true: <<1::1>>
  }

  # Proximity sensor, duty
  # Infra-red on / off duty cycle
  # 1/40, 1/80, 1/160, 1/320
  @ps_duty %{
    40 => <<0::1, 0::1>>,
    80 => <<0::1, 1::1>>,
    160 => <<1::1, 0::1>>,
    320 => <<1::1, 1::1>>
  }

  # Proximity sensor, interrupt persistence
  # number of readings required to trigger
  @ps_pers %{
    1 => <<0::1, 0::1>>,
    2 => <<0::1, 1::1>>,
    3 => <<1::1, 0::1>>,
    4 => <<1::1, 1::1>>
  }

  # Proximity sensor, integration time (unit T?)
  @ps_it %{
    :t1 => <<0::1, 0::1, 0::1>>,
    :t1_5 => <<0::1, 0::1, 1::1>>,
    :t2 => <<0::1, 1::1, 0::1>>,
    :t2_5 => <<0::1, 1::1, 1::1>>,
    :t3 => <<1::1, 0::1, 0::1>>,
    :t3_5 => <<1::1, 0::1, 1::1>>,
    :t4 => <<1::1, 1::1, 0::1>>,
    :t8 => <<1::1, 1::1, 1::1>>
  }

  # Proximity sensor, shut down
  @ps_sd %{
    false: <<0::1>>,
    true: <<1::1>>
  }

  # Proximity sensor, high definition
  # 12 or 16 bit proximity sensor output
  @ps_hd %{
    12 => <<0::1>>,
    16 => <<1::1>>
  }

  # Proximity sensor, interrupt setting
  @ps_int %{
    :disable => <<0::1, 0::1>>,
    :close => <<0::1, 1::1>>,
    :away => <<1::1, 0::1>>,
    :both => <<1::1, 1::1>>
  }

  # Proximity sensor, multi-pulse numbers
  @ps_mps %{
    1 => <<0::1, 0::1>>,
    2 => <<0::1, 1::1>>,
    4 => <<1::1, 0::1>>,
    8 => <<1::1, 1::1>>
  }

  # Proximity sensor, "smart" persistence
  @ps_smart_pers %{
    false: <<0::1>>,
    true: <<1::1>>
  }

  # Proximity sensor, active force enable
  @ps_af %{
    false: <<0::1>>,
    true: <<1::1>>
  }

  # Proximity sensor, active force trigger
  # if active force is enabled, setting this triggers
  # a proximity check
  # this value is then reset to zero
  @ps_trig %{
    false: <<0::1>>,
    true: <<1::1>>
  }

  # Proximity sensor, enable sunlight cancellation
  @ps_sc_en %{
    false: <<0::1>>,
    true: <<1::1>>
  }

  # Proximity sensor, white channel enable
  @white_en %{
    false: <<0::1>>,
    true: <<1::1>>
  }

  # Proximity sensor, detection logic mode enable
  # This will prevent Ambient Light Interrupts and
  # provide specific close/away information as
  # interrupts
  @ps_ms %{
    normal: <<0::1>>,
    detection: <<1::1>>
  }

  # LED current selection / LED intensity (mA)
  @led_i %{
    50 => <<0::1, 0::1, 0::1>>,
    75 => <<0::1, 0::1, 1::1>>,
    100 => <<0::1, 1::1, 0::1>>,
    120 => <<0::1, 1::1, 1::1>>,
    140 => <<1::1, 0::1, 0::1>>,
    160 => <<1::1, 0::1, 1::1>>,
    180 => <<1::1, 1::1, 0::1>>,
    200 => <<1::1, 1::1, 1::1>>
  }

  @reserved_zero <<0::1>>
  @threshold_max 65535
  @threshold_min 0

  alias __MODULE__, as: C

  def new do
    %C{}
  end

  def set!(%C{} = c, {register, value})
      when (register in @register_labels or register in @threshold_pair_labels) and
             is_binary(value) do
    case value do
      <<_::16>> ->
        %C{registers: Map.put(c.registers, register, value)}

      <<_::8>> ->
        %C{registers: Map.put(c.registers, register, value)}
    end
  end

  defp register_to_binary(%C{} = c, label) when label in @write_registers do
    case @threshold_registers[label] do
      # Not a threshold register (they are a full 16 bit)
      nil ->
        regular_register_value(c, label)

      :skip ->
        # Empty binary, the other part will provide the full 16 bits
        <<>>

      register_key ->
        threshold_register_value(c, register_key)
    end
  end

  def get_register_for_i2c(%C{} = c, label) when label in @write_registers do
    {address, _offset} = @registers[label]

    payload =
      @registers
      |> Enum.filter(fn {_reg, {addr, _}} ->
        addr == address
      end)
      |> Enum.sort_by(fn {_reg, {_addr, pos}} -> pos end, :asc)
      |> Enum.map(fn {register, _} ->
        register_to_binary(c, register)
      end)
      |> IO.iodata_to_binary()

    <<address::8, payload::binary>>
  end

  @doc """
  Ambient Light Sensor configuration.

  Returns binary ready to write to register.
  """
  @spec als_conf(
          integration_time_ms :: 80 | 160 | 320 | 640,
          persistence_times :: 1 | 2 | 4 | 8,
          enable_interrupt? :: boolean(),
          shut_down? :: boolean()
        ) :: {:als_conf, binary()}
  def als_conf(als_it \\ 80, als_pers \\ 1, als_int_en \\ false, als_sd \\ true) do
    {:als_conf,
     <<
       f(@als_it, als_it)::bitstring,
       @reserved_zero::bitstring,
       @reserved_zero::bitstring,
       f(@als_pers, als_pers)::bitstring,
       f(@als_int_en, als_int_en)::bitstring,
       f(@als_sd, als_sd)::bitstring
     >>}
  end

  def reserved do
    {:reserved, <<0::8>>}
  end

  defguard is_threshold(value) when value <= @threshold_max and value >= @threshold_min

  @doc """
  Sets high threshold for Ambient Light Sensor interrupt.

  Alias for `als_thdh` with better name.

  Returns a binary ready to write to register.
  """
  @spec als_threshhold_high(high :: non_neg_integer()) :: binary()
  def als_threshhold_high(high \\ 0) when is_threshold(high), do: als_thdh(high)

  @doc """
  Sets high threshold for Ambient Light Sensor interrupt.

  Returns a binary ready to write to register.
  """
  @spec als_thdh(high :: non_neg_integer()) :: binary()
  def als_thdh(high \\ 0) when is_threshold(high) do
    {:als_thdh, <<high::little-16>>}
  end

  @doc """
  Sets low threshold for Ambient Light Sensor interrupt.

  Alias for `als_thdl` with better name.

  Returns a binary ready to write to register.
  """
  @spec als_threshhold_high(high :: non_neg_integer()) :: binary()
  def als_threshhold_low(low \\ 0) when is_threshold(low), do: als_thdl(low)

  @doc """
  Sets low threshold for Ambient Light Sensor interrupt.

  Returns a binary ready to write to register.
  """
  @spec als_thdh(high :: non_neg_integer()) :: binary()
  def als_thdl(low \\ 0) when is_threshold(low) do
    {:als_thdl, <<low::little-16>>}
  end

  @doc """
  Proximity sensor configuration, part 1.

  Duty cycle is 1/40, 1/80, 1/160, 1/320.

  Returns a binary ready to write to register.
  """
  @spec ps_conf1(
          duty_cycle :: 40 | 80 | 160 | 320,
          persistance_times :: 1 | 2 | 3 | 4,
          integration_time :: :t1 | :t1_5 | :t2 | :t2_5 | :t3 | :t3_5 | :t4 | :t8,
          shutdown? :: boolean()
        ) :: {:ps_conf1, binary()}
  def ps_conf1(ps_duty \\ 40, ps_pers \\ 1, ps_it \\ :t1, ps_sd \\ true) do
    {:ps_conf1,
     <<
       f(@ps_duty, ps_duty)::bitstring,
       f(@ps_pers, ps_pers)::bitstring,
       f(@ps_it, ps_it)::bitstring,
       f(@ps_sd, ps_sd)::bitstring
     >>}
  end

  @doc """
  Proximity sensor configuration, part 2

  Returns a binary ready to write to register.
  """
  @spec ps_conf2(
          definition_bits :: 12 | 16,
          interrupt_mode :: :disable | :close | :away | :both
        ) :: {:ps_conf2, binary()}
  def ps_conf2(ps_hd \\ 12, ps_int \\ :disable) do
    {:ps_conf2,
     <<
       @reserved_zero::bitstring,
       @reserved_zero::bitstring,
       @reserved_zero::bitstring,
       @reserved_zero::bitstring,
       f(@ps_hd, ps_hd)::bitstring,
       @reserved_zero::bitstring,
       f(@ps_int, ps_int)::bitstring
     >>}
  end

  @doc """
  Proximity sensor configuration, part 3

  Returns a binary ready to write to register.
  """
  @spec ps_conf3(
          multi_pulse_count :: 1 | 2 | 4 | 8,
          smart_persistence? :: boolean(),
          active_force_mode? :: boolean(),
          active_force_trigger :: boolean(),
          sunlight_cancellation? :: boolean()
        ) :: {:ps_conf3, binary()}
  def ps_conf3(
        ps_mps \\ 1,
        ps_smart_pers \\ false,
        ps_af \\ false,
        ps_trig \\ false,
        ps_sc_en \\ false
      ) do
    {:ps_conf3,
     <<
       @reserved_zero::bitstring,
       f(@ps_mps, ps_mps)::bitstring,
       f(@ps_smart_pers, ps_smart_pers)::bitstring,
       f(@ps_af, ps_af)::bitstring,
       f(@ps_trig, ps_trig)::bitstring,
       @reserved_zero::bitstring,
       f(@ps_sc_en, ps_sc_en)::bitstring
     >>}
  end

  @doc """
  Proximity sensor - More Settings?

  ps_ms means detection logic mode, it will disable ALS interrupts.

  Returns a binary ready to write to register.
  """
  @spec ps_ms(
          white_channel? :: boolean(),
          detection_logic_mode? :: :normal | :detection,
          led_intensity_ma :: 50 | 75 | 100 | 120 | 140 | 160 | 180 | 200
        ) :: {:ps_ms, binary()}
  def ps_ms(white_en \\ false, ps_ms \\ :normal, led_i \\ 50) do
    {:ps_ms,
     <<
       f(@white_en, white_en)::bitstring,
       f(@ps_ms, ps_ms)::bitstring,
       @reserved_zero::bitstring,
       @reserved_zero::bitstring,
       @reserved_zero::bitstring,
       f(@led_i, led_i)::bitstring
     >>}
  end

  def ps_cancellation(value \\ 0) when is_threshold(value), do: ps_canc(value)

  def ps_canc(value \\ 0) when is_threshold(value) do
    {:ps_canc, <<value::little-16>>}
  end

  def ps_threshold_high(high \\ 0) when is_threshold(high), do: ps_thdh(high)

  def ps_thdh(high \\ 0) when is_threshold(high) do
    {:ps_thdh, <<high::little-16>>}
  end

  def ps_threshold_low(low \\ 0) when is_threshold(low), do: ps_thdl(low)

  def ps_thdl(low \\ 0) when is_threshold(low) do
    {:ps_thdl, <<low::little-16>>}
  end

  defp regular_register_value(c, register) do
    case c.registers[register] do
      nil -> <<_::8>> = default(register)
      <<_::8>> = value -> value
    end
  end

  defp threshold_register_value(c, register_key) do
    case c.registers[register_key] do
      # blank 16 bits
      nil -> <<0::16>>
      <<_::16>> = value -> value
    end
  end

  defp default(register) do
    case @register_defaults[register] do
      nil -> <<0::8>>
      value -> <<value::8>>
    end
  end

  defp f(values, key), do: Map.fetch!(values, key)

  # Slight crime, a couple of functions that uses module attributes
  # and that are really only good if you are doing tests
  if Mix.env() == :test do
    def values do
      %{
        als_conf: [@als_it, @als_pers, @als_int_en, @als_sd],
        reserved: [],
        als_thdh: [:uint16le],
        als_thdl: [:uint16le],
        ps_conf1: [@ps_duty, @ps_pers, @ps_it, @ps_sd],
        ps_conf2: [@ps_hd, @ps_int],
        ps_conf3: [@ps_mps, @ps_smart_pers, @ps_af, @ps_trig, @ps_sc_en],
        ps_ms: [@white_en, @ps_ms, @led_i],
        ps_canc: [:uint16le],
        ps_thdh: [:uint16le],
        ps_thdl: [:uint16le]
      }
      # Make them consistently ordered
      |> Enum.map(fn {field, arg_values} ->
        {field,
         case arg_values do
           [:uint16le] -> [[@threshold_min, @threshold_max]]
           items -> Enum.map(items, &Map.keys/1)
         end}
      end)
    end

    def to_detailed_binaries(%C{} = c) do
      @write_registers
      |> Enum.map(fn register ->
        binary = register_to_binary(c, register)
        {register, binary}
      end)
    end
  end
end
