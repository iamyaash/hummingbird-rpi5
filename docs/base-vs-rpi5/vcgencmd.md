# vcgencmd

[Back to Raspberry Pi tools](rpi-tools.md)

## What it is

`vcgencmd` asks the VideoCore firmware for information Linux can't see by itself. It's the
usual way to check whether a Pi is too hot or short on power.

It comes from AlmaLinux's `raspberrypi-userland` package and needs [`/dev/vcio`](vcio-device.md).

## Useful commands

These are the ones tested on a Pi 5 with this image:

| Command | Shows |
|---|---|
| `vcgencmd measure_temp` | SoC temperature |
| `vcgencmd get_throttled` | Whether the Pi is throttled or has been short on power |
| `vcgencmd measure_clock arm` | Current CPU clock |
| `vcgencmd measure_volts` | Core voltage |
| `vcgencmd version` | Firmware build date and version |

## Reading `get_throttled`

`throttled=0x0` means all is well. Any other value is a set of bit flags:

| Bit | Value | Means |
|---|---|---|
| 0 | `0x1` | Under-voltage right now |
| 1 | `0x2` | ARM frequency capped right now |
| 2 | `0x4` | Throttled right now |
| 3 | `0x8` | Soft temperature limit right now |
| 16 | `0x10000` | Under-voltage has happened since boot |
| 17 | `0x20000` | Frequency capping has happened since boot |
| 18 | `0x40000` | Throttling has happened since boot |
| 19 | `0x80000` | Soft temperature limit has happened since boot |

`0x50000`, for example, means the power supply dipped at some point and the Pi throttled because
of it. That usually points to a weak power supply.

## On the base image

`vcgencmd` doesn't work on the base image for two reasons: it isn't installed, and even if it
were, there's no `/dev/vcio` to talk through.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
