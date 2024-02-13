defmodule Vcnl4040.Configuration do
    defstruct registers: %{}

    @registers [
        # label: {address, byte offset}
        als_conf: {0x00, 0},
        reserved: {0x00, 1},
        als_thdh_l: {0x01, 0},
        als_thdh_r: {0x01, 1},
        als_thdl_l: {0x02, 0},
        als_thdl_r: {0x02, 1},
        ps_conf1: {0x03, 0},
        ps_conf2: {0x03, 1},
        ps_conf3: {0x04, 0},
        ps_ms: {0x04, 1},
        ps_canc_l: {0x05, 0},
        ps_canc_m: {0x05, 1},
        ps_thdl_l: {0x06,0},
        ps_thdl_m: {0x06,1},
        ps_thdh_l: {0x07, 0},
        ps_thdh_m: {0x07, 1},
        ps_data_l: {0x08, 0},
        ps_data_m: {0x08, 1},
        als_data_l: {0x09, 0},
        als_data_m: {0x09, 1},
        white_data_l: {0x0a, 0},
        white_data_m: {0x0a, 1},
        reserved: {0x0b, 0},
        int_flag: {0x0b, 1},
        id_l: {0x0c, 0},
        id_m: {0x0c, 1}
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
        640 => <<1::1, 1::1>>,
    }

    # Ambient Light Sensor, persistence
    # number of reading required to trigger
    @als_pers %{
        1 => <<0::1, 0::1>>,
        2 => <<0::1, 1::1>>,
        4 => <<1::1, 0::1>>,
        8 => <<1::1, 1::1>>,
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
        320 => <<1::1, 1::1>>,
    }

    # Proximity sensor, interrupt persistence
    # number of readings required to trigger
    @ps_pers %{
        1 => <<0::1, 0::1>>,
        2 => <<0::1, 1::1>>,
        3 => <<1::1, 0::1>>,
        4 => <<1::1, 1::1>>,
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
        :t8 => <<1::1, 1::1, 1::1>>,
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
        :both => <<1::1, 1::1>>,
    }

    # Proximity sensor, multi-pulse numbers
    @ps_mps %{
        1 => <<0::1, 0::1>>,
        2 => <<0::1, 1::1>>,
        4 => <<1::1, 0::1>>,
        8 => <<1::1, 1::1>>,
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
        200 => <<1::1, 1::1, 1::1>>,
    }

    @reserved_zero <<0::1>>
    @threshold_max 65535
    @threshold_min 0

    @doc """
    Ambient Light Sensor configuration.

    Returns binary ready to write to register.
    """
    @spec als_conf(
        integration_time_ms :: 80 | 160 | 320 | 640,
        persistence_times :: 1 | 2 | 4 | 8,
        enable_interrupt? :: boolean(),
        shut_down? :: boolean()
    ) :: binary()
    def als_conf(als_it \\ 80, als_pers \\ 1, als_int_en \\ true, als_sd \\ false) do
        <<
            f(@als_it, als_it),
            @reserved_zero,
            @reserved_zero,
            f(@als_pers, als_pers),
            f(@als_int_en, als_int_en),
            f(@als_sd, als_sd),
        >>
    end

    def reserved_register do
        <<0::8>>
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
        <<high::little-16>>
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
        <<low::little-16>>
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
    ) :: binary()
    def ps_conf1(ps_duty \\ 40, ps_pers \\ 1, ps_it \\ :t1, ps_sd \\ true) do
        <<
            f(@ps_duty, ps_duty),
            f(@ps_pers, ps_pers),
            f(@ps_it, ps_it),
            f(@ps_sd, ps_sd)
        >>
    end

    @doc """
    Proximity sensor configuration, part 2

    Returns a binary ready to write to register.
    """
    @spec ps_conf2(
        definition_bits :: 12 | 16,
        interrupt_mode :: :disable | :close | :away | :both
    )
    def ps_conf2(ps_hd \\ 12, ps_int \\ :disable) do
        <<
            @reserved_zero,
            @reserved_zero,
            @reserved_zero,
            @reserved_zero,
            f(@ps_hd, ps_hd),
            @reserved_zero,
            f(@ps_int, ps_int)
        >>
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
    )
    def ps_conf3(ps_mps \\ 1, ps_smart_pers \\ false, ps_af \\ false, ps_trig \\ false, ps_sc_en \\ false) do
        <<
            @reserved_zero,
            f(@ps_mps, ps_mps),
            f(@ps_smart_pers, ps_smart_pers),
            f(@ps_af, ps_af),
            f(@ps_trig, ps_trig),
            @reserved_zero,
            f(@ps_sc_en, ps_sc_en)
        >>
    end

    @doc """
    Proximity sensor - More Settings?

    ps_ms means detection logic mode, it will disable ALS interrupts.

    Returns a binary ready to write to register.
    """
    @spec ps_ms(
        white_channel? :: boolean(),
        detection_logic_mode? :: boolean(),
        led_intensity_ma :: 50 | 75 | 100 | 120 | 140 | 160 | 180 | 200
    )
    def ps_ms(white_en \\ false, ps_ms \\ false, led_i \\ 50) do
        <<
            f(@white_en, white_en),
            f(@ps_ms, ps_ms),
            @reserved_zero,
            @reserved_zero,
            @reserved_zero,
            f(@led_i, led_i)
        >>
    end

    def ps_cancellation_high(high \\ 0) when is_threshold(high), do: ps_canc_h(high)

    def ps_canc_h(high \\ 0) when is_threshold(high) do
        <<high::little-16>>
    end

    def ps_cancellation_low(low \\ 0) when is_threshold(low), do: ps_canc_l(low)

    def ps_canc_l(low \\ 0) when is_threshold(low) do
        <<low::little-16>>
    end


    defp f(values, key), do: Map.fetch!(values, key)
end