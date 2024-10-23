# Changelog

## v0.1.7

Remove rounding of lux values to provide significantly more detailed precision. Expect floats.

## v0.1.6

Removed unintentional warning that would make a lot of noise in logs.

## v0.1.5

Add termination callback to clean up GPIO and I2C references held via Circuits when GenServer closes. They could easily get jammed.

Add adaptive dynamic interrupt handling using a tolerance mechanism. See README for details.

## v0.1.4

Add graceful error output on failing to set up interrupt pin. This is better than dying in a weirdly quiet way due to a match error.

Added a changelog.
