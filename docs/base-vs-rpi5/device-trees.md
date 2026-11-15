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

## Things to know

- They're the upstream DTBs, not the Raspberry Pi downstream ones. That's why
  [`vcio.ko`](vcio-ko.md) had to be changed: upstream has no `raspberrypi,vcio` node.
- No overlays are shipped. The downstream overlays don't match the upstream DTBs.
- Old DTBs stay on the FAT partition after a kernel change. See [known issues](../known-issues.md).

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
