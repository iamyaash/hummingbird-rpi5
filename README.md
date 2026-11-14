# Hummingbird on Raspberry Pi 5

> **Unstable.** This is a test project. Every image it publishes is tagged `unstable`, and
> things can break between builds. Don't run it on a card you can't reflash.

## What it is

Hummingbird is an image-based OS. The whole system is one container image, and you update it by
switching to a newer image instead of installing packages on a running machine. This repo builds
that image for the Raspberry Pi 5 and turns it into an SD card image you can flash.

The Pi 5 boots the image straight from its own firmware. There is no UEFI, U-Boot or GRUB in the
chain.

The image is put together from three places:

- **Hummingbird** for the userspace: systemd, bootc, ostree, NetworkManager, chrony and so on.
- **Fedora 44's kernel**, which comes with the Hummingbird base image.
- **AlmaLinux's Raspberry Pi packages** for the VideoCore firmware, the Pi's WiFi and Bluetooth
  firmware, and the `vcgencmd` and `vcmailbox` tools.

It's based on [AlmaLinux/bootc-images-rpi](https://github.com/AlmaLinux/bootc-images-rpi) and
[oci-native/archlinux-rpi](https://github.com/oci-native/archlinux-rpi). Only the Pi 5 is
supported. Other Pi models won't boot it, because the image only ships Pi 5 device trees.

### What works

Tested on a Raspberry Pi 5 (8 GB) on 2026-11-14, starting from a fresh flash of the CI image:

- Booting from the Pi firmware, SSH, Ethernet, WiFi, and Bluetooth (pairing tested)
- First boot with cloud-init, including growing the root and `/var` partitions
- `/dev/vcio`, `vcgencmd`, `vcmailbox`, tryboot and the watchdog
- `bootc upgrade` and `bootc switch`

Not tested yet: HDMI with a monitor, the power button, and a power cut during `bootc upgrade`.
`bootc rollback` doesn't work, so use the tryboot method described below. The full list is in
[HARDWARE.md](HARDWARE.md).

## Build guide

You can let CI build the image, or build it yourself on an arm64 machine.

### Option 1: CI

The workflow is [`.github/workflows/build.yml`](.github/workflows/build.yml). It runs on a native
arm64 runner and only starts when you trigger it by hand:

```sh
gh workflow run build.yml --ref main
gh run watch
gh run download <run-id> --name hummingbird-rpi5-unstable-sdcard-image
```

Each run does two things:

- Uploads a compressed SD card image (`hummingbird-rpi5-unstable-<date>-<sha>.raw.xz`) as a
  workflow artifact. Artifacts are kept for 14 days.
- Pushes the bootc image to `ghcr.io/<owner>/hummingbird-rpi5`.

The image tags work like this:

| Tag | When it's pushed | What it's for |
|---|---|---|
| `unstable-<date>-<sha>` and `unstable-<sha>` | Every run, from any branch | Pinning one exact build |
| `unstable` | Runs on `main` only | Following `main`. Cards track this tag |

There's no `latest` tag. That name is saved for a stable channel later. Older builds were pushed
as `latest`, but it no longer gets updated and still points to an old build with AlmaLinux's
kernel, so don't track it.

The channel name is set by the `CHANNEL` variable in the workflow.

### Option 2: build locally

You need an arm64 machine with podman. Don't try this on x86: the container builds under qemu,
but `bootc install` fails with `setns: Invalid argument`, because qemu-user is multithreaded.

Run these as root:

```sh
# 1. Build the bootc image
sudo podman build -t localhost/hummingbird-rpi5:unstable -f Containerfile .

# 2. Make the SD card image
#    Arguments: <local image> <image the Pi pulls on upgrade> <output file> [size, default 8G]
sudo scripts/build-sd-image.sh \
  localhost/hummingbird-rpi5:unstable \
  ghcr.io/<owner>/hummingbird-rpi5:unstable \
  hummingbird-rpi5-unstable.raw

# 3. Optional: compress it
xz -T0 hummingbird-rpi5-unstable.raw
```

## Demo installation

This walks through putting the image on a card and logging in for the first time.

**1. Flash the card.** Check the device name with `lsblk` first. Flashing erases the card.

```sh
xzcat hummingbird-rpi5-unstable-*.raw.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

**2. Add your SSH key.** The card has a small FAT partition called `CIDATA`. Mount it and open
`user-data`. Replace the placeholder under `ssh_authorized_keys:` with your public key.

If you'd rather do it in one command (the mount path may differ on your system):

```sh
KEY="$(cat ~/.ssh/<key>.pub)"
sed -i "/ssh_authorized_keys:/{n;s|.*|      - $KEY|}" /run/media/$USER/CIDATA/user-data
```

**3. Boot the Pi.** Plug in Ethernet and power it on. It takes about a minute to reach SSH.

**4. Find its IP address.** Check your router's client list for `hummingbird-rpi`. Or scan your
network with `nmap -sn <subnet>` and look for "Raspberry Pi Trading".

**5. Log in.**

```sh
ssh -i ~/.ssh/<key> hummingbird@<ip>
```

Once you're in, try a couple of commands to see what's running:

```sh
bootc status            # which image is running
vcgencmd measure_temp   # CPU temperature
```

A few things you'll likely run into:

- After reflashing, SSH warns that the host key changed. Remove the old one with
  `ssh-keygen -R <ip>`.
- `bootc status` may print a `mount: (hint) your fstab has been modified` message. It's
  harmless. `sudo systemctl daemon-reload` clears it.
- To connect to WiFi: `sudo nmcli dev wifi connect <ssid> password <password>`.
- Put firmware settings in `config-bootc-common.txt` on `CIDATA`. Don't edit `config.txt`, since
  rpi-bootc-bootloader rewrites it on every sync.

The firmware partition (p1) isn't mounted at runtime. To read it, mount it read-only:

```sh
sudo mkdir -p /mnt/p1 && sudo mount -o ro /dev/mmcblk0p1 /mnt/p1
sudo ls /mnt/p1          # files are root-only, so use sudo
sudo umount /mnt/p1
```

## Upgrades and rollback

`bootc upgrade` and `bootc switch` both work. Automatic updates are off, so a card only changes
when you run one of them yourself.

`bootc upgrade` pulls the `:unstable` tag, which only moves when `main` builds. To run one
specific build, switch to its tag. A pinned tag never moves, so `upgrade` won't find anything
newer until you switch back:

```sh
sudo bootc switch ghcr.io/<owner>/hummingbird-rpi5:unstable-<sha>   # pin one build
sudo bootc switch ghcr.io/<owner>/hummingbird-rpi5:unstable         # follow main again
```

Cards flashed before the move to `unstable` tags still follow `:latest`, which isn't updated any
more. Run the second command once to move them over.

### Rolling back

Don't use `bootc rollback`. With rpi-bootc-bootloader v0.0.8 it can leave the Pi stuck at boot
(solid green LED, no network) when the two deployments have different kernels. Running `sync`
afterwards fixes the paths, but then the booted deployment becomes the default and the rollback
is ignored. This is being reported upstream.

Use the tryboot method instead:

```sh
sudo rpi-bootc-bootloader sync        # default = the booted one, fallback/tryboot = the other
sudo rpi-bootc-bootloader tryreboot   # boot the other deployment once
# now on the old deployment:
sudo rpi-bootc-bootloader sync        # make it the default
```

If the tryboot fails, a power cycle goes back to the default. `tryreboot` needs `vcmailbox` in the
image that's currently booted. To boot the fallback entry on power-up, hold GPIO6 to GND (for
example pin 31 to pin 39) while you switch the Pi on.

Be careful with `vcmailbox 0x00038064 4 4 1`. It arms tryboot, so the next boot uses
`tryboot.txt`. To check that `vcmailbox` works without changing anything, read a tag instead:
`vcmailbox 0x00000001 4 4 0` (firmware revision).

### Recovering a card that hangs after a rollback

From another machine:

1. Mount the root partition (p3) read-only. `sudo ls -l <root>/ostree/` shows which `boot.N` link
   exists, for example `boot.0 -> boot.0.1`. The directory is root-only, so run this with sudo to
   see the real deployment paths:
   `sudo find <root>/ostree/boot.0.1 -maxdepth 4 -printf '%p -> %l\n'`
2. Back up `bootc/entries/ostree-*/cmdline.txt` on `CIDATA`. Then change the `boot.N` in each
   `ostree=` path so it matches a path that exists.
3. Boot the card and roll back with the tryboot method above.

## Known issues

- **Every Pi probably has the same Bluetooth address.** The chip uses its default address
  (`43:45:C0:00:1F:AC`), because the upstream device tree doesn't give the firmware a
  `local-bd-address`. This only matters if you have more than one Pi nearby.
- **HDMI is untested.** `vc4` loads and logs a harmless upstream `vc4-drm ... late IOMMU probe`
  warning.
- **The power button is untested.** The boot log shows `gpio-keys ... Unable to get irq number for
  GPIO 0`.
- **No `bootc rollback`.** See above.
- **Old files pile up on the FAT partition.** rpi-bootc-bootloader never deletes files from an
  entry folder, so old DTBs and overlays stay around after a kernel change.
- **The kernel is tainted.** The unsigned `vcio.ko` and `8250_bcm7271.ko` taint it (flags `O`
  and `E`).

## Under the hood

Fedora's kernel boots fine on the Pi once a few things are changed.

- **Kernel updates** come from bumping the pinned base image (date tag and digest together), not
  from a separate kernel repo.
- **Kernel format.** Fedora's `vmlinuz` is an EFI zboot (zstd) wrapper, which the Pi firmware
  can't boot. The build pulls out the raw arm64 Image (about 79 MB) and installs it as `vmlinuz`.
- **`/dev/vcio`** is needed by `vcgencmd`, `vcmailbox` and tryboot. Fedora's kernel doesn't have
  `CONFIG_BCM_VCIO`, so [`kmod/vcio/vcio.c`](kmod/vcio/vcio.c) is the Raspberry Pi downstream
  driver, changed to work without a `raspberrypi,vcio` device tree node. A builder stage compiles
  it against the exact base kernel's `kernel-devel` from Koji, since the Fedora updates repo only
  keeps the newest kernel. It loads at boot through `modules-load.d`. The module is unsigned, so
  the kernel is tainted, but it still loads because `MODULE_SIG_FORCE` is off. If a base image bump
  changes the kernel API, the vcio build fails on purpose.
- **Bluetooth.** Fedora's kernel doesn't have `CONFIG_SERIAL_8250_BCM7271`, the driver for the Pi 5
  Bluetooth UART. [`kmod/bcm7271-uart`](kmod/bcm7271-uart/) builds the unmodified upstream driver
  out of tree. The sources, including the private `8250.h`, are copied from the kernel.org stable
  tree at the version in `kmod/bcm7271-uart/VERSION`, and the build fails if that doesn't match the
  base kernel. After a base image bump, run `make -C kmod/bcm7271-uart update KVERSION=<x.y.z>` and
  commit. The driver loads through a device tree alias, then `hci_uart` and `btbcm` bring up
  `hci0` with the Pi 5 firmware patch.
- **Device trees.** The Pi 5 DTBs are staged under `/usr/share/raspberrypi2-kernel-fedora/<kver>/boot/`,
  which is where rpi-bootc-bootloader copies from. The upstream `bcm2712-d-rpi-5-b.dtb` is
  installed as `bcm2712d0-rpi-5-b.dtb`, the name the firmware looks for. No device tree overlays
  ship, because the downstream overlays don't match the upstream DTBs.
- **Initramfs.** Fedora builds the SD card drivers and filesystems as modules, so the initramfs
  adds `mmc_block sdhci sdhci-pltfm sdhci-brcmstb xfs erofs overlay`.
- **Updates.** rpi-bootc-bootloader copies each bootc deployment onto the FAT partition
  (`bootc/entries/ostree-N/`) and points the firmware's `os_prefix` at it. That's why
  `bootc upgrade` works without a separate bootloader.

Where each part comes from:

| Part | Comes from |
|---|---|
| Userspace (systemd, bootc, ostree, dracut, NetworkManager, chrony) | `quay.io/hummingbird-community/os-minimal`, pinned by date and digest |
| Kernel | Fedora 44 kernel in the base image (`7.2.13-200.fc44` at the current pin) |
| Device trees | Upstream Fedora Pi 5 DTBs from the same kernel |
| `/dev/vcio` | `vcio.ko`, built from [`kmod/vcio/`](kmod/vcio/) |
| VideoCore firmware | AlmaLinux `raspberrypi2-firmware` |
| Pi WiFi and Bluetooth firmware | AlmaLinux `linux-firmware-raspberrypi` |
| `vcgencmd`, `vcmailbox` | AlmaLinux `raspberrypi-userland` |
| WiFi, Bluetooth, cloud-init and other tools | Fedora 44 |
| Boot entries on the FAT partition | [rpi-bootc-bootloader](https://github.com/kfox1111/rpi-bootc-bootloader) v0.0.8 |

GRUB, shim and bootupd are removed.
