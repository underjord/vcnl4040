defmodule VCNL4040.DeviceConfigTest do
  use ExUnit.Case
  doctest VCNL4040.DeviceConfig

  alias VCNL4040.DeviceConfig

  test "check default registers generated" do
    assert %DeviceConfig{registers: empty} = e = DeviceConfig.new()
    assert %{} == empty

    assert <<
             # als_conf
             0x01::8,
             # reserved
             0::8,
             # als_thdh
             0::16,
             # als_thdl
             0::16,
             # ps_conf1
             0x01::8,
             # ps_conf2
             0::8,
             # ps_conf3
             0::8,
             # ps_ms
             0::8,
             # ps_canc
             0::16,
             # ps_thdl
             0::16,
             # ps_thdh
             0::16
           >> = to_binaries(e)
  end

  test "generate ps config with interrupts" do
    assert dc = DeviceConfig.ps_with_interrupts(5, 50, :both, 40, 3, :t2)

    assert <<
             # als_conf
             0x01::8,
             # reserved
             0::8,
             # als_thdh
             0::16,
             # als_thdl
             0::16,
             # ps_conf1
             36::8,
             # ps_conf2
             11::8,
             # ps_conf3
             0::8,
             # ps_ms
             0::8,
             # ps_canc
             0::16,
             # ps_thdl
             5::8,
             0::8,
             # ps_thdh
             50::8,
             0::8
           >> = to_binaries(dc)
  end

  test "change a couple of register values" do
    assert %DeviceConfig{registers: empty} = e = DeviceConfig.new()
    assert %{} == empty

    assert <<
             # als_conf
             0x01::8,
             # reserved
             0::8,
             # als_thdh
             0::16,
             # als_thdl
             0::16,
             # ps_conf1
             0x01::8,
             # ps_conf2
             0::8,
             # ps_conf3
             0::8,
             # ps_ms
             0::8,
             # ps_canc
             0::16,
             # ps_thdl
             0::16,
             # ps_thdh
             0::16
           >> = base = to_binaries(e)

    new =
      e
      # Turn proximity sensor on, is off by default
      |> DeviceConfig.update!(:ps_conf1, ps_sd: false, ps_pers: 3)

    assert <<
             # als_conf
             0x01::8,
             # reserved
             0::8,
             # als_thdh
             0::16,
             # als_thdl
             0::16,
             # ps_conf1
             32::8,
             # ps_conf2
             0::8,
             # ps_conf3
             0::8,
             # ps_ms
             0::8,
             # ps_canc
             0::16,
             # ps_thdl
             0::16,
             # ps_thdh
             0::16
           >> = update1 = to_binaries(new)

    refute update1 == base

    new =
      new
      |> DeviceConfig.update!(:ps_conf2, ps_int: :both)

    assert <<
             # als_conf
             0x01::8,
             # reserved
             0::8,
             # als_thdh
             0::16,
             # als_thdl
             0::16,
             # ps_conf1
             32::8,
             # ps_conf2
             0x03::8,
             # ps_conf3
             0::8,
             # ps_ms
             0::8,
             # ps_canc
             0::16,
             # ps_thdl
             0::16,
             # ps_thdh
             0::16
           >> = update2 = to_binaries(new)

    refute update1 == update2

    assert [
             <<0::8, 1::8, 0::8>>,
             <<1::8, 0::8, 0::8>>,
             <<2::8, 0::8, 0::8>>,
             <<3::8, 32::8, 3::8>>,
             <<4::8, 0::8, 0::8>>,
             <<5::8, 0::8, 0::8>>,
             <<6::8, 0::8, 0::8>>,
             <<7::8, 0::8, 0::8>>
           ] =
             new
             |> DeviceConfig.get_all_registers_for_i2c()
  end

  test "check that all options do something" do
    # This test is gnarly and messy, but it is quite reassuring
    assert %DeviceConfig{registers: _empty} = blank = DeviceConfig.new()

    assert <<
             # als_conf
             0x01::8,
             # reserved
             0::8,
             # als_thdh
             0::16,
             # als_thdl
             0::16,
             # ps_conf1
             0x01::8,
             # ps_conf2
             0::8,
             # ps_conf3
             0::8,
             # ps_ms
             0::8,
             # ps_canc
             0::16,
             # ps_thdl
             0::16,
             # ps_thdh
             0::16
           >> = base = to_binaries(blank)

    # Run all set-calls with no args, should produce identical results to defaults
    DeviceConfig.values()
    |> Enum.each(fn {fun, _} ->
      {^fun, <<_bin::binary>>, _cfg} = res = apply(DeviceConfig, fun, [])
      # Should be unchanged
      new = DeviceConfig.set!(blank, res)
      assert to_binaries(new) == base
    end)

    DeviceConfig.values()
    |> Enum.reduce(%{}, fn {fun, arg_values}, seen ->
      case arg_values do
        [{_key, _value} | _] ->
          # Call this config function with only defaults
          {^fun, <<_bin::binary>>, _cfg} = res = apply(DeviceConfig, fun, [])
          first_cfg = DeviceConfig.set!(blank, res)
          first_binary = to_binaries(first_cfg)
          # Might be same or changed from blank/base

          arg_values
          |> Enum.reduce(seen, fn {key, arg_value_set}, seen2 ->
            arg_value_set
            |> Map.keys()
            |> Enum.reduce(seen2, fn arg, seen3 ->
              {^fun, <<_bin::binary>>, _cfg} = res = apply(DeviceConfig, fun, [%{key => arg}])
              this_cfg = DeviceConfig.set!(first_cfg, res)
              this_binary = to_binaries(this_cfg)

              if this_cfg == first_cfg do
                assert this_binary == first_binary
                seen3
              else
                if this_binary == first_binary do
                  IO.puts("#{fun} at field #{key} and value #{arg}")
                end

                # Never before seen!
                if not is_nil(seen3[this_binary]) do
                  IO.puts("#{fun} at field #{key} and value #{arg}")
                end

                assert is_nil(seen3[this_binary])
                assert this_binary != first_binary
                Map.put(seen3, this_binary, this_cfg)
              end
            end)
          end)

        [min, max] when is_integer(min) and is_integer(max) ->
          assert true
          seen

        [] ->
          assert true
          seen
      end
    end)
  end

  test "get register configuration for I2C" do
    c = DeviceConfig.new()

    assert <<
             # als_conf address
             0x00,
             # als_conf section
             0x01::8,
             # reserved section
             0::8
           >> = DeviceConfig.get_register_for_i2c(c, :als_conf)

    assert <<
             # als_conf address
             0x03,
             # ps_conf1
             0x01::8,
             # ps_conf2
             0::8
           >> = DeviceConfig.get_register_for_i2c(c, :ps_conf2)
  end

  test "update device config piece by piece" do
    c = DeviceConfig.new()
    assert c.config[:als_conf] == nil

    assert %DeviceConfig{config: %{als_conf: %{als_it: 320}}} =
             c = DeviceConfig.update!(c, :als_conf, als_it: 320)

    assert <<
             # als_conf address
             0x00,
             # als_conf section
             1::1,
             0::6,
             1::1,
             # reserved section
             0::8
           >> = DeviceConfig.get_register_for_i2c(c, :als_conf)
  end

  defp to_binaries(c) do
    c
    |> DeviceConfig.to_detailed_binaries()
    |> Enum.map(fn {_register, binary} -> binary end)
    |> IO.iodata_to_binary()
  end
end
