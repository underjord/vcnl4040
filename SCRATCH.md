# Scratch notes

## Options to implement

- interrupts: Is the GPIO interrupt hooked up at all? Probably :ambient, :proximity and if possible :both

## Control to offer

There are things we can probably change while the thing is active and for some uses this would be necessary.

- Change interrupt thresholds (proximity and ambient), depending on what ambient situation is
- 

## Useful longer range Proximity Sensing

```
alias VCNL4040.DeviceConfig

(DeviceConfig.merge_configs(DeviceConfig.als_for_polling(),DeviceConfig.ps_for_polling())
 |> DeviceConfig.set!(DeviceConfig.ps_conf1(40, 2, :t2, false))
 |> DeviceConfig.set!(DeviceConfig.ps_ms(false, :normal, 200))
 |> VCNL4040.set_device_config()
)
```