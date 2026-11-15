# The boot changes

[Back to base vs rpi5](README.md)

The base image boots through UEFI: firmware, then shim, then GRUB, then the kernel. The Pi 5 has
no UEFI. Its firmware reads the kernel straight off a FAT partition. So we remove the UEFI chain
and use two things instead:

| Part | Does | Page |
|---|---|---|
| Pi firmware | Reads `config.txt` on the FAT partition, then loads the kernel, initramfs and DTB | [Pi firmware](pi-firmware.md) |
| rpi-bootc-bootloader | Copies each bootc deployment onto the FAT partition and points `config.txt` at it | [rpi-bootc-bootloader](rpi-bootc-bootloader.md) |

```text
Base (UEFI):  UEFI firmware -> shim -> GRUB -> kernel
rpi5:         Pi firmware -> config.txt -> bootc/entries/ostree-N/ -> kernel
```

## What's removed

| Removed | Why |
|---|---|
| `grub2-efi-aa64`, `grub2-tools*`, `grub2-common` | No UEFI, so GRUB never runs |
| `shim-aa64` | Same |
| `efibootmgr` | There are no EFI boot entries to manage |
| `bootupd` and `bootloader-update.service` | It updates GRUB and shim, which are gone |

The `/etc/dnf/protected.d` files that stop dnf from removing GRUB and shim are deleted first.

## SD card layout

| Partition | Filesystem | Label | Holds |
|---|---|---|---|
| p1 | FAT32 | `CIDATA` | Pi firmware, `config.txt`, `bootc/entries/ostree-N/`, cloud-init seed |
| p2 | XFS | `boot` | `/boot`: ostree boot entries and kernels |
| p3 | XFS | `root` | `/`: the ostree sysroot |

The card uses a plain MBR partition table, because the firmware reads it directly.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
