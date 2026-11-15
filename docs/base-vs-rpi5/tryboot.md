# tryboot

[Back to Raspberry Pi tools](rpi-tools.md)

## What it is

tryboot is a Pi firmware feature. You set a flag, reboot, and for that **one** boot the firmware
reads `tryboot.txt` instead of `config.txt`. The boot after that goes back to `config.txt`.

That makes it a safe way to try something. If it doesn't boot, a power cycle gets you back.

## How we use it

[rpi-bootc-bootloader](rpi-bootc-bootloader.md) keeps two entries on the FAT partition:

| File | Points at |
|---|---|
| `config.txt` | The default deployment |
| `tryboot.txt` | The other deployment |

So tryboot means "boot the other deployment, once". `bootc rollback` is the normal way to roll
back now. tryboot is for trying the other deployment first, and for builds with upstream
rpi-bootc-bootloader `v0.0.8`, where `bootc rollback` isn't safe.

## Rolling back with tryboot

```sh
sudo rpi-bootc-bootloader sync        # default = booted one, tryboot = the other
sudo rpi-bootc-bootloader tryreboot   # boot the other one once
# now on the old deployment, keep it:
sudo rpi-bootc-bootloader sync        # on v0.0.8, or with TRYBOOT=1
sudo bootc rollback                   # on v0.0.8-hb1 with TRYBOOT=0
```

```text
tryreboot --> vcmailbox arms the flag --> reboot --> firmware reads tryboot.txt
                                                         |
                                     boots? --> sync to keep it
                                     fails? --> power cycle, back to config.txt
```

More detail in [upgrades and rollback](../upgrades.md).

## Things to know

- `tryreboot` needs [`vcmailbox`](vcmailbox.md) and [`/dev/vcio`](vcio-device.md) in the image
  that's **currently booted**.
- To boot the tryboot entry without a working system, hold GPIO6 to GND (for example pin 31 to
  pin 39) while you power on.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
