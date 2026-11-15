# Hummingbird on Raspberry Pi 5

> **Unstable.** This is a test project. Things can break between builds, so don't run it on a
> card you can't reflash.

Hummingbird is an image-based OS. The whole system is one container image, and you update by
switching to a newer image instead of installing packages. This repo builds that image into an
SD card you can flash for the Raspberry Pi 5. The Pi boots it straight from its own firmware,
with no UEFI, U-Boot or GRUB.

The image is put together from three places:

- **Hummingbird** for the userspace: systemd, bootc, ostree, NetworkManager, chrony.
- **Fedora 44's kernel**, which comes with the Hummingbird base image.
- **AlmaLinux's Raspberry Pi packages** for the VideoCore firmware, the Pi's WiFi and Bluetooth
  firmware, and `vcgencmd` and `vcmailbox`.

For what we changed from the base image and why, see
[Base Hummingbird vs hummingbird-rpi5](docs/base-vs-rpi5/README.md).

Based on [AlmaLinux/bootc-images-rpi](https://github.com/AlmaLinux/bootc-images-rpi) and
[oci-native/archlinux-rpi](https://github.com/oci-native/archlinux-rpi). Only the Pi 5 is
supported.

## Status

Tested on a Raspberry Pi 5 (8 GB) on 2026-11-14, from a fresh flash of the CI image.

- **Works:** boot from the [Pi firmware](docs/base-vs-rpi5/pi-firmware.md), SSH, Ethernet,
  [WiFi](docs/base-vs-rpi5/wifi.md), [Bluetooth](docs/base-vs-rpi5/bluetooth.md) (pairing tested),
  [cloud-init](docs/base-vs-rpi5/cloud-init.md) first boot, [`vcgencmd`](docs/base-vs-rpi5/vcgencmd.md),
  [`vcmailbox`](docs/base-vs-rpi5/vcmailbox.md), [tryboot](docs/base-vs-rpi5/tryboot.md), watchdog,
  `bootc upgrade`, `bootc switch`, `bootc rollback` (tested on 2026-11-15, needs a build with
  rpi-bootc-bootloader `v0.0.8-hb1`).
- **Not tested yet:** HDMI with a monitor, the power button, a power cut during `bootc upgrade`.

## Build

### Option 1: CI

The workflow runs on a native arm64 runner and only starts when you trigger it by hand:

```sh
gh workflow run build.yml --ref main
gh run watch
gh run download <run-id> --name hummingbird-rpi5-unstable-sdcard-image
```

Each run uploads a compressed SD image (`hummingbird-rpi5-unstable-<date>-<sha>.raw.xz`) and
pushes the bootc image to `ghcr.io/<owner>/hummingbird-rpi5`. Cards track the `unstable` tag,
which only moves when `main` builds.

### Option 2: build locally

You need an arm64 machine with podman. x86 won't work, because `bootc install` fails under qemu.
Run these from the repo root:

```sh
# 1. Build the bootc image
sudo podman build -t localhost/hummingbird-rpi5:unstable -f Containerfile .

# 2. Make the SD card image
#    <local image> <image the Pi pulls on upgrade> <output file> [size, default 8G]
sudo scripts/build-sd-image.sh \
  localhost/hummingbird-rpi5:unstable \
  ghcr.io/<owner>/hummingbird-rpi5:unstable \
  hummingbird-rpi5-unstable.raw

# 3. Optional: compress it
xz -T0 hummingbird-rpi5-unstable.raw
```

More detail: [docs/build.md](docs/build.md).

## Install

**1. Flash the card.** Check the device name with `lsblk` first. This erases the card.

```sh
xzcat hummingbird-rpi5-unstable-*.raw.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

**2. Add your SSH key.** Mount the card's small FAT partition, `CIDATA`, and replace the
placeholder under `ssh_authorized_keys:` in `user-data` with your public key. In one command:

```sh
KEY="$(cat ~/.ssh/<key>.pub)"
sed -i "/ssh_authorized_keys:/{n;s|.*|      - $KEY|}" /run/media/$USER/CIDATA/user-data
```

**3. Boot.** Plug in Ethernet and power on. SSH is up in about a minute.

**4. Log in.** Find the Pi in your router's client list (`hummingbird-rpi`), or run
`nmap -sn <subnet>` and look for "Raspberry Pi Trading". Then:

```sh
ssh -i ~/.ssh/<key> hummingbird@<ip>
bootc status            # which image is running
vcgencmd measure_temp   # CPU temperature
```

Notes:

- After reflashing, clear the old host key with `ssh-keygen -R <ip>`.
- For WiFi: `sudo nmcli dev wifi connect <ssid> password <password>`.
- Put firmware settings in `config-bootc-common.txt` on `CIDATA`. Don't edit `config.txt`, since
  it's regenerated on every sync.

More detail: [docs/install.md](docs/install.md).

## Upgrade

`bootc upgrade` pulls `:unstable`. Automatic updates are off, so a card only changes when you run
a command.

```sh
sudo bootc upgrade
sudo bootc switch ghcr.io/<owner>/hummingbird-rpi5:unstable-<sha>   # pin one build
sudo bootc switch ghcr.io/<owner>/hummingbird-rpi5:unstable         # follow main again
```

A pinned tag never moves, so `upgrade` won't find anything newer until you switch back.

## Roll back

```sh
sudo bootc rollback
journalctl -b -u rpi-bootc-bootloader-sync.service | tail -1   # wait for "Finished"
sudo reboot
```

A sync copies the boot entries to `CIDATA` by itself after the rollback. Wait for it before you
reboot. This needs rpi-bootc-bootloader `v0.0.8-hb1` or newer (`rpi-bootc-bootloader version`).
On older builds, `bootc rollback` can leave the Pi stuck at boot, so run `bootc upgrade` first or
use the tryboot steps in [docs/upgrades.md](docs/upgrades.md).

More detail: [docs/upgrades.md](docs/upgrades.md). How tryboot works:
[tryboot](docs/base-vs-rpi5/tryboot.md).

## Known issues

- Every Pi probably uses the same Bluetooth address (`43:45:C0:00:1F:AC`), so it only matters
  with more than one Pi nearby.
- HDMI and the power button are untested.
- Old DTBs and overlays stay on the FAT partition after a kernel change.
- The unsigned [`vcio.ko`](docs/base-vs-rpi5/vcio-ko.md) and
  [`8250_bcm7271.ko`](docs/base-vs-rpi5/8250_bcm7271.md) taint the kernel.

Full list: [docs/known-issues.md](docs/known-issues.md).

## More docs

- [Build](docs/build.md) | [Install](docs/install.md) | [Upgrades and rollback](docs/upgrades.md)
- [Hardware test results](docs/hardware.md) | [How it works](docs/how-it-works.md)
- [Known issues](docs/known-issues.md) | [Base vs hummingbird-rpi5](docs/base-vs-rpi5/README.md)
