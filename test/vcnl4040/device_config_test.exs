defmodule VCNL4040.DeviceConfigTest do
  use ExUnit.Case

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

    # Run all set-calls with no args, should produce identical results
    DeviceConfig.values()
    |> Enum.each(fn {fun, _} ->
      {^fun, <<_bin::binary>>} = res = apply(DeviceConfig, fun, [])
      # Should be unchanged
      new = DeviceConfig.set!(blank, res)
      assert to_binaries(new) == base
    end)

    DeviceConfig.values()
    |> Enum.each(fn {fun, arg_values} ->
      if arg_values != [] do
        first_args = base_arg_values(arg_values)
        {^fun, <<_bin::binary>>} = res = apply(DeviceConfig, fun, first_args)
        first_cfg = DeviceConfig.set!(blank, res)
        first_binary = to_binaries(first_cfg)
        # Might be same or changed from blank/base

        arg_values
        |> Enum.with_index()
        |> Enum.each(fn {arg_value_set, pos} ->
          arg_value_set
          |> Enum.each(fn arg ->
            these_args = List.replace_at(first_args, pos, arg)

            if these_args != first_args do
              {^fun, <<_bin::binary>>} = res = apply(DeviceConfig, fun, these_args)
              this_cfg = DeviceConfig.set!(first_cfg, res)
              this_binary = to_binaries(this_cfg)

              if this_binary == first_binary do
                IO.puts("#{fun} at argument position #{pos} and value #{arg}")
              end

              assert this_binary != first_binary
            end
          end)
        end)
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

  defp base_arg_values(arg_values) do
    arg_values
    |> Enum.map(&List.first/1)
  end

  defp to_binaries(c) do
    c
    |> DeviceConfig.to_detailed_binaries()
    |> Enum.map(fn {_register, binary} -> binary end)
    |> IO.iodata_to_binary()
  end
end
