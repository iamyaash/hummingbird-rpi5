# Initramfs

[Back to base vs rpi5](README.md)

## The problem

The initramfs is the small filesystem the kernel runs first. Its job is to find the real root disk
and mount it. To do that it needs the drivers for the disk and the filesystem.

Fedora builds those drivers as modules, not into the kernel. And the base image's initramfs is
built **host-only**: dracut only puts in what the build machine needs. The build machine isn't a
Pi, so the Pi's SD card drivers are left out.

| Without the fix | With it |
|---|---|
| The initramfs can't see the SD card | It loads the SD card drivers |
| It can't mount the XFS root | It has `xfs` |
| Boot stops waiting for the root device | Boot carries on |

## What we change

The [`Containerfile`](../../Containerfile) rebuilds the initramfs with `--no-hostonly` and adds
the modules listed in [`30-rpi.conf`](../../files/usr/lib/dracut/dracut.conf.d/30-rpi.conf):

| Module | Needed for |
|---|---|
| `mmc_block` | SD card as a block device |
| `sdhci`, `sdhci-pltfm`, `sdhci-brcmstb` | The Pi 5's SD card controller |
| `xfs` | The `boot` and `root` partitions |
| `erofs`, `overlay` | The composefs mount bootc uses for `/` |

After the rebuild, the build lists what's in the initramfs and **fails if any of these modules is
missing**. So a bad initramfs can't ship.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
