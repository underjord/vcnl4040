defmodule Vcnl4040.ConfigurationTest do
  use ExUnit.Case

  alias Vcnl4040.Configuration, as: Cfg

  test "check default registers generated" do
    assert %Cfg{registers: empty} = e = Cfg.new()
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
        >> = Cfg.to_binaries(e)
  end

  test "check all permutations" do
    assert %Cfg{registers: empty} = blank = Cfg.new()
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
        >> = base = Cfg.to_binaries(blank)

    # Run all set-calls with no args, should produce identical results
    Cfg.values()
    |> Enum.each(fn {fun, _} ->
        {^fun, bin} = res = apply(Cfg, fun, [])
        # Should be unchanged
        new = Cfg.set!(blank, res) 
        assert Cfg.to_binaries(new) == base
    end)

    Cfg.values()
    |> Enum.each(fn {fun, arg_values} ->
        if arg_values != [] do
            first_args = base_arg_values(arg_values)
            {^fun, <<bin :: binary>>} = res = apply(Cfg, fun, first_args)
            first_cfg = Cfg.set!(blank, res) 
            first_binary = Cfg.to_binaries(first_cfg)
            # Might be same or changed from blank/base

            arg_values
            |> Enum.with_index()
            |> Enum.each(fn {arg_value_set, pos} ->
                arg_value_set
                |> Enum.each(fn arg ->
                    these_args = List.replace_at(first_args, pos, arg)
                    if these_args != first_args do
                        {^fun, <<bin :: binary>>} = res = apply(Cfg, fun, these_args)
                        this_cfg = Cfg.set!(first_cfg, res)
                        this_binary = Cfg.to_binaries(this_cfg)
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

  defp base_arg_values(arg_values) do
    arg_values
    |> Enum.map(&List.first/1)
  end
end
