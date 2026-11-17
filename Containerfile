# Pinned base image. Bump the date tag and digest together.
# The base's Fedora kernel is the one that boots, so a bump also means rebuilding vcio.ko.
ARG BASE_IMAGE=quay.io/hummingbird-community/os-minimal:20261113@sha256:a98c8cf505b1fdde497fa78af26c2d7439f97071cc79cb4e35fc104d6bda4a79

# Only used to build vcio.ko and unpack the kernel. Nothing from it ships.
ARG BUILDER_IMAGE=registry.fedoraproject.org/fedora:44

FROM ${BASE_IMAGE} AS base

# Build against the base image's Fedora kernel:
# - vcio.ko gives us /dev/vcio for vcgencmd, vcmailbox and tryboot. Fedora's kernel doesn't have
#   CONFIG_BCM_VCIO. kernel-devel comes from Koji by exact version, since the Fedora
#   updates repo only has the newest kernel.
# - 8250_bcm7271.ko is the Pi 5 Bluetooth UART driver. Fedora's kernel doesn't have
#   CONFIG_SERIAL_8250_BCM7271. It's the unmodified upstream source, copied in at the kernel's version.
# - Image is the raw arm64 kernel. Fedora's vmlinuz is an EFI zboot wrapper around a
#   zstd payload, and the Pi firmware can't boot that.
FROM ${BUILDER_IMAGE} AS kernel-build
COPY kmod/vcio/ /src/vcio/
COPY kmod/bcm7271-uart/ /src/bcm7271-uart/
RUN --mount=type=bind,from=base,source=/usr/lib/modules,target=/base-modules \
    set -eux; \
    KVER="$(ls /base-modules)"; \
    test "$(echo "$KVER" | wc -w)" = 1; \
    ARCH="${KVER##*.}"; test "$ARCH" = "$(uname -m)"; \
    VER="${KVER%%-*}"; REL="${KVER#*-}"; REL="${REL%.*}"; \
    dnf -y install --setopt=install_weak_deps=False gcc make kmod zstd \
        "https://kojipkgs.fedoraproject.org/packages/kernel/$VER/$REL/$ARCH/kernel-devel-$KVER.rpm"; \
    make -C /src/vcio KDIR="/usr/src/kernels/$KVER"; \
    modinfo -F vermagic /src/vcio/vcio.ko | grep -q "^$KVER "; \
    test "$(cat /src/bcm7271-uart/VERSION)" = "$VER" \
        || { echo "kmod/bcm7271-uart is for $(cat /src/bcm7271-uart/VERSION), kernel is $VER: run make -C kmod/bcm7271-uart update KVERSION=$VER" >&2; exit 1; }; \
    make -C /src/bcm7271-uart KDIR="/usr/src/kernels/$KVER"; \
    BT=/src/bcm7271-uart/8250/8250_bcm7271.ko; \
    modinfo -F vermagic "$BT" | grep -q "^$KVER "; \
    modinfo -F alias "$BT" | grep -qx 'of:N\*T\*Cbrcm,bcm7271-uart'; \
    mkdir -p /out; cp /src/vcio/vcio.ko "$BT" /out/; echo "$KVER" > /out/kver; \
    Z="/base-modules/$KVER/vmlinuz"; \
    test "$(dd if="$Z" bs=1 skip=4 count=4 status=none)" = zimg; \
    test "$(dd if="$Z" bs=1 skip=24 count=4 status=none)" = zstd; \
    OFF="$(od -An -tu4 -j8 -N4 "$Z" | tr -d ' ')"; \
    SIZE="$(od -An -tu4 -j12 -N4 "$Z" | tr -d ' ')"; \
    dd if="$Z" bs=4M iflag=skip_bytes,count_bytes skip="$OFF" count="$SIZE" status=none \
        | zstd -dc > /out/Image; \
    test "$(dd if=/out/Image bs=1 skip=56 count=4 status=none)" = ARMd

FROM ${BASE_IMAGE}

# dnf protects GRUB and shim through /etc/dnf/protected.d. Drop that so dnf can remove them.
RUN rm -f /etc/dnf/protected.d/grub2-efi-aa64.conf \
          /etc/dnf/protected.d/grub2-tools-minimal.conf \
          /etc/dnf/protected.d/shim.conf

# VideoCore firmware, Pi WiFi/BT blobs and vcgencmd/vcmailbox come from the
# AlmaLinux el10 repo. Not the kernel, since we keep the base image's Fedora one.
COPY files/etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10 /etc/pki/rpm-gpg/
COPY files/etc/yum.repos.d/almalinux-rpi.repo /etc/yum.repos.d/

