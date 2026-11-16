# Hardware support

This page lists what works on a Raspberry Pi 5 with this image, what doesn't, and what I actually
tested on my own board.

- **Board:** Raspberry Pi 5 Model B, 8 GB, booting from a 64 GB microSD card
- **Image tested:** `ghcr.io/iamyaash/hummingbird-rpi5:unstable-33abab7`, the Bluetooth build
- **Kernel:** `7.2.13-200.fc44.aarch64` (the Fedora kernel from the Hummingbird base image)
- **Last tested:** 2026-11-14

Status words used below:

- **Works:** tested on my Pi
- **Partly:** works, with a limitation
- **No:** doesn't work
- **Loads, not tested:** the driver loads or the device shows up, but I didn't use it
- **Not checked:** not tested at all

## Boot and system

| Feature | Status | Notes |
|---|---|---|
| Boot from the Pi firmware (no UEFI or GRUB) | Works | Fresh flash and upgrades |
| Fresh flash of the CI SD image | Works | `dd` to microSD, SSH is up in about 60 seconds |
| cloud-init first boot | Works | SSH key and user come from `user-data`, no errors |
| Root and `/var` growth | Works | `/var` grows to 58 GB on a 64 GB card |
| CPU cores and RAM | Works | `nproc` shows 4, 7.7 GiB usable |
| No failed systemd units | Works | `systemctl is-system-running` says `running` |
| Clock sync (chrony) | Works | Syncs to the Fedora NTP pool |
| Watchdog (`bcm2835_wdt`) | Works | Module loaded, `/dev/watchdog0` present |
| Temperature and voltage sensors | Works | hwmon `cpu_thermal` and `rpi_volt` |
| Real-time clock | No | No `/dev/rtc`. The clock starts at a fixed date on each boot until chrony syncs |
| Power button | Not checked | Boot log shows `gpio-keys ... Unable to get irq number for GPIO 0` |

## Updates

| Feature | Status | Notes |
|---|---|---|
| `bootc upgrade` | Works | |
| `bootc switch` | Works | Also works going from the old AlmaLinux-kernel image to the Fedora-kernel one |
| Rollback with tryboot (`rpi-bootc-bootloader tryreboot`) | Works | |
| `bootc rollback` | Works | Tested across kernels `7.3.3` to `7.2.13`. Needs rpi-bootc-bootloader `v0.0.8-hb1`. See [upgrades and rollback](upgrades.md) |
| Power cut during a boot partition sync | Broken on `v0.0.8-hb1` | `CIDATA` corrupted, re-flash needed. `v0.0.8-hb2` fix not tested yet. See [power cuts during a sync](upgrades.md#power-cuts-during-a-sync) |

## Networking

| Feature | Status | Notes |
|---|---|---|
| Ethernet (`end0`) | Works | DHCP, IPv4 and IPv6 |
| SSH | Works | |
| WiFi (`wlan0`) | Works | 2.4 and 5 GHz, connected with `nmcli`, power save off |

## Bluetooth

| Feature | Status | Notes |
|---|---|---|
| Controller (`hci0`) | Works | Comes up at boot through the out-of-tree `8250_bcm7271.ko` |
| Scanning | Works | Finds nearby devices |
| Pairing, bonding and trusting a phone | Works | Tested with an Android phone |
| Connecting and exchanging data | Works | `avinfo` read the phone's audio codecs over the link |
| Audio (A2DP, headsets) | No | The image has no audio stack (no PipeWire) |
| Tethering over Bluetooth (PAN) | No | The chip's default address `43:45:C0:00:1F:AC` is a multicast MAC, so `bnep0` can't come up |
| Unique Bluetooth address per Pi | No | Every Pi 5 probably uses the same default address. Matters if several Pis are nearby |

## Raspberry Pi tools

| Feature | Status | Notes |
|---|---|---|
| `/dev/vcio` | Works | Out-of-tree `vcio.ko`, owned by `root:video`, mode 0660 |
| `vcgencmd` | Works | `measure_temp`, `get_throttled`, `measure_clock arm`, `measure_volts`, `version` |
| `vcmailbox` | Works | Read-only tags and the tryboot tag |

## Display, audio and peripherals

| Feature | Status | Notes |
|---|---|---|
| HDMI output | Loads, not tested | `vc4` loads and creates `HDMI-A-1` and `HDMI-A-2`. No monitor tested. Logs a harmless upstream `vc4-drm ... late IOMMU probe` warning |
| HDMI audio | No | No sound card appears (`/dev/snd` only has `seq` and `timer`) |
| USB ports | Loads, not tested | 5 USB host controllers present. No USB device tested |
| PCIe / M.2 HAT | Loads, not tested | The external PCIe slot shows `link down` with nothing attached. Not tested with an NVMe drive |
| GPIO | Loads, not tested | `/dev/gpiochip0` through `5` are present. Not tested |
| I2C, SPI | No | No `/dev/i2c-*` or `/dev/spidev*`. Would need device tree changes, and no overlays ship |
| Status LEDs (ACT, PWR) | Not checked | Not in `/sys/class/leds`, only `mmc0::` and `mmc1::` show up |
| Fan / Active Cooler | Not checked | No fan cooling device found. Not checked with a fan attached |
| Camera (CSI), display (DSI) | Not checked | |
| UART debug console (`ttyAMA10`) | Not checked | Set up in `config-bootc-common.txt` and the kernel arguments. Not checked with a serial adapter |
| Booting from USB or NVMe | Not checked | Only microSD is tested |

## Other Raspberry Pi models

Only the Pi 5 is supported. The image ships only `bcm2712` device trees, so other models won't
boot it.

---

These tests were run by hand on my Raspberry Pi 5.
