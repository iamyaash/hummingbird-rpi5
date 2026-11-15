# xfsprogs

[Back to what we added](packages.md)

## Why we need it

The SD card's `boot` (p2) and `root` (p3) partitions are XFS. The base image's kernel can mount
XFS, but it has no XFS tools at all:

| Tool | Base image | hummingbird-rpi5 |
|---|---|---|
| `mkfs.ext4`, `mkfs.vfat` | Yes | Yes |
| `mkfs.xfs` | No | Yes |
| `xfs_growfs` | No | Yes |
| `xfs_repair` | No | Yes |

## What it's used for

| Tool | Used for |
|---|---|
| `xfs_growfs` | cloud-init grows the root filesystem with it on first boot. See [cloud-init](cloud-init.md). |
| `mkfs.xfs` | Making new XFS filesystems on the Pi. The SD card image itself is made on the build host by [`build-sd-image.sh`](../../scripts/build-sd-image.sh), with the host's own `mkfs.xfs`. |
| `xfs_repair` | Fixing the filesystem if a power cut damages it |

## How we found this

When we tried to install the base image to a VM with `bcvk --filesystem xfs`, it failed at
"Creating rootfs: No such file or directory", because `mkfs.xfs` wasn't there. With
`--filesystem ext4` it worked.

## Related

The initramfs also needs the `xfs` module to mount root at boot. That's added in
[`30-rpi.conf`](../../files/usr/lib/dracut/dracut.conf.d/30-rpi.conf), along with the SD card
drivers.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