# Fedora 44 repo and its key:
# Hummingbird doesn't ship linux-firmware or brcmfmac-firmware, and the Pi 5 WiFi needs them
COPY files/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-44-primary /etc/pki/rpm-gpg/
COPY files/etc/yum.repos.d/fedora-44-firmware.repo /etc/yum.repos.d/

# Remove the UEFI boot chain and bootupd. Keep the Fedora kernel from the base.
# Install the VideoCore firmware, the WiFi/BT firmware and the tools
# Put the VideoCore firmware in /usr/lib/ostree-boot for the FAT partition
# Empty /boot and clear /var/cache/ldconfig
RUN systemctl disable bootloader-update.service \
    && dnf -y remove grub2-efi-aa64 grub2-tools grub2-tools-minimal grub2-common \
       shim-aa64 efibootmgr bootupd \
    && rm -rf /usr/lib/bootupd /usr/lib/efi \
    && dnf -y install --setopt=install_weak_deps=False raspberrypi2-firmware \
    linux-firmware-raspberrypi raspberrypi-userland brcmfmac-firmware wireless-regdb \
    wpa_supplicant bluez NetworkManager-wifi \
    cloud-init cloud-utils-growpart xfsprogs jq \
    && rpm -q kernel-core \
    && ! rpm -q raspberrypi2-kernel4 \
    && mkdir -p /usr/lib/ostree-boot \
    && mv /boot/bootcode.bin /boot/LICENCE.broadcom /boot/start*.elf /boot/fixup*.dat /usr/lib/ostree-boot/ \
    && rm -rf /boot/* \
    && dnf clean all \
    && rm -rf /run/dnf /var/log/dnf5.log /var/cache/libdnf5 /var/cache/ldconfig

# Get the Fedora kernel booting on the Pi firmware:
# - vmlinuz becomes the raw Image. The .vmlinuz.hmac file hashed the zboot version, so it's removed.
# - vcio.ko goes in extra/ and is loaded at boot from modules-load.d, since there is no device tree node for it.
# - 8250_bcm7271.ko also goes in extra/. It loads through its device tree alias when the Bluetooth UART shows up,
#   and then hci_uart and btbcm bring up hci0.
# - The Pi 5 DTBs go under /usr/share/raspberrypi2-kernel*/<kver>/boot/, which is
#   where rpi-bootc-bootloader copies from. The firmware looks for the downstream file names,
#   so the upstream bcm2712-d-rpi-5-b.dtb gets installed as bcm2712d0-rpi-5-b.dtb.
COPY --from=kernel-build /out/ /tmp/kernel-build/
COPY files/usr/lib/modules-load.d/vcio.conf /usr/lib/modules-load.d/
RUN KVER=$(ls /usr/lib/modules) \
    && test "$KVER" = "$(cat /tmp/kernel-build/kver)" \
    && install -m 0755 /tmp/kernel-build/Image /usr/lib/modules/$KVER/vmlinuz \
    && rm -f /usr/lib/modules/$KVER/.vmlinuz.hmac \
    && install -D -m 0644 /tmp/kernel-build/vcio.ko /usr/lib/modules/$KVER/extra/vcio.ko \
    && install -m 0644 /tmp/kernel-build/8250_bcm7271.ko /usr/lib/modules/$KVER/extra/ \
    && depmod -a $KVER \
    && modinfo -k $KVER vcio > /dev/null \
    && grep -q 'brcm,bcm7271-uart.* 8250_bcm7271$' /usr/lib/modules/$KVER/modules.alias \
    && D=/usr/share/raspberrypi2-kernel-fedora/$KVER/boot \
    && install -D -m 0644 /usr/lib/modules/$KVER/dtb/broadcom/bcm2712-rpi-5-b.dtb $D/bcm2712-rpi-5-b.dtb \
    && install -m 0644 /usr/lib/modules/$KVER/dtb/broadcom/bcm2712-d-rpi-5-b.dtb $D/bcm2712d0-rpi-5-b.dtb \
    && test "$(ls -d /usr/share/raspberrypi2-kernel*/*/boot | wc -l)" = 1 \
    && echo '# Per-deployment firmware settings (board-wide ones go in config-bootc-common.txt).' \
       > /usr/lib/modules/$KVER/rpi-config.txt \
    && rm -rf /tmp/kernel-build /var/cache/ldconfig

