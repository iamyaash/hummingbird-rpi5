# Known issues

- **Every Pi probably has the same Bluetooth address.** The chip uses its default address
  (`43:45:C0:00:1F:AC`), because the upstream device tree doesn't give the firmware a
  `local-bd-address`. This only matters if you have more than one Pi nearby.
- **HDMI is untested.** `vc4` loads and logs a harmless upstream `vc4-drm ... late IOMMU probe`
  warning.
- **The power button is untested.** The boot log shows `gpio-keys ... Unable to get irq number for
  GPIO 0`.
- **`bootc rollback` on older builds.** Builds with upstream rpi-bootc-bootloader `v0.0.8` can
  get stuck at boot after `bootc rollback`. Upgrade first. See
  [upgrades and rollback](upgrades.md).
- **A power cut during a boot partition sync is untested.** If it hits while the default entry
  folder is being replaced, hold GPIO6 to boot the fallback.
- **The kernel is tainted.** The unsigned `vcio.ko` and `8250_bcm7271.ko` taint it (flags `O`
  and `E`).
