# Base Hummingbird vs hummingbird-rpi5

## What Hummingbird is

Hummingbird is a set of small, Fedora-based images. The one this project builds on is
`quay.io/hummingbird-community/os-minimal`, a bootc image: a container image that you can
install to a disk and boot, then update with `bootc upgrade`.

It's made for generic UEFI machines (PCs, servers, VMs), not for the Raspberry Pi.

The short version, layer by layer:

| Layer | Base `os-minimal` | What we did | hummingbird-rpi5 |
|---|---|---|---|
| Userspace | systemd, bootc, ostree, NetworkManager, chrony | Kept | Same |
| Kernel | Fedora 44 kernel, zboot `vmlinuz` | Unwrapped, two modules added | [Same Fedora kernel](kernel.md) as a [raw `Image`](raw-image.md), plus [`vcio.ko`](vcio-ko.md) and [`8250_bcm7271.ko`](8250_bcm7271.md) |
| Boot | GRUB, shim, bootupd (UEFI) | Replaced | [Pi firmware](pi-firmware.md) and [rpi-bootc-bootloader](rpi-bootc-bootloader.md) ([why](boot.md)) |
| Firmware and tools | No firmware, no WiFi or Bluetooth userspace | Added | [WiFi](wifi.md) and [Bluetooth](bluetooth.md) firmware and tools, [cloud-init](cloud-init.md), [xfsprogs](xfsprogs.md) ([all of it](packages.md)) |

## What the base has, and why it won't work on a Pi 5

| Base image has | Problem on the Pi 5 | Fix |
|---|---|---|
| GRUB, shim and bootupd | The Pi firmware doesn't boot through UEFI. It reads the kernel straight off the FAT partition. | [Boot](boot.md) |
| `vmlinuz` as an EFI zboot (zstd) file | The Pi firmware can't unpack it. It needs the raw arm64 `Image`. | [Raw Image](raw-image.md) |
| A Fedora kernel without `CONFIG_BCM_VCIO` | There's no [`/dev/vcio`](vcio-device.md), so [`vcgencmd`](vcgencmd.md), [`vcmailbox`](vcmailbox.md) and [tryboot](tryboot.md) don't work. | [`vcio.ko`](vcio-ko.md) |
| A Fedora kernel without `CONFIG_SERIAL_8250_BCM7271` | No driver for the Pi 5's Bluetooth UART, so no `hci0`. | [`8250_bcm7271.ko`](8250_bcm7271.md) |
| DTBs under the wrong path and name | The firmware doesn't find the Pi 5 device tree. | [Device trees](device-trees.md) |
| Kernel args for `ttyS0` | The Pi 5 debug UART is `ttyAMA10`. | [Kernel args](kernel-args.md) |
| A host-only initramfs | It's missing the SD card drivers, so it can't find the root disk. | [Initramfs](initramfs.md) |
| chrony pointed at `2.hummingbird.pool.ntp.org` | It doesn't resolve. The Pi has no battery clock, so HTTPS then fails on certificate dates. | [chrony](chrony.md) |
| No `mkfs.xfs` | The root filesystem is XFS. | [xfsprogs](xfsprogs.md) |
| No firmware, no WiFi or Bluetooth userspace | `brcmfmac` loads but the chip never starts, and there's no `bluez`. | [WiFi](wifi.md), [Bluetooth](bluetooth.md) |
| No first-boot setup | No user, no SSH key, the disk doesn't grow. | [cloud-init](cloud-init.md) |

### WiFi and Bluetooth in the base image

I booted the base image in a VM to check this ([how](base-check.md)). The drivers are in the
kernel, but nothing around them is:

| Part | WiFi | Bluetooth |
|---|---|---|
| Kernel modules | Yes: `cfg80211`, `mac80211`, `brcmfmac` | Yes: `bluetooth`, `hci_uart`, `btbcm` |
| Pi 5 UART driver | Not needed | No: [`8250_bcm7271`](8250_bcm7271.md) is missing |
| Firmware | No: there's no `/usr/lib/firmware` at all | No: same |
| Userspace | No: no `wpa_supplicant`, no `NetworkManager-wifi` | No: no `bluez` |
| Works out of the box? | **No**, see [WiFi](wifi.md) | **No**, see [Bluetooth](bluetooth.md) |

