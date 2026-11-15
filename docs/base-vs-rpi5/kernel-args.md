# Kernel args

[Back to base vs rpi5](README.md)

## The problem

bootc reads default kernel args from `/usr/lib/bootc/kargs.d/`. Hummingbird's `00-base.toml`
sets them for a PC:

```text
console=tty1 console=ttyS0,115200n8
```

`ttyS0` is the usual PC serial port. The Pi 5 doesn't have one. Its debug UART (the 3-pin
connector between the HDMI ports) is `ttyAMA10`, so with the base args you get no serial console.

## What we change

We replace the file with our own
[`00-base.toml`](../../files/usr/lib/bootc/kargs.d/00-base.toml):

| Arg | Why |
|---|---|
| `rootwait` | Wait for the SD card to show up before mounting root |
| `console=ttyAMA10,115200` | Kernel and login console on the Pi 5 debug UART |
| `console=tty1` | Console on HDMI too |

The last `console=` entry becomes `/dev/console`, so HDMI gets the interactive output.

The UART also has to be turned on in the firmware. That's `enable_uart=1` in
`config-bootc-common.txt`, see [Pi firmware](pi-firmware.md).

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
