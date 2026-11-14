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