# rpi-bootc-bootloader copies each bootc deployment onto the FAT partition
# (bootc/entries/ostree-N/) and switches os_prefix in config.txt.
# It's v0.0.8 kept in bootloader/ and patched for bootc rollback (see the top of the script).
# It needs flock, cmp and diff, so fail if they're missing.
COPY bootloader/rpi-bootc-bootloader /usr/bin/rpi-bootc-bootloader
COPY files/usr/lib/systemd/system/ /usr/lib/systemd/system/
RUN chmod 0755 /usr/bin/rpi-bootc-bootloader \
    && grep -q 'VERSION="v0.0.8-hb1"' /usr/bin/rpi-bootc-bootloader \
    && test -x /usr/bin/flock && test -x /usr/bin/cmp && test -x /usr/bin/diff

# Save and restore the clock, since the Pi has no battery clock. See rpi-clock.service.
# The build time is the floor, so a fresh card's clock never starts before the image was built.
COPY files/usr/libexec/rpi-clock /usr/libexec/rpi-clock
RUN mkdir -p /usr/lib/rpi-clock \
    && date +%s > /usr/lib/rpi-clock/build-time \
    && grep -qE '^[0-9]+$' /usr/lib/rpi-clock/build-time

# cloud-init: grow the partition behind /sysroot and resize /var, because / is
# read-only composefs on ostree. Same patch as AlmaLinux's bootstrap image.
COPY files/etc/cloud/ /etc/cloud/
RUN f="$(echo /usr/lib/python3*/site-packages/cloudinit/config/cc_resizefs.py)" \
    && grep -q 'resize_what = "/"' "$f" \
    && sed -i 's@resize_what = "/"@resize_what = "/var"@' "$f" \
    && rm -f "$(dirname "$f")"/__pycache__/cc_resizefs.*.pyc

# Turn on networking, SSH, Bluetooth, time sync, cloud-init and the boot entry sync
# from a preset
COPY files/usr/lib/systemd/system-preset/70-rpi.preset /usr/lib/systemd/system-preset/
RUN systemctl preset NetworkManager.service sshd.service bluetooth.service chronyd.service \
    cloud-init-main.service cloud-init-local.service cloud-init-network.service \
    cloud-config.service cloud-final.service rpi-bootc-bootloader-sync.path

# The Pi has no battery clock, and Hummingbird's chrony pool doesn't resolve,
# so HTTPS fails on certificate dates. Use Fedora's pool. Fail if that line moves.
RUN grep -q '2\.hummingbird\.pool\.ntp\.org' /etc/chrony.conf \
    && sed -i 's/2\.hummingbird\.pool\.ntp\.org/2.fedora.pool.ntp.org/' /etc/chrony.conf \
    && grep -q '2\.fedora\.pool\.ntp\.org' /etc/chrony.conf

# Create the /var folders for NetworkManager, bluez and cloud-init. bootc doesn't update /var.
COPY files/usr/lib/tmpfiles.d/hummingbird-rpi5.conf /usr/lib/tmpfiles.d/

# brcmfmac drops off WiFi when power save is on, so turn it off.
COPY files/usr/lib/NetworkManager/conf.d/50-rpi-wifi-powersave.conf /usr/lib/NetworkManager/conf.d/

# Replace Hummingbird's kernel args. The Pi 5 debug UART is ttyAMA10, not ttyS0.
COPY files/usr/lib/bootc/kargs.d/00-base.toml /usr/lib/bootc/kargs.d/

# vcgencmd and vcmailbox come from raspberrypi-userland. vcgencmd reads firmware info
# (temperature, throttling), and vcmailbox runs `rpi-bootc-bootloader tryboot`.
# The udev rule lets the video group use them without sudo.
COPY files/usr/lib/udev/rules.d/60-rpi-vcio.rules /usr/lib/udev/rules.d/
RUN test -x /usr/bin/vcgencmd && test -x /usr/bin/vcmailbox

# Rebuild the initramfs with --no-hostonly, since the build machine isn't a Pi. Include the
# filesystem and SD card modules from 30-rpi.conf. Fail the build if any are missing.
COPY files/usr/lib/dracut/dracut.conf.d/30-rpi.conf /usr/lib/dracut/dracut.conf.d/
RUN KVER=$(ls /usr/lib/modules) \
    && dracut --force --no-hostonly --kver "$KVER" "/usr/lib/modules/$KVER/initramfs.img" \
    && lsinitrd "/usr/lib/modules/$KVER/initramfs.img" > /tmp/initrd.lst \
    && for m in xfs erofs overlay mmc_block sdhci sdhci-pltfm sdhci-brcmstb; do \
         grep -qE "/$m\.ko" /tmp/initrd.lst || { echo "initramfs is missing $m" >&2; exit 1; }; \
       done \
    && rm -rf /tmp/initrd.lst /var/cache/ldconfig

RUN rm -rf /run/cloud-init

RUN bootc container lint --fatal-warnings
