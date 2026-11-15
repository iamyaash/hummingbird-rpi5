# What we added

[Back to base vs rpi5](README.md)

The base image is a minimal server image. It has no firmware, no WiFi or Bluetooth userspace, and
no first-boot setup. These are the packages and config files we add on top.

| Area | Page |
|---|---|
| WiFi firmware and tools | [WiFi](wifi.md) |
| Bluetooth firmware and tools | [Bluetooth](bluetooth.md) |
| First-boot setup | [cloud-init](cloud-init.md) |
| XFS tools | [xfsprogs](xfsprogs.md) |

## Where the packages come from

| Repo file | Packages allowed (`includepkgs`) |
|---|---|
| [`almalinux-rpi.repo`](../../files/etc/yum.repos.d/almalinux-rpi.repo) | `raspberrypi2-firmware`, `linux-firmware-raspberrypi`, `raspberrypi-userland` |
| [`fedora-44-firmware.repo`](../../files/etc/yum.repos.d/fedora-44-firmware.repo) | `linux-firmware`, `linux-firmware-whence`, `brcmfmac-firmware`, `wireless-regdb`, `iw`, `wpa_supplicant`, `bluez`, `cloud-init`, `cloud-utils-growpart`, `xfsprogs`, `jq` |

Both repos use `includepkgs`, so dnf can't pull anything else from them, like a second kernel or a
newer systemd. Anything not on these lists comes from Hummingbird's own repos. Everything is
installed with `install_weak_deps=False` to keep the image small.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
