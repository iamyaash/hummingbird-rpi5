# Known issues

- **Every Pi probably has the same Bluetooth address.** The chip uses its default address
  (`43:45:C0:00:1F:AC`), because the upstream device tree doesn't give the firmware a
  `local-bd-address`. This only matters if you have more than one Pi nearby.
- **HDMI is untested.** `vc4` loads and logs a harmless upstream `vc4-drm ... late IOMMU probe`
  warning.
- **The power button is untested.** The boot log shows `gpio-keys ... Unable to get irq number for
  GPIO 0`.
- **No `bootc rollback`.** See [upgrades and rollback](upgrades.md).
- **Old files pile up on the FAT partition.** rpi-bootc-bootloader never deletes files from an
  entry folder, so old DTBs and overlays stay around after a kernel change.
- **The kernel is tainted.** The unsigned `vcio.ko` and `8250_bcm7271.ko` taint it (flags `O`
  and `E`).
