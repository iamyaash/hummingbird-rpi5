# WiFi

[Back to what we added](packages.md)

## What the base image has

The kernel side is all there. Everything around it is missing.

| Part | Base image | hummingbird-rpi5 |
|---|---|---|
| `cfg80211`, `mac80211`, `brcmfmac` modules | Yes | Yes, same kernel |
| Firmware (`brcm/brcmfmac43455-sdio.bin` and friends) | No, there's no `/usr/lib/firmware` at all | Yes |
| Regulatory database | No | Yes |
| `wpa_supplicant` | No | Yes |
| NetworkManager WiFi plugin | No | Yes |
| `nmcli dev wifi` | Shows `WIFI-HW missing` | Works |

Without the firmware, `brcmfmac` loads but the chip never starts.

## What we add

| Package | Gives us | From |
|---|---|---|
| `linux-firmware-raspberrypi` | Pi-specific WiFi firmware and board config | AlmaLinux |
| `brcmfmac-firmware` | Broadcom/Cypress WiFi firmware | Fedora 44 |
| `wireless-regdb` | Which channels and power levels are legal where you are | Fedora 44 |
| `wpa_supplicant` | WPA/WPA2/WPA3 handshakes | Fedora 44 |
| `NetworkManager-wifi` | Lets NetworkManager manage `wlan0` | Hummingbird |

## Config we add

| File | Does |
|---|---|
| [`50-rpi-wifi-powersave.conf`](../../files/usr/lib/NetworkManager/conf.d/50-rpi-wifi-powersave.conf) | Turns WiFi power save off (`wifi.powersave=2`). With it on, `brcmfmac` drops off the network a few minutes after boot. |
| [`hummingbird-rpi5.conf`](../../files/usr/lib/tmpfiles.d/hummingbird-rpi5.conf) | Creates `/var/lib/NetworkManager`. bootc doesn't update `/var`, so it has to be made at boot. |

## Using it

```sh
sudo nmcli dev wifi connect <ssid> password <password>
```

Tested on a Pi 5 on 2.4 and 5 GHz. See [hardware](../hardware.md).

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
