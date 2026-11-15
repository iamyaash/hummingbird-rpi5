# Bluetooth

[Back to what we added](packages.md)

## What the base image has

| Part | Base image | hummingbird-rpi5 |
|---|---|---|
| `bluetooth`, `hci_uart`, `btbcm` modules | Yes | Yes, same kernel |
| Pi 5 Bluetooth UART driver (`8250_bcm7271`) | No | Yes, built by us |
| Firmware patch for the chip | No | Yes |
| `bluez` (`bluetoothd`, `bluetoothctl`) | No | Yes |
| `bluetooth.service` | Not there | Enabled |

So on the base image there's no `hci0`, and even with one there'd be no tools to use it.

## What we add

| Thing | Gives us | From |
|---|---|---|
| [`8250_bcm7271.ko`](8250_bcm7271.md) | The UART the chip is wired to | Built from `kmod/bcm7271-uart` |
| `linux-firmware-raspberrypi` | The firmware patch `btbcm` loads into the chip | AlmaLinux |
| `bluez` | `bluetoothd`, `bluetoothctl`, `btmgmt` | Fedora 44 |

## Config we add

| File | Does |
|---|---|
| [`70-rpi.preset`](../../files/usr/lib/systemd/system-preset/70-rpi.preset) | Enables `bluetooth.service` |
| [`hummingbird-rpi5.conf`](../../files/usr/lib/tmpfiles.d/hummingbird-rpi5.conf) | Creates `/var/lib/bluetooth` and `/var/lib/bluetooth/mesh`, where pairings are stored |

## Using it

```sh
bluetoothctl
# then: power on, scan on, pair <mac>, trust <mac>
```

Scanning and pairing a phone are tested. Audio and tethering (PAN) don't work. See
[hardware](../hardware.md) and [known issues](../known-issues.md).

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
