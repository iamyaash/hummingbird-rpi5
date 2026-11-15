# rpi-bootc-bootloader

[Back to the boot changes](boot.md)

## What it is

[rpi-bootc-bootloader](https://github.com/kfox1111/rpi-bootc-bootloader) is a small script by
kfox1111. It does the job GRUB and bootupd do on a normal bootc system: it makes the new
deployment bootable after `bootc upgrade` or `bootc switch`.

We use **v0.0.8**, kept in the repo at [`bootloader/`](../../bootloader/) with a few changes for
`bootc rollback`. The patched version reports itself as `v0.0.8-hb1`.

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
`v0.0.8-hb1`.

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

- `bootc rollback` doesn't work well with v0.0.8. It can leave the Pi stuck at boot when the two
  deployments have different kernels. Use the tryboot steps in
  [upgrades and rollback](../upgrades.md) instead.
- Upstream v0.0.8 never deletes files from an entry folder, so old DTBs pile up after kernel
  changes. See [known issues](../known-issues.md). The patched copy rebuilds each folder, which is
  not yet tested on a Pi. The rollback fix isn't either, see
  [testing the rollback fix](../upgrades.md#testing-the-rollback-fix-fixbootc-rollback-branch).
- Don't edit `config.txt` yourself. It's rewritten on every sync. Use `config-bootc-common.txt`.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
