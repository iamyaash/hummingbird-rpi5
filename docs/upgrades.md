# Upgrades and rollback

`bootc upgrade` and `bootc switch` both work. Automatic updates are off, so a card only changes
when you run one of them yourself.

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

Don't use `bootc rollback`. With rpi-bootc-bootloader v0.0.8 it can leave the Pi stuck at boot
(solid green LED, no network) when the two deployments have different kernels. Running `sync`
afterwards fixes the paths, but then the booted deployment becomes the default and the rollback
is ignored. This is being reported upstream.

Use the tryboot method instead:

```sh
sudo rpi-bootc-bootloader sync        # default = the booted one, fallback/tryboot = the other
sudo rpi-bootc-bootloader tryreboot   # boot the other deployment once
# now on the old deployment:
sudo rpi-bootc-bootloader sync        # make it the default
```

On the `fix/bootc-rollback` branch, with `TRYBOOT=0`, the last `sync` doesn't make the old
deployment the default any more. See [testing the rollback fix](#testing-the-rollback-fix-fixbootc-rollback-branch).

If the tryboot fails, a power cycle goes back to the default. `tryreboot` needs `vcmailbox` in the
image that's currently booted. To boot the fallback entry on power-up, hold GPIO6 to GND (for
example pin 31 to pin 39) while you switch the Pi on.

Be careful with `vcmailbox 0x00038064 4 4 1`. It arms tryboot, so the next boot uses
`tryboot.txt`. To check that `vcmailbox` works without changing anything, read a tag instead:
`vcmailbox 0x00000001 4 4 0` (firmware revision).

## Recovering a card that hangs after a rollback

From another machine:

1. Mount the root partition (p3) read-only. `sudo ls -l <root>/ostree/` shows which `boot.N` link
   exists, for example `boot.0 -> boot.0.1`. The directory is root-only, so run this with sudo to
   see the real deployment paths:
   `sudo find <root>/ostree/boot.0.1 -maxdepth 4 -printf '%p -> %l\n'`
2. Back up `bootc/entries/ostree-*/cmdline.txt` on `CIDATA`. Then change the `boot.N` in each
   `ostree=` path so it matches a path that exists.
3. Boot the card and roll back with the tryboot method above.

## Testing the rollback fix (fix/bootc-rollback branch)

This branch has a patched rpi-bootc-bootloader (`v0.0.8-hb1`, in [`bootloader/`](../bootloader/))
that should make `bootc rollback` work. It hasn't been tested on a Pi yet, so the warnings above
still apply.

What's different:

- With `TRYBOOT=0` (the default), `sync` makes the entry that ostree boots by default the default
  on `CIDATA`. ostree marks it with `(ostree:0)` in the `title` line of
  `/boot/loader/entries/ostree-*.conf`. After `bootc rollback` that's the old deployment.
- `rpi-bootc-bootloader-sync.path` watches `/boot` and runs `sync` when ostree swaps the
  `/boot/loader` link, so `bootc rollback` syncs by itself. Upgrades are still synced at shutdown
  by the finalize-staged hook.
- Each entry folder is rebuilt, so old DTBs and overlays go away.
- With `TRYBOOT=1` (in `/etc/rpi-bootc-bootloader/tryboot.conf`), the booted deployment stays the
  default and the other one is on tryboot, like before. A rollback then needs
  `sudo rpi-bootc-bootloader tryreboot`, and once the old deployment is up,
  `sudo rpi-bootc-bootloader sync`.
- With `TRYBOOT=0`, the tryboot method above stops at "boot the other deployment once". To keep it,
  run `sudo bootc rollback` from it.

How to check the state, after each step:

```sh
sudo ls -l /ostree/                                       # which boot.N link exists
sudo grep -E '^(title|options)' /boot/loader/entries/ostree-*.conf
bootc status
systemctl status rpi-bootc-bootloader-sync.path rpi-bootc-bootloader-sync.service
journalctl -b -u rpi-bootc-bootloader-sync.service
sudo mount -o ro LABEL=CIDATA /mnt
cat /mnt/config-bootc-default.txt /mnt/config-bootc-fallback.txt /mnt/tryboot.txt
cat /mnt/bootc/entries/ostree-*/cmdline.txt               # boot.N must match ls -l /ostree
ls -l /mnt/bootc/entries/                                 # no ostree-N.new left over
ls /mnt/bootc/entries/ostree-*/                           # only the files of that deployment
less /mnt/rpi-bootc-log.txt                               # trace of the last sync
sudo umount /mnt
```

What's right: `config-bootc-default.txt` points at the entry folder of the `(ostree:0)` entry,
both `cmdline.txt` files use the `boot.N` that exists, and `rpi-bootc-log.txt` is from after the
last change.

Tests to run on the Pi:

1. **Rollback across different kernels.** Have two deployments with different kernels (for
   example `bootc switch` to a build with an older base image, then reboot). Run
   `sudo bootc rollback`. Before rebooting, check that `rpi-bootc-bootloader-sync.service` ran
   after the rollback and that the files above are right. Reboot: the old deployment comes up
   (`bootc status`, `uname -r`). Reboot again: still the old one.
2. **Rollback twice.** From there, `sudo bootc rollback` again, check, and reboot. The newer
   deployment comes back.
3. **`bootc upgrade` with `TRYBOOT=0`.** Upgrade or switch to a new build and reboot. The new
   one boots, and fallback and tryboot point at the previous one. The sync during shutdown is
   the finalize-staged one: `journalctl -b -1 -u rpi-bootc-bootloader-sync.service` should show
   no run during the shutdown.
4. **`bootc upgrade` with `TRYBOOT=1`.** Run
   `echo TRYBOOT=1 | sudo tee /etc/rpi-bootc-bootloader/tryboot.conf`, upgrade, and reboot. The
   old deployment still boots and the new one is on tryboot. `sudo rpi-bootc-bootloader tryreboot`
   boots the new one, `sudo rpi-bootc-bootloader sync` makes it the default, and a reboot keeps
   it. Remove the file afterwards.
5. **Power cut during a sync.** Watch `journalctl -f -u rpi-bootc-bootloader-sync.service` from a
   second SSH session, run `sudo bootc rollback` between two different kernels, and pull the
   power while the sync runs. The Pi should come up on one of the two deployments. If the cut
   hit the moment the default folder was swapped, the default folder is missing and the boot
   fails, so hold GPIO6 (next test) to boot the fallback. Then run
   `sudo rpi-bootc-bootloader sync` and check that no `ostree-N.new` folder is left.
6. **GPIO6 fallback.** Power off, hold GPIO6 to GND (pin 31 to pin 39) and power on. The
   deployment in `config-bootc-fallback.txt` boots.
