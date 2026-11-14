# Hardware support

What works on the Raspberry Pi 5 with this image, what doesn't, and what was actually tested
on hardware by the author.

- **Board:** Raspberry Pi 5 Model B, 8 GB, booting from a 64 GB microSD card
- **Image:** `ghcr.io/iamyaash/hummingbird-rpi5:unstable-33abab7` (branch `feat/bluetooth`)
- **Kernel:** `7.2.13-200.fc44.aarch64` (Fedora kernel from the Hummingbird base image)
- **Last tested:** 2026-11-14

Legend:

- **Works:** tested on hardware by the author
- **Partly:** works with a limitation
- **Doesn't work**
- **Loads, not tested:** the driver loads or the device appears, but it wasn't used
- **Not checked:** not checked at all

## Boot and system

| Feature | Status | Notes |
|---|---|---|
| Boot from the Pi firmware (no UEFI/GRUB) | Works | Fresh flash and upgrades |
| Fresh flash of the CI SD image | Works | `dd` to microSD, first boot to SSH in about 60 s |
| cloud-init first boot | Works | SSH key and user from `user-data`, NoCloud seed on the FAT partition, no errors |
| Root and `/var` growth to fill the card | Works | `/var` grows to 58 GB on a 64 GB card |
| All 4 CPU cores and 8 GB RAM | Works | `nproc` = 4, 7.7 GiB usable |
| No failed systemd units | Works | `systemctl is-system-running` = `running` |
| Clock sync (chrony) | Works | Synced to the Fedora NTP pool |
| Watchdog (`bcm2835_wdt`) | Works | Module loaded, `/dev/watchdog0` present |
| Temperature and voltage sensors | Works | hwmon `cpu_thermal` and `rpi_volt` |
| Real-time clock (RTC) | No | No `/dev/rtc`. The clock starts at a fixed date on every boot until chrony syncs |
| Power button | Not checked | Boot log shows `gpio-keys ... Unable to get irq number for GPIO 0` |

## Updates

| Feature | Status | Notes |
|---|---|---|
| `bootc upgrade` | Works | |
| `bootc switch` | Works | Including from the old AlmaLinux-kernel image to the Fedora-kernel image |
| Rollback with tryboot (`rpi-bootc-bootloader tryreboot`) | Works | |
| `bootc rollback` | No | Can leave the Pi unbootable when the kernels differ. Use tryboot. See README |
| Power cut during `bootc upgrade` | Not checked | |

## Networking

| Feature | Status | Notes |
|---|---|---|
| Ethernet (`end0`) | Works | DHCP, IPv4 and IPv6 |
| SSH | Works | |
| WiFi (`wlan0`) | Works | 2.4 and 5 GHz, connected via `nmcli`, power save off |

## Bluetooth

| Feature | Status | Notes |
|---|---|---|
| Controller (`hci0`) | Works | Comes up at boot via the out-of-tree `8250_bcm7271.ko` |
| Scan | Works | Finds nearby devices |
| Pair, bond, trust a phone | Works | Tested with an Android phone |
| Connect and exchange data | Works | `avinfo` read the phone's audio codecs over the link |
| Audio (A2DP, headsets) | No | No audio stack (no PipeWire) in the image |
| Tethering / internet over Bluetooth (PAN) | No | The chip's default address `43:45:C0:00:1F:AC` is a multicast MAC, so `bnep0` can't come up |
| Unique Bluetooth address per Pi | No | Every Pi 5 likely uses the same default address. Matters with several Pis near each other |

## Raspberry Pi tools

| Feature | Status | Notes |
|---|---|---|
| `/dev/vcio` | Works | Out-of-tree `vcio.ko`, `root:video 0660` |
| `vcgencmd` | Works | `measure_temp`, `get_throttled`, `measure_clock arm`, `measure_volts`, `version` |
| `vcmailbox` | Works | Read-only tags and the tryboot tag |

## Display, audio and peripherals

| Feature | Status | Notes |
|---|---|---|
| HDMI output | Loads, not tested | `vc4` loads and creates `HDMI-A-1` and `HDMI-A-2`. No monitor tested. Logs a harmless upstream `vc4-drm ... late IOMMU probe` warning |
| HDMI audio | No | No sound card appears (`/dev/snd` has only `seq` and `timer`) |
| USB ports | Loads, not tested | 5 USB host controllers present. No USB device tested |
| PCIe / M.2 HAT | Loads, not tested | External PCIe slot reports `link down` with nothing attached. Not tested with an NVMe drive |
| GPIO | Loads, not tested | `/dev/gpiochip0` to `5` present. Not tested |
| I2C, SPI | No | No `/dev/i2c-*` or `/dev/spidev*`. Would need device tree changes, and no overlays are shipped |
| Status LEDs (ACT/PWR) | Not checked | Not exposed in `/sys/class/leds` (only `mmc0::`, `mmc1::`) |
| Fan / Active Cooler | Not checked | No fan cooling device found. Not checked with a fan attached |
| Camera (CSI), display (DSI) | Not checked | |
| UART debug console (`ttyAMA10`) | Not checked | Configured in `config-bootc-common.txt` and kernel arguments, not checked with a serial adapter |
| Booting from USB or NVMe | Not checked | Only microSD is tested |

## Other Raspberry Pi models

Only the Pi 5 is supported. The image ships only `bcm2712` device trees, so other models
won't boot.

---

> These tests were run by hand on my Raspberry Pi 5.