`brcmfmac` loads, but it wants `brcm/brcmfmac43455-sdio.bin` (the Pi 5 chip) and that file isn't there.

## What we replace it with

| Base | hummingbird-rpi5 |
|---|---|
| GRUB + shim + bootupd | [Pi firmware](pi-firmware.md) (`raspberrypi2-firmware`) + [rpi-bootc-bootloader](rpi-bootc-bootloader.md) |
| zboot `vmlinuz` | [Raw `Image`](raw-image.md) pulled out of it at build time. It's still the same Fedora kernel. |
| Fedora DTB paths and names | [Pi 5 DTBs](device-trees.md) where the firmware looks for them |
| Host-only initramfs | [Rebuilt](initramfs.md) with `--no-hostonly` plus the SD card and filesystem modules |
| `ttyS0` kernel args | [`ttyAMA10`](kernel-args.md) |
| Hummingbird NTP pool | [`2.fedora.pool.ntp.org`](chrony.md) |

## What we added

| Added | Why | From |
|---|---|---|
| [`vcio.ko`](vcio-ko.md) | [`/dev/vcio`](vcio-device.md) for `vcgencmd` and tryboot | built from [`kmod/vcio`](../../kmod/vcio/) |
| [`8250_bcm7271.ko`](8250_bcm7271.md) | Pi 5 Bluetooth UART | built from [`kmod/bcm7271-uart`](../../kmod/bcm7271-uart/) |
| `linux-firmware-raspberrypi` | Pi [WiFi](wifi.md) and [Bluetooth](bluetooth.md) firmware | AlmaLinux |
| `raspberrypi-userland` | [`vcgencmd`](vcgencmd.md), [`vcmailbox`](vcmailbox.md) | AlmaLinux |
| `brcmfmac-firmware`, `wireless-regdb` | [WiFi](wifi.md) firmware and regulatory data | Fedora 44 |
| `wpa_supplicant` | WPA handshakes for [WiFi](wifi.md) | Fedora 44 |
| `NetworkManager-wifi` | Connecting to [WiFi](wifi.md) with `nmcli` | Hummingbird |
| `bluez` | `bluetoothd` and `bluetoothctl`, see [Bluetooth](bluetooth.md) | Fedora 44 |
| `cloud-init`, `cloud-utils-growpart`, `jq` | [First boot setup](cloud-init.md), growing `/var` | Fedora 44 |
| `xfsprogs` | [XFS tools](xfsprogs.md) | Fedora 44 |
| A few config files | WiFi power save off, services on, `/var` folders, udev rule for `/dev/vcio` | [`files/`](../../files/) |

Where each package comes from, and how the repos are limited: [packages](packages.md).

Everything else (systemd, bootc, ostree, NetworkManager, the kernel itself) comes from the base
image unchanged. To get a newer kernel, bump the base image.

## All pages in this folder

| Topic | Pages |
|---|---|
| Kernel | [Overview](kernel.md), [raw Image](raw-image.md), [`vcio.ko`](vcio-ko.md), [`8250_bcm7271.ko`](8250_bcm7271.md), [device trees](device-trees.md), [kernel args](kernel-args.md), [initramfs](initramfs.md) |
| Boot | [Overview](boot.md), [Pi firmware](pi-firmware.md), [rpi-bootc-bootloader](rpi-bootc-bootloader.md) |
| Pi tools | [Overview](rpi-tools.md), [`/dev/vcio`](vcio-device.md), [`vcgencmd`](vcgencmd.md), [`vcmailbox`](vcmailbox.md), [tryboot](tryboot.md) |
| Added packages | [Overview](packages.md), [WiFi](wifi.md), [Bluetooth](bluetooth.md), [cloud-init](cloud-init.md), [xfsprogs](xfsprogs.md), [chrony](chrony.md) |
| Checking | [How the base image was checked](base-check.md) |

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
