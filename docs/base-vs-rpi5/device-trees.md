# Device trees

[Back to base vs rpi5](README.md)

## What they are

A device tree (`.dtb`) tells the kernel what hardware the board has and where it is: the UARTs, the
SD controller, the WiFi chip and so on. On the Pi, the firmware picks the DTB for the board and
hands it to the kernel.

## The problem

The Fedora kernel ships upstream Pi 5 DTBs, but in the wrong place and under the wrong name for the
Pi firmware:

| | Fedora kernel | What the Pi setup expects |
|---|---|---|
| Where | `/usr/lib/modules/<kver>/dtb/broadcom/` | `/usr/share/raspberrypi2-kernel*/<kver>/boot/`, where [rpi-bootc-bootloader](rpi-bootc-bootloader.md) copies from |
| D0 stepping name | `bcm2712-d-rpi-5-b.dtb` | `bcm2712d0-rpi-5-b.dtb`, the name the firmware looks for |

## What we change

The [`Containerfile`](../../Containerfile) copies the two Pi 5 DTBs into
`/usr/share/raspberrypi2-kernel-fedora/<kver>/boot/`:

| From | Installed as |
|---|---|
| `bcm2712-rpi-5-b.dtb` | `bcm2712-rpi-5-b.dtb` |
| `bcm2712-d-rpi-5-b.dtb` | `bcm2712d0-rpi-5-b.dtb` |

Both are patched on the way in to add the fan.

## The fan patch

The upstream DTBs enable the RP1 PWM (`rp1_pwm1`) and mux the fan pin (GPIO45) to it, but they
have no `pwm-fan` node, and `cpu_thermal` only has the 110 C critical trip. Nothing claims the PWM
channel, so the pin stays low and the fan (fan header or Active Cooler) runs at full speed.

[`dts/rpi5-fan.dtso`](../../dts/rpi5-fan.dtso) adds what's missing, with the values from the
Raspberry Pi downstream `bcm2712-rpi-5-b.dts`:

| What | Value |
|---|---|
| `pwm-fan` node | `/pwm-fan`, label `fan` |
| `pwms` | `rp1_pwm1` channel 3, period 41566 ns (about 24 kHz), inverted polarity |
| `cooling-levels` | `0 75 125 175 250` (off, then about 30, 50, 70 and 100 percent) |
| Active trips in `cpu_thermal` | 50, 60, 67.5 and 75 C, each with 5 C of hysteresis |
| Cooling maps | Each trip sets the fan to the next level (1 to 4) |

Not taken from downstream: the tach read-out (`rpm-regmap`, which upstream `pwm-fan` doesn't
have), `cooling-min-state`/`cooling-max-state` (upstream works them out from `cooling-levels`) and
the map on the critical trip (the fan is already at full speed from 75 C).

How it's applied: a `dtb-build` stage in the [`Containerfile`](../../Containerfile) compiles the
overlay and runs [`scripts/fan-dtb.sh`](../../scripts/fan-dtb.sh) `apply` on each DTB. That runs
`fdtoverlay` and then checks the result. `dtc` is only in that stage, not in the image. The
patched DTBs are installed in the same place as before, so rpi-bootc-bootloader, tryboot and
rollback work as before, and each deployment carries its own patched DTB.

The overlay refers to labels in the base DTB (`rp1_pwm1`, `thermal_trips`, `cooling_maps`), so it
needs the base's `__symbols__`. Fedora builds its DTBs with `-@`, so they're there (checked on
`7.3.3-200.fc44`). If a later kernel drops them, `fdtoverlay` fails and so does the build.

The build also fails if a DTB is missing, if the check finds a wrong value, or if the base DTB
already has a `pwm-fan` node or cooling maps. That last one means upstream has the fan now: drop
the overlay and the `dtb-build` stage, and keep `scripts/fan-dtb.sh check` to test the DTBs.

[`tests/fan-dtb/run.sh`](../../tests/fan-dtb/run.sh) runs the patch against unpatched DTBs from
the base image. It needs `dtc`.

### Fan level 0 and the udev rule

At fan level 0 (`pwm1` 0), `pwm-fan` switches the PWM off by default (`pwm1_enable` 1). A
switched-off RP1 PWM drops the pin low, and the fan reads a low pin as full speed. So without a
fix, the fan runs flat out whenever the CPU is below the first trip.

[`60-rpi-fan.rules`](../../files/usr/lib/udev/rules.d/60-rpi-fan.rules) sets `pwm1_enable` to 2
when the `pwmfan` hwmon device shows up. In that mode `pwm-fan` keeps the PWM on at 0% duty, which
with inverted polarity holds the pin high, so the fan stops. There's no device tree property for
this mode, so it has to be set from userspace.

To check it on the Pi:

```
cat /sys/class/hwmon/hwmon*/pwm1_enable       # 2
sudo cat /sys/kernel/debug/pwm | grep -A1 pwm-3  # enabled, even at 0/41566 ns
```

## Things to know

- They're the upstream DTBs (plus the fan patch), not the Raspberry Pi downstream ones. That's why
  [`vcio.ko`](vcio-ko.md) had to be changed: upstream has no `raspberrypi,vcio` node.
- No overlays are shipped. The downstream overlays don't match the upstream DTBs.
- Old DTBs stay on the FAT partition after a kernel change. See [known issues](../known-issues.md).

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
