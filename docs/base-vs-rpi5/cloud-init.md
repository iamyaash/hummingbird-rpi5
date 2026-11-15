# cloud-init

[Back to what we added](packages.md)

## Why we need it

The SD card image is the same for everyone. It has no user account and no SSH key baked in.
cloud-init sets those up on first boot from files you edit on the card, and grows the disk to fill
the card.

| Without it | With it |
|---|---|
| No way to log in | A `hummingbird` user with your SSH key |
| Root filesystem stays at the 8G image size | It grows to fill the card |
| Hostname is `localhost` | `hummingbird-rpi` |

## What we add

| Package | Gives us | From |
|---|---|---|
| `cloud-init` | First-boot setup | Fedora 44 |
| `cloud-utils-growpart` | `growpart`, which cloud-init uses to grow the partition | Fedora 44 |
| `jq` | A JSON tool | Fedora 44 |

## Where it reads its settings

cloud-init uses the **NoCloud** data source. It finds the FAT partition by its label, `CIDATA`,
and reads these files from it:

| File on `CIDATA` | What to change |
|---|---|
| [`user-data`](../../boot-partition/user-data) | Your SSH key, and the hostname if you like |
| [`meta-data`](../../boot-partition/meta-data) | Nothing, it can stay empty |

It only runs once. Changing these files after the first boot does nothing.

## Changes for bootc

On bootc, `/` is a read-only composefs mount, so cloud-init's normal resize steps don't work:

| Normal cloud-init | What we change |
|---|---|
| `growpart` grows the partition behind `/` | [`10-bootc-growpart.cfg`](../../files/etc/cloud/cloud.cfg.d/10-bootc-growpart.cfg) points it at `/sysroot` instead |
| `resizefs` resizes `/` | `cc_resizefs.py` is patched to resize `/var`. AlmaLinux's bootstrap image does the same. |
| Uses `/var/lib/cloud` | [`hummingbird-rpi5.conf`](../../files/usr/lib/tmpfiles.d/hummingbird-rpi5.conf) creates it, since bootc doesn't update `/var` |

The five cloud-init services are enabled in [`70-rpi.preset`](../../files/usr/lib/systemd/system-preset/70-rpi.preset).
`/run/cloud-init` is cleared at build time so it starts fresh on the Pi.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
