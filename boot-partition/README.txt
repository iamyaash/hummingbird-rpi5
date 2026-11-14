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

Don't run "bootc rollback". It can leave the Pi unable to boot. To roll back, run
"rpi-bootc-bootloader sync", then "rpi-bootc-bootloader tryreboot", then
"rpi-bootc-bootloader sync" again. The repo's docs/upgrades.md has the details.
