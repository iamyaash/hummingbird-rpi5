# Known issues

- **Every Pi probably has the same Bluetooth address.** The chip uses its default address
  (`43:45:C0:00:1F:AC`), because the upstream device tree doesn't give the firmware a
  `local-bd-address`. This only matters if you have more than one Pi nearby.
- **A power cut during an update or rollback can break boot.** After `bootc upgrade` (at the
  reboot) and after `bootc rollback`, rpi-bootc-bootloader copies the kernel and initrd to the
  FAT boot partition (`CIDATA`). It only writes them out to the card at the very end, so if the
  power goes out in the middle, the partition can be left half written. In a test on 2026-11-16
  neither boot entry worked, GPIO6 didn't help, and the card had to be reflashed. Don't power
  off while an update or rollback is running. A fix is in progress in the
  [`fix/bootloader-fsync`](https://github.com/iamyaash/hummingbird-rpi5/tree/fix/bootloader-fsync) branch. It works, but
  it isn't reliable in every case yet, so it's not merged.
- **The fan may run at full speed.** The upstream device tree has no `pwm-fan` node, so nothing
  drives the fan pin. Images built from this change patch the DTBs to add the fan and its trips,
  and a udev rule keeps the PWM on at fan level 0 (see
  [device trees](base-vs-rpi5/device-trees.md#fan-level-0-and-the-udev-rule)). Without the rule,
  the fan runs at full speed whenever the CPU is cool. Older images always run the fan at full
  speed. The udev rule isn't checked on a fresh boot yet.
- **The kernel is tainted.** The unsigned `vcio.ko` and `8250_bcm7271.ko` taint it (flags `O`
  and `E`).
