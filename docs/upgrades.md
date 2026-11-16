# Upgrades and rollback

`bootc upgrade` and `bootc switch` both work. Automatic updates are off, so a card only changes
when you run one of them yourself.

> **Don't cut the power during an update or rollback.** It can leave the boot partition half
> written, and then the Pi won't boot until you reflash the card. See
> [known issues](known-issues.md).

`bootc upgrade` pulls the `:unstable` tag, which only moves when `main` builds. To run one
specific build, switch to its tag. A pinned tag never moves, so `upgrade` won't find anything
newer until you switch back:

```sh
sudo bootc switch ghcr.io/<owner>/hummingbird-rpi5:unstable-<sha>   # pin one build
sudo bootc switch ghcr.io/<owner>/hummingbird-rpi5:unstable         # follow main again
```

Cards flashed before the move to `unstable` tags still follow `:latest`, which isn't updated any
more. Run the second command once to move them over.

## Rolling back

```sh
sudo bootc rollback
journalctl -b -u rpi-bootc-bootloader-sync.service | tail -1   # wait for "Finished"
sudo reboot
```

This needs a build with rpi-bootc-bootloader `v0.0.8-hb1` or newer. Check with
`rpi-bootc-bootloader version`. After `bootc rollback`, a sync runs by itself and copies the boot
entries to `CIDATA`. It took about 45 seconds on a Pi 5 with an SD card. Wait for it before you
reboot.

Older builds have upstream `v0.0.8`. On those, `bootc rollback` can leave the Pi stuck at boot
(solid green LED, no network) when the two deployments have different kernels. Run
`bootc upgrade` first, or roll back with tryboot.

### Rolling back with tryboot

```sh
sudo rpi-bootc-bootloader sync        # default = the booted one, fallback/tryboot = the other
sudo rpi-bootc-bootloader tryreboot   # boot the other deployment once
```

Then, on the old deployment, keep it:

- On `v0.0.8`, or with `TRYBOOT=1`: `sudo rpi-bootc-bootloader sync`.
- On `v0.0.8-hb1` with `TRYBOOT=0` (the default): `sudo bootc rollback`. A plain `sync` follows
  ostree's boot order, which still has the newer deployment first.

If the tryboot fails, a power cycle goes back to the default. `tryreboot` needs `vcmailbox` in the
image that's currently booted. To boot the fallback entry on power-up, hold GPIO6 to GND (for
example pin 31 to pin 39) while you switch the Pi on.

Be careful with `vcmailbox 0x00038064 4 4 1`. It arms tryboot, so the next boot uses
`tryboot.txt`. To check that `vcmailbox` works without changing anything, read a tag instead:
`vcmailbox 0x00000001 4 4 0` (firmware revision).

## Recovering a card that hangs after a rollback

This only happens on builds with upstream `v0.0.8`. From another machine:

1. Mount the root partition (p3) read-only. `sudo ls -l <root>/ostree/` shows which `boot.N` link
   exists, for example `boot.0 -> boot.0.1`. The directory is root-only, so run this with sudo to
   see the real deployment paths:
   `sudo find <root>/ostree/boot.0.1 -maxdepth 4 -printf '%p -> %l\n'`
2. Back up `bootc/entries/ostree-*/cmdline.txt` on `CIDATA`. Then change the `boot.N` in each
   `ostree=` path so it matches a path that exists.
3. Boot the card. Then `bootc upgrade` to a build with `v0.0.8-hb1`, or roll back with tryboot.

## How the rollback fix works

The patched rpi-bootc-bootloader is in [`bootloader/`](../bootloader/).

- With `TRYBOOT=0` (the default), `sync` makes the entry that ostree boots by default the default
  on `CIDATA`. ostree marks it with `(ostree:0)` in the `title` line of
  `/boot/loader/entries/ostree-*.conf`. After `bootc rollback` that's the old deployment.
- `rpi-bootc-bootloader-sync.path` watches `/boot` and runs `sync` when ostree swaps the
  `/boot/loader` link, so `bootc rollback` syncs by itself. Upgrades are still synced at shutdown
  by the finalize-staged hook.
- When both deployments have the same kernel and initramfs, ostree only swaps the
  `/ostree/boot.N` link and leaves `/boot` alone. No sync runs and none is needed, since the paths
  in `cmdline.txt` still work.
- Each entry folder is rebuilt, so old DTBs and overlays go away.
- With `TRYBOOT=1` (in `/etc/rpi-bootc-bootloader/tryboot.conf`), the booted deployment stays the
  default and the other one is on tryboot, like before.

## Tested on a Pi 5 (2026-11-15)

- `bootc switch` from a build with kernel `7.3.3` to one with `7.2.13`, and back. Both synced at
  shutdown and booted.
- `bootc rollback` from the `7.3.3` build to the `7.2.13` one. The sync ran by itself, the
  `cmdline.txt` paths moved from `boot.0` to `boot.1`, and the Pi rebooted onto the old build.
  This is the case that used to hang.
- `bootc rollback` between two builds with the same kernel. `/boot` didn't change and the paths
  stayed right. Not rebooted.
- After each sync, each entry folder only had that deployment's files.

Not tested yet:

- Rolling back twice in a row. Both deployments need `v0.0.8-hb1` and different kernels.
- `bootc upgrade` with `TRYBOOT=1`.
- A power cut during a sync. Tested on 2026-11-16 and it broke the card. See
  [known issues](known-issues.md).
- The GPIO6 fallback button.

## Checking the state

```sh
sudo ls -l /ostree/                                       # which boot.N link exists
sudo grep -E '^(title|options)' /boot/loader/entries/ostree-*.conf
bootc status
systemctl status rpi-bootc-bootloader-sync.path rpi-bootc-bootloader-sync.service
journalctl -b -u rpi-bootc-bootloader-sync.service
sudo mount -o ro LABEL=CIDATA /mnt
sudo cat /mnt/config-bootc-default.txt /mnt/config-bootc-fallback.txt /mnt/tryboot.txt
sudo sh -c 'cat /mnt/bootc/entries/ostree-*/cmdline.txt'  # boot.N must match ls -l /ostree
sudo ls -l /mnt/bootc/entries/                            # no ostree-N.new left over
sudo less /mnt/rpi-bootc-log.txt                          # trace of the last sync
sudo umount /mnt
```

What's right: `config-bootc-default.txt` points at the entry folder of the `(ostree:0)` entry,
both `cmdline.txt` files use the `boot.N` that exists, and `rpi-bootc-log.txt` is from after the
last change.
