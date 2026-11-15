# The kernel changes

[Back to base vs rpi5](README.md)

hummingbird-rpi5 boots the same Fedora 44 kernel that comes in the base image. We don't patch it
or swap it for the Raspberry Pi kernel. We change the file format so the Pi firmware can load it,
and add two modules Fedora doesn't build.

| Change | Fixes | Built from |
|---|---|---|
| [Raw `Image`](raw-image.md) | The Pi firmware can't boot Fedora's `vmlinuz` | The base image's own `vmlinuz` |
| [`vcio.ko`](vcio-ko.md) | No `/dev/vcio`, so no `vcgencmd`, `vcmailbox` or tryboot | [`kmod/vcio`](../../kmod/vcio/) |
| [`8250_bcm7271.ko`](8250_bcm7271.md) | No Bluetooth on the Pi 5 | [`kmod/bcm7271-uart`](../../kmod/bcm7271-uart/) |

Around the kernel, three more things change:

| Change | Fixes |
|---|---|
| [Device trees](device-trees.md) | The firmware can't find Fedora's Pi 5 DTBs |
| [Kernel args](kernel-args.md) | The console is on `ttyS0`, which the Pi 5 doesn't have |
| [Initramfs](initramfs.md) | It doesn't have the SD card drivers, so root isn't found |

The raw `Image` and both modules come from the `kernel-build` stage of the [`Containerfile`](../../Containerfile). That
stage builds against `kernel-devel` for the exact base kernel version, fetched from Koji. Nothing
else from it ships.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
