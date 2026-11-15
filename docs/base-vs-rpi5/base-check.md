# How the base image was checked

[Back to base vs rpi5](README.md)

The base image was installed into a local libvirt VM and inspected over SSH. This is what was run
and what came back.

## Setup

| Step | Command | Result |
|---|---|---|
| 1 | `podman pull quay.io/hummingbird-community/os-minimal:20261113@sha256:a98c8cf5...` | Pulled, 903 MB |
| 2 | `podman tag 59a17f8ccf16 quay.io/hummingbird-community/os-minimal:20261113` | Needed because `bcvk` looks the image up by tag |
| 3 | `cargo install --locked --git https://github.com/bootc-dev/bcvk bcvk` | `bcvk` 0.22.0, which runs bootc images as VMs without root |
| 4 | `bcvk libvirt run -c qemu:///session --name hb-base-test --filesystem xfs ...` | **Failed**: no `mkfs.xfs` in the image. See [xfsprogs](xfsprogs.md). |
| 5 | Same with `--filesystem ext4` | Installed and booted |
| 6 | `bcvk libvirt ssh -c qemu:///session hb-base-test '<checks>'` | The results below |

The full command for step 5:

```sh
bcvk libvirt run -c qemu:///session --name hb-base-test --memory 2G --cpus 2 \
    --disk-size 10G --filesystem ext4 --ssh-wait \
    quay.io/hummingbird-community/os-minimal:20261113
```

## Results

| Check | Result |
|---|---|
| Kernel | `7.3.3-200.fc44.x86_64` |
| `CONFIG_CFG80211`, `MAC80211`, `BRCMFMAC`, `IWLWIFI` | `=m` |
| `CONFIG_BT`, `BT_HCIUART`, `BT_BCM`, `BT_HCIBTUSB` | `=m`, and `BT_HCIUART_BCM=y` |
| `CONFIG_SERIAL_8250_BCM7271` | Not set |
| `modprobe cfg80211 mac80211 brcmfmac bluetooth hci_uart btusb` | All load |
| `/usr/lib/firmware` | Doesn't exist |
| Firmware, `bluez`, `wpa_supplicant`, `iwd`, `wireless-regdb` packages | None installed |
| NetworkManager plugin folder | Empty, so no WiFi plugin |
| `nmcli radio` | `WIFI-HW missing` |
| `bluetooth.service` | Inactive |
| `nmcli`, `rfkill` | Present |
| `wpa_supplicant`, `iw`, `bluetoothctl`, `btmgmt` | Missing |
| `modinfo -F firmware brcmfmac` | Asks for 78 files, including `brcm/brcmfmac43455-sdio.bin` |

## Limits

- It was an **x86_64** VM. The Pi image is aarch64, built from the same Fedora kernel config.
- A VM has no WiFi or Bluetooth hardware. This shows what the image ships, not whether a radio
  connects. For real hardware results, see [hardware](../hardware.md).

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
