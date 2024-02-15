# VCNL4040

This is a Circuits-based Elixir driver for the VCNL4040. The VCNL4040 is an ambient light and proximity sensor. It uses I2C and GPIO for communication and has a pretty cool set of features.

For details on the hardware consult [the datasheet](https://www.vishay.com/docs/84274/vcnl4040.pdf). There is additional useful detail about the sensor in [the
  implementation notes](https://www.vishay.com/docs/84307/designingvcnl4040.pdf).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vcnl4040` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vcnl4040, "~> 0.1.0"}
  ]
end
```

## Simulated device

There is a simulated device for the VCNL4040 in [circuits_sim](https://github.com/elixir-circuits/circuits_sim) at some stage of completion. At the time of writing it does not have GPIO interrupt support.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/vcnl4040>.

