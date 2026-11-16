# rpi-bootc-bootloader

[Back to the boot changes](boot.md)

## What it is

[rpi-bootc-bootloader](https://github.com/kfox1111/rpi-bootc-bootloader) is a small script by
kfox1111. It does the job GRUB and bootupd do on a normal bootc system: it makes the new
deployment bootable after `bootc upgrade` or `bootc switch`.

We use **v0.0.8**, kept in the repo at [`bootloader/`](../../bootloader/) with a few changes for
`bootc rollback` and power cuts. The patched version reports itself as `v0.0.8-hb2`.

## Why we need it

bootc keeps its deployments and kernels on the XFS partitions. The Pi firmware can only read the
FAT partition (`CIDATA`), so something has to copy each deployment's boot files there.

| Without it | With it |
|---|---|
| The firmware never sees the new kernel | Each deployment gets its own folder on `CIDATA` |
| `bootc upgrade` stages an update that never boots | The next reboot boots the new deployment |
| No fallback if the new one breaks | The old deployment stays there as the tryboot entry |

## What it installs

| File | Does |
|---|---|
| `/usr/bin/rpi-bootc-bootloader` | The script |
| `ostree-finalize-staged.service.d/rpi-bootc-bootloader.conf` | A drop-in that runs a sync when bootc finalizes a staged update at shutdown |
| `rpi-bootc-bootloader-sync.path` and `.service` | Ours, not upstream. Runs a sync when ostree changes `/boot/loader` outside an upgrade, for example on `bootc rollback` |

Both are copied from the repo at build time. The build checks the script's `VERSION` is
`v0.0.8-hb2`.

## What a sync does

```text
bootc upgrade -> reboot -> ostree-finalize-staged.service -> rpi-bootc-bootloader sync
```

`sync` writes to p1 (`CIDATA`):

| Writes | What's in it |
|---|---|
| `bootc/entries/ostree-N/` | `vmlinuz`, `initrd`, `cmdline.txt` and the DTBs for deployment N |
| `config.txt` | `os_prefix` pointing at the default entry, plus an include of `config-bootc-common.txt` |
| `tryboot.txt` | The same, but pointing at the other entry |

It finds p1 by taking the `/sysroot` device and swapping its partition number for 1.

## Commands

| Command | Does |
|---|---|
| `sudo rpi-bootc-bootloader sync` | Rewrite the entries. The default is ostree's default entry (`(ostree:0)`), or the booted deployment with `TRYBOOT=1`. |
| `sudo rpi-bootc-bootloader tryreboot` | Boot the other deployment once. Needs `vcmailbox`, so it needs [`vcio.ko`](vcio-ko.md). |
| `rpi-bootc-bootloader version` | Print the version |

If a tryboot fails, a power cycle goes back to the default.

## Things to know

- Upstream v0.0.8 doesn't sync after `bootc rollback`, so the Pi can get stuck at boot when the
  two deployments have different kernels. It also never deletes files from an entry folder, so
  old DTBs pile up after kernel changes. `v0.0.8-hb1` fixes both, tested on a Pi on 2026-11-15.
  See [how the rollback fix works](../upgrades.md#how-the-rollback-fix-works).
- Upstream v0.0.8 never flushes `CIDATA` before `umount`. Linux keeps the FAT changes in RAM
  and writes them in any order, so a power cut during a sync can leave the FAT table pointing at
  clusters that were never written. Both entry folders become unreadable and GPIO6 can't help.
  This happened on a Pi on 2026-11-16 with `v0.0.8-hb1`. `v0.0.8-hb2` flushes after each step,
  repairs a dirty FAT with `fsck.fat -a` before mounting it, and writes nothing when nothing
  changed. See [power cuts during a sync](../upgrades.md#power-cuts-during-a-sync).
- Don't edit `config.txt` yourself. It's rewritten on every sync. Use `config-bootc-common.txt`.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
