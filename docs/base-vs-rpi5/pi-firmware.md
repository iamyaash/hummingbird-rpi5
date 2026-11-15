# Pi firmware

[Back to the boot changes](boot.md)

## What it is

The Raspberry Pi doesn't use UEFI or GRUB. Its own firmware reads the first FAT partition on the
card, reads `config.txt` there, and loads the kernel, initramfs and device tree that file names.

## Where it comes from

| Package | Gives us | From |
|---|---|---|
| `raspberrypi2-firmware` | The VideoCore firmware files (`bootcode.bin`, `start*.elf`, `fixup*.dat`, `LICENCE.broadcom`) | AlmaLinux el10 |

Only these packages come from the AlmaLinux repo. [`almalinux-rpi.repo`](../../files/etc/yum.repos.d/almalinux-rpi.repo)
uses `includepkgs`, so dnf can't pull anything else from there, including AlmaLinux's kernel.

## How the files get onto the card

| Step | Where | What happens |
|---|---|---|
| 1 | [`Containerfile`](../../Containerfile) | The package puts the files in `/boot`. They're moved to `/usr/lib/ostree-boot/` and `/boot` is emptied, since bootc expects that. |
| 2 | [`build-sd-image.sh`](../../scripts/build-sd-image.sh) | `/usr/lib/ostree-boot/` is copied onto p1 (`CIDATA`), with `config-bootc-common.txt` and the cloud-init seed |
| 3 | First `rpi-bootc-bootloader sync` | Writes `config.txt`, `tryboot.txt` and the first entry folder. See [rpi-bootc-bootloader](rpi-bootc-bootloader.md). |

## The config files on `CIDATA`

| File | Written by | Edit it? |
|---|---|---|
| `config.txt` | rpi-bootc-bootloader, on every sync | No, your changes get overwritten |
| `tryboot.txt` | rpi-bootc-bootloader | No |
| [`config-bootc-common.txt`](../../boot-partition/config-bootc-common.txt) | This repo | Yes. Board-wide settings go here, and `config.txt` includes it. |

`config-bootc-common.txt` turns on the debug UART (`enable_uart=1`) and has no `dtoverlay` lines.
The downstream overlays don't match the upstream DTBs the Fedora kernel uses.

## Things that change because of it

| Change | Why |
|---|---|
| Kernel args use `console=ttyAMA10,115200` instead of `ttyS0` | The Pi 5's debug UART is `ttyAMA10`. See [`00-base.toml`](../../files/usr/lib/bootc/kargs.d/00-base.toml). |
| The kernel is a raw `Image` | The firmware can't boot zboot. See [raw Image](raw-image.md). |
| `bcm2712-d-rpi-5-b.dtb` is installed as `bcm2712d0-rpi-5-b.dtb` | That's the name the firmware looks for |

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
