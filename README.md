# VCNL4040

This is a Circuits-based Elixir driver for the VCNL4040. The VCNL4040 is an ambient light and proximity sensor. It uses I2C and GPIO for communication and has a pretty cool set of features.

For details on the hardware consult [the datasheet](https://www.vishay.com/docs/84274/vcnl4040.pdf). There is additional useful detail about the sensor in [the
  implementation notes](https://www.vishay.com/docs/84307/designingvcnl4040.pdf).

I would not consider the API completely stable yet but it is being tested for real world use.

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

## Getting started

If you have I2C hooked up on your device, typically under Nerves:

```
iex> Circuits.I2C.detect_devices() # Use to find the right one, example: "i2c-1"
# .. lots of output, looks for a single device on a single bus, typically
iex> VCNL4040.start_link(i2c_bus: "i2c-1", name: VCNL4040, log_samples?: true)
{:ok, _pid}
iex> VCNL4040.sensor_present?()
true
iex> RingLogger.attach
# You should start seeing the logged samples from the default setup
# because of log_samples?: true
```

With `log_samples?: true` you should get sample output in your logs every second by default.

See `VCNL4040.start_link/1` for more detailed documentation on start options.

See `VCNL4040.DeviceConfig` for more detailed configuration of the hardware.

## Dynamic interrupt threshold

This tries to offload all the work to the device using the built-in interrupt
features. It requires the interrupt pin to be hooked up.

When light changes beyond a certain tolerance it will trigger a sample that
and then it will adapt the thresholds. This has been reliable for me so far in
testing but consider it somewhat experimental.

Exampe:

```elixir
      # This enables interrupts, sets some bogus thresholds and sets 160ms
      # integration time, plenty of options if you read DeviceConfig
      device_config = VCNL4040.DeviceConfig.als_with_interrupts(1000, 1600, 160)
      {:ok, pid} =
        VCNL4040.start_link(
          i2c_bus: "i2c-1",
          notify_pid: self(),
          # Check your pin :)
          interrupt_pin: 6,
          #log_samples?: true,
          # Turn off polling entirely, because that's cool
          poll_interval: nil,
          device_config: device_config,
          als_integration_time: 160,
          # for light in a range between 0-65335 or so
          als_interrupt_tolerance: 500,
          name: VCNL4040
        )

```

## Simulated device

There is a simulated device for the VCNL4040 in [circuits_sim](https://github.com/elixir-circuits/circuits_sim) at some stage of completion. At the time of writing it does not have GPIO interrupt support.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/vcnl4040>.

