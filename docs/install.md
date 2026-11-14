# Install on an SD card

This walks through putting the image on a card and logging in for the first time. You need a
built image (see [build](build.md)) or one downloaded from CI.

**1. Flash the card.** Check the device name with `lsblk` first. Flashing erases the card.

```sh
xzcat hummingbird-rpi5-unstable-*.raw.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

**2. Add your SSH key.** The card has a small FAT partition called `CIDATA`. Mount it and open
`user-data`. Replace the placeholder under `ssh_authorized_keys:` with your public key.

If you'd rather do it in one command (the mount path may differ on your system):

```sh
KEY="$(cat ~/.ssh/<key>.pub)"
sed -i "/ssh_authorized_keys:/{n;s|.*|      - $KEY|}" /run/media/$USER/CIDATA/user-data
```

**3. Boot the Pi.** Plug in Ethernet and power it on. It takes about a minute to reach SSH.

**4. Find its IP address.** Check your router's client list for `hummingbird-rpi`. Or scan your
network with `nmap -sn <subnet>` and look for "Raspberry Pi Trading".

**5. Log in.**

```sh
ssh -i ~/.ssh/<key> hummingbird@<ip>
```

Once you're in, try a couple of commands to see what's running:

```sh
bootc status            # which image is running
vcgencmd measure_temp   # CPU temperature
```

## Things you'll likely run into

- After reflashing, SSH warns that the host key changed. Remove the old one with
  `ssh-keygen -R <ip>`.
- `bootc status` may print a `mount: (hint) your fstab has been modified` message. It's
  harmless. `sudo systemctl daemon-reload` clears it.
- To connect to WiFi: `sudo nmcli dev wifi connect <ssid> password <password>`.
- Put firmware settings in `config-bootc-common.txt` on `CIDATA`. Don't edit `config.txt`, since
  rpi-bootc-bootloader rewrites it on every sync.

The firmware partition (p1) isn't mounted at runtime. To read it, mount it read-only:

```sh
sudo mkdir -p /mnt/p1 && sudo mount -o ro /dev/mmcblk0p1 /mnt/p1
sudo ls /mnt/p1          # files are root-only, so use sudo
sudo umount /mnt/p1
```

Next: [upgrades and rollback](upgrades.md).
