# vcio.ko

[Back to the kernel changes](kernel.md)

## What it's for

[`/dev/vcio`](vcio-device.md) lets userspace talk to the VideoCore firmware through
its mailbox. Three things need it (see [Raspberry Pi tools](rpi-tools.md)):

| Tool | Uses it for |
|---|---|
| `vcgencmd` | Temperature, throttling, clocks, firmware version |
| `vcmailbox` | Raw mailbox calls |
| `rpi-bootc-bootloader tryboot` | Setting the tryboot flag through `vcmailbox` |

## The problem

Fedora's kernel doesn't set `CONFIG_BCM_VCIO`, so there's no `/dev/vcio` at all and those tools
fail.

## What we ship

[`kmod/vcio/vcio.c`](../../kmod/vcio/vcio.c) is the Raspberry Pi downstream driver
(`drivers/char/broadcom/vcio.c`, rpi-6.12.y), with two changes:

| Downstream driver | Our version |
|---|---|
| Binds to a `raspberrypi,vcio` device tree node | Finds the firmware node itself and registers on load, since Fedora's upstream DTBs have no such node |
| Trusts the buffer size from userspace | Checks it first (12 bytes to 1 MB) |

The ioctl interface is unchanged, so `vcgencmd` and `vcmailbox` work as they do on Raspberry Pi OS.

## How it gets loaded

| File | Does |
|---|---|
| [`modules-load.d/vcio.conf`](../../files/usr/lib/modules-load.d/vcio.conf) | Loads `vcio` at boot. With no device tree node, nothing else would. |
| [`60-rpi-vcio.rules`](../../files/usr/lib/udev/rules.d/60-rpi-vcio.rules) | Gives the `video` group access, so `vcgencmd` works without sudo |

It's built against `kernel-devel` for the exact base kernel version, fetched from Koji, and
installed to `/usr/lib/modules/<kver>/extra/vcio.ko`.

## Things to know

- It isn't signed, so it taints the kernel. It still loads because Fedora doesn't set
  `MODULE_SIG_FORCE`.
- If a base image bump changes the kernel API it uses, the build fails on purpose.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
