Hummingbird on Raspberry Pi 5 (unstable)
=========================================

This is an unstable test build, so expect things to change or break between builds.

Before the first boot, edit user-data on this partition:

  - Put your SSH public key under ssh_authorized_keys, replacing the placeholder line.
  - Optionally set a password for logging in on the HDMI console (see the comments in the file).

Plug in Ethernet and power on the Pi. It shows up as hummingbird-rpi in your router's client
list. Log in with:

  ssh -i <your-key> hummingbird@<ip>

Don't edit config.txt. rpi-bootc-bootloader rewrites it on every update. Put firmware settings in
config-bootc-common.txt instead. Don't add device tree overlay (dtoverlay) lines: the kernel uses
the upstream Fedora device trees, and no overlays ship with it.

To roll back, run "sudo bootc rollback", wait for rpi-bootc-bootloader-sync.service to finish,
then reboot. Builds older than rpi-bootc-bootloader v0.0.8-hb1 can't do this safely, so run
"bootc upgrade" on those first. The repo's docs/upgrades.md has the details.
