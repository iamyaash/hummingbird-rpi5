# How it works

The image is put together from three places:

- **Hummingbird** for the userspace: systemd, bootc, ostree, NetworkManager, chrony and so on.
- **Fedora 44's kernel**, which comes with the Hummingbird base image.
- **AlmaLinux's Raspberry Pi packages** for the VideoCore firmware, the Pi's WiFi and Bluetooth
  firmware, and the `vcgencmd` and `vcmailbox` tools.

Fedora's kernel boots fine on the Pi once a few things are changed.

- **Kernel updates** come from bumping the pinned base image (date tag and digest together), not
  from a separate kernel repo.
- **Kernel format.** Fedora's `vmlinuz` is an EFI zboot (zstd) wrapper, which the Pi firmware
  can't boot. The build pulls out the raw arm64 Image (about 79 MB) and installs it as `vmlinuz`.
- **`/dev/vcio`** is needed by `vcgencmd`, `vcmailbox` and tryboot. Fedora's kernel doesn't have
  `CONFIG_BCM_VCIO`, so [`kmod/vcio/vcio.c`](../kmod/vcio/vcio.c) is the Raspberry Pi downstream
  driver, changed to work without a `raspberrypi,vcio` device tree node. A builder stage compiles
  it against the exact base kernel's `kernel-devel` from Koji, since the Fedora updates repo only
  keeps the newest kernel. It loads at boot through `modules-load.d`. The module is unsigned, so
  the kernel is tainted, but it still loads because `MODULE_SIG_FORCE` is off. If a base image bump
  changes the kernel API, the vcio build fails on purpose.
- **Bluetooth.** Fedora's kernel doesn't have `CONFIG_SERIAL_8250_BCM7271`, the driver for the Pi 5
  Bluetooth UART. [`kmod/bcm7271-uart`](../kmod/bcm7271-uart/) builds the unmodified upstream
  driver out of tree. The sources, including the private `8250.h`, are copied from the kernel.org
  stable tree at the version in `kmod/bcm7271-uart/VERSION`, and the build fails if that doesn't
  match the base kernel. After a base image bump, run
  `make -C kmod/bcm7271-uart update KVERSION=<x.y.z>` and commit. The driver loads through a device
  tree alias, then `hci_uart` and `btbcm` bring up `hci0` with the Pi 5 firmware patch.
- **Device trees.** The Pi 5 DTBs are staged under
  `/usr/share/raspberrypi2-kernel-fedora/<kver>/boot/`, which is where rpi-bootc-bootloader copies
  from. The upstream `bcm2712-d-rpi-5-b.dtb` is installed as `bcm2712d0-rpi-5-b.dtb`, the name the
  firmware looks for. No device tree overlays ship, because the downstream overlays don't match
  the upstream DTBs.
- **Initramfs.** Fedora builds the SD card drivers and filesystems as modules, so the initramfs
  adds `mmc_block sdhci sdhci-pltfm sdhci-brcmstb xfs erofs overlay`.
- **Updates.** rpi-bootc-bootloader copies each bootc deployment onto the FAT partition
  (`bootc/entries/ostree-N/`) and points the firmware's `os_prefix` at it. That's why
  `bootc upgrade` works without a separate bootloader.

## Where each part comes from

| Part | Comes from |
|---|---|
| Userspace (systemd, bootc, ostree, dracut, NetworkManager, chrony) | `quay.io/hummingbird-community/os-minimal`, pinned by date and digest |
| Kernel | Fedora 44 kernel in the base image (`7.2.13-200.fc44` at the current pin) |
| Device trees | Upstream Fedora Pi 5 DTBs from the same kernel |
| `/dev/vcio` | `vcio.ko`, built from [`kmod/vcio/`](../kmod/vcio/) |
| VideoCore firmware | AlmaLinux `raspberrypi2-firmware` |
| Pi WiFi and Bluetooth firmware | AlmaLinux `linux-firmware-raspberrypi` |
| `vcgencmd`, `vcmailbox` | AlmaLinux `raspberrypi-userland` |
| WiFi, Bluetooth, cloud-init and other tools | Fedora 44 |
| Boot entries on the FAT partition | [rpi-bootc-bootloader](https://github.com/kfox1111/rpi-bootc-bootloader) v0.0.8 |

GRUB, shim and bootupd are removed.
