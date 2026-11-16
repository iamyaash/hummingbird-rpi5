#!/bin/bash
# Tests for `rpi-bootc-bootloader sync` (bootloader/rpi-bootc-bootloader), run against fake
# /boot, /sysroot and FAT folders in a temp dir. Nothing is mounted and bootc isn't called.
#
# Usage: tests/bootloader/run.sh
# Needs bash, jq, flock and diffutils. Exits non-zero if a check fails.

set -u

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/bootloader/rpi-bootc-bootloader"
WORK="$(realpath "$(mktemp -d)")"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0

ok() { PASSED=$((PASSED + 1)); echo "ok - $CASE: $1"; }
not_ok() { FAILED=$((FAILED + 1)); echo "not ok - $CASE: $1"; [ -n "${2:-}" ] && echo "    $2"; }

# check <description> <command...>
check() {
	local desc="$1"; shift
	if "$@"; then ok "$desc"; else not_ok "$desc"; fi
}

# ---- fixtures

# new_fixture <name>: empty fake system in $T.
#   $ROOT        what the ostree=, linux and initrd paths in the BLS entries are relative to
#   $BOOT        /boot, with loader -> loader.N/entries/ostree-N.conf
#   $SYS         /sysroot, with ostree/deploy/default/deploy/<name>.0 and ostree/boot.N links
#   $FAT         the FAT partition (already "mounted")
new_fixture() {
	CASE="$1"
	T="$WORK/$1"
	ROOT="$T/root"
	BOOT="$ROOT/boot"
	SYS="$ROOT/sysroot"
	FAT="$T/fat"
	mkdir -p "$BOOT" "$SYS/ostree/deploy/default/deploy" "$FAT"
	ln -s "$SYS/ostree" "$ROOT/ostree"
	rm -f "$T/tryboot.conf"
}

# add_deploy <name> <kver> <file...>: a deployment with checksum <name> and serial 0.
# Files are the DTBs (and overlays/<x>.dtbo) in usr/share/raspberrypi2-kernel-fedora/<kver>/boot.
# Its kernel and initramfs go in /boot/ostree/default-bc<name>/.
add_deploy() {
	local name="$1" kver="$2" f
	shift 2
	local d="$SYS/ostree/deploy/default/deploy/$name.0"
	local dtb="$d/usr/share/raspberrypi2-kernel-fedora/$kver/boot"
	mkdir -p "$dtb/overlays" "$d/usr/lib/modules/$kver" "$BOOT/ostree/default-bc$name"
	for f in "$@"; do
		echo "$name $f" > "$dtb/$f"
	done
	echo "# rpi-config for $name" > "$d/usr/lib/modules/$kver/rpi-config.txt"
	echo "kernel $name $kver" > "$BOOT/ostree/default-bc$name/vmlinuz-$kver"
	echo "initrd $name $kver" > "$BOOT/ostree/default-bc$name/initramfs-$kver.img"
	echo "$kver" > "$T/kver.$name"
}

# set_state <bootversion> <N:name:mark>...: what ostree leaves after a deploy or rollback.
# Writes /boot/loader.<v>/entries/ostree-N.conf for each entry, points /boot/loader at
# loader.<v>, and makes /ostree/boot.<v> -> boot.<v>.0 the only boot.N link.
# mark is the ostree index in the title (0 or 1), or - for no "(ostree:N)" at all.
# With KEEP_OLD=1 the other loader.N and boot.N stay, like halfway through an ostree swap.
set_state() {
	local v="$1" spec n name mark kver title
	shift
	rm -rf "$BOOT/loader.$v" "$SYS/ostree/boot.$v.0"
	mkdir -p "$BOOT/loader.$v/entries"
	if [ "${KEEP_OLD:-0}" != 1 ]; then
		rm -f "$SYS/ostree/boot.0" "$SYS/ostree/boot.1"
	fi
	rm -f "$SYS/ostree/boot.$v"
	ln -s "boot.$v.0" "$SYS/ostree/boot.$v"
	for spec in "$@"; do
		IFS=: read -r n name mark <<<"$spec"
		kver="$(cat "$T/kver.$name")"
		mkdir -p "$SYS/ostree/boot.$v.0/default/bc$name"
		ln -s "$SYS/ostree/deploy/default/deploy/$name.0" "$SYS/ostree/boot.$v.0/default/bc$name/0"
		title="Fedora Linux 44 (Hummingbird)"
		[ "$mark" = - ] || title="$title (ostree:$mark)"
		cat > "$BOOT/loader.$v/entries/ostree-$n.conf" <<EOF
title $title
version $n
options root=UUID=0000 rw console=ttyAMA10,115200 ostree=/ostree/boot.$v/default/bc$name/0
linux /boot/ostree/default-bc$name/vmlinuz-$kver
initrd /boot/ostree/default-bc$name/initramfs-$kver.img
EOF
	done
	ln -sfn "loader.$v" "$BOOT/loader"
}

# set_status <booted name or -> <staged: true|false>: the bootc status --format json the script reads.
set_status() {
	local booted='null' staged='null'
	[ "$1" = - ] || booted="{\"ostree\":{\"checksum\":\"$1\",\"deploySerial\":0}}"
	[ "$2" = true ] && staged='{"ostree":{"checksum":"staged","deploySerial":0}}'
	echo "{\"status\":{\"staged\":$staged,\"booted\":$booted}}" > "$T/status.json"
}

# run_sync [args]: rpi-bootc-bootloader sync on the fixture. Output in $T/out and $T/err.
run_sync() {
	RPI_BOOTC_TMPMNT="$FAT" \
	RPI_BOOTC_BOOT_DIR="$BOOT" \
	RPI_BOOTC_SYSROOT="$SYS" \
	RPI_BOOTC_PATH_PREFIX="$ROOT" \
	RPI_BOOTC_STATUS_JSON="$T/status.json" \
	RPI_BOOTC_NO_MOUNT=1 \
	RPI_BOOTC_TRYBOOT_CONF="$T/tryboot.conf" \
	RPI_BOOTC_LOCK="$T/lock" \
	RPI_BOOTC_FLUSH_LOG="$T/flushes" \
	"$SCRIPT" sync "$@" > "$T/out" 2> "$T/err"
}

# ---- checks

# sync_ok [args]: run_sync and check that it exits 0.
sync_ok() {
	if run_sync "$@"; then
		ok "sync${*:+ $*} exits 0"
	else
		not_ok "sync${*:+ $*} exits 0" "stderr: $(tr '\n' ' ' < "$T/err")"
	fi
}

os_prefix_is() { grep -qx "os_prefix=bootc/entries/ostree-$2/" "$FAT/$1"; }

# expect_default <N> <M>: config-bootc-default.txt boots entry N, fallback and tryboot boot M.
expect_default() {
	check "default is ostree-$1" os_prefix_is config-bootc-default.txt "$1"
	check "fallback is ostree-$2" os_prefix_is config-bootc-fallback.txt "$2"
	check "tryboot is ostree-$2" os_prefix_is tryboot.txt "$2"
}

# The files an entry folder should have for deployment <name>, sorted.
want_files() {
	local kver dtb
	kver="$(cat "$T/kver.$1")"
	dtb="$SYS/ostree/deploy/default/deploy/$1.0/usr/share/raspberrypi2-kernel-fedora/$kver/boot"
	{
		printf '%s\n' vmlinuz initrd cmdline.txt rpi-config.txt overlays
		(cd "$dtb" && find . -type f | sed 's|^\./||')
	} | sort | tr '\n' ' '
}

have_files() { (cd "$1" && find . -mindepth 1 | sed 's|^\./||' | sort | tr '\n' ' '); }

# expect_entry <N> <name> <bootversion>: folder ostree-N holds exactly deployment <name>,
# and its cmdline.txt points at /ostree/boot.<bootversion>.
expect_entry() {
	local e="$FAT/bootc/entries/ostree-$1" kver
	kver="$(cat "$T/kver.$2")"
	check "ostree-$1 has the $2 kernel" grep -qx "kernel $2 $kver" "$e/vmlinuz"
	check "ostree-$1 has the $2 initrd" grep -qx "initrd $2 $kver" "$e/initrd"
	check "ostree-$1 cmdline.txt is ostree=/ostree/boot.$3/default/bc$2/0" \
		grep -qx "root=UUID=0000 rw console=ttyAMA10,115200 ostree=/ostree/boot.$3/default/bc$2/0" "$e/cmdline.txt"
	local want have
	want="$(want_files "$2")"
	have="$(have_files "$e")"
	if [ "$want" = "$have" ]; then
		ok "ostree-$1 has only the $2 files"
	else
		not_ok "ostree-$1 has only the $2 files" "want: $want| have: $have"
	fi
}

sync_fails() { ! run_sync; }
no_warning() { ! grep -q 'Warning' "$T/err"; }
has_warning() { grep -q 'Warning: neither or both BLS entries are marked (ostree:0)' "$T/err"; }
no_new_dirs() { ! ls -d "$FAT"/bootc/entries/*.new > /dev/null 2>&1; }
no_tmp_files() { [ -z "$(find "$FAT" -name '*.tmp')" ]; }
# flushed_before <A> <B>: the FAT was flushed for step A before step B (lines in $T/flushes).
flushed_before() {
	local a b
	a="$(grep -n -x -m1 "$1" "$T/flushes" | cut -d: -f1)"
	b="$(grep -n -x -m1 "$2" "$T/flushes" | cut -d: -f1)"
	[ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]
}
no_flushes() { [ ! -s "$T/flushes" ]; }
# nothing_written_since <marker>: no file or folder on the FAT changed after <marker>.
nothing_written_since() { [ -z "$(find "$FAT" -newer "$1")" ]; }

# Deployments used by most cases: A and B have different kernels, like the AlmaLinux and
# Fedora kernel images on the Pi. A ships more DTBs and overlays than B.
two_kernels() {
	add_deploy A 6.12.115-20261103.v8.1.el10 bcm2712-rpi-5-b.dtb bcm2712d0-rpi-5-b.dtb \
		bcm2711-rpi-4-b.dtb overlays/vc4-kms-v3d.dtbo overlays/disable-bt.dtbo
	add_deploy B 7.2.13-200.fc44.aarch64 bcm2712-rpi-5-b.dtb bcm2712d0-rpi-5-b.dtb
}

# ---- cases

# (a) bootc upgrade, TRYBOOT=0: the finalize-staged hook reads bootc status before
# `ostree admin finalize-staged` (so something is staged) and the BLS entries after it.
new_fixture a-upgrade
two_kernels
add_deploy C 7.3.3-200.fc44.aarch64 bcm2712-rpi-5-b.dtb bcm2712d0-rpi-5-b.dtb
set_state 0 2:B:0 1:A:1
set_status B false
sync_ok
expect_default 2 1
expect_entry 2 B 0
expect_entry 1 A 0
# finalize-staged: C is new and becomes ostree-2 (ostree:0), B moves to ostree-1.
set_state 1 2:C:0 1:B:1
set_status B true
sync_ok
expect_default 2 1
expect_entry 2 C 1
expect_entry 1 B 1
check "no warning" no_warning
check "no ostree-N.new left" no_new_dirs

# (b) bootc rollback across different kernels. Before: B (Fedora kernel) booted and default.
# After `bootc rollback`: /ostree/boot.1 is gone, the BLS entries say boot.0, and A is now
# ostree-2 (ostree:0). Nothing is staged and the FAT folders are stale.
new_fixture b-rollback
two_kernels
set_state 1 2:B:0 1:A:1
set_status B false
sync_ok
expect_default 2 1
expect_entry 2 B 1
expect_entry 1 A 1
set_state 0 2:A:0 1:B:1
check "before the sync the FAT cmdline.txt still says boot.1 (the bug)" \
	grep -q 'ostree=/ostree/boot.1/' "$FAT/bootc/entries/ostree-2/cmdline.txt"
check "before the sync /ostree/boot.1 is gone" test ! -e "$ROOT/ostree/boot.1"
sync_ok
expect_default 2 1
expect_entry 2 A 0
expect_entry 1 B 0
check "no warning" no_warning
# Reboot into A: a sync from there changes nothing, and the folders aren't rewritten.
set_status A false
INODE1="$(stat -c %i "$FAT/bootc/entries/ostree-1")"
INODE2="$(stat -c %i "$FAT/bootc/entries/ostree-2")"
sync_ok
expect_default 2 1
check "unchanged ostree-1 folder is kept" test "$INODE1" = "$(stat -c %i "$FAT/bootc/entries/ostree-1")"
check "unchanged ostree-2 folder is kept" test "$INODE2" = "$(stat -c %i "$FAT/bootc/entries/ostree-2")"
# Roll back a second time, from A back to B.
set_state 1 2:B:0 1:A:1
sync_ok
expect_default 2 1
expect_entry 2 B 1
expect_entry 1 A 1
check "no ostree-N.new left" no_new_dirs

# (c) TRYBOOT=1: the booted deployment stays the default, the other one goes on tryboot.
new_fixture c-tryboot
two_kernels
add_deploy C 7.3.3-200.fc44.aarch64 bcm2712-rpi-5-b.dtb bcm2712d0-rpi-5-b.dtb
echo 'TRYBOOT=1' > "$T/tryboot.conf"
# Upgrade from B to C (after finalize-staged): B stays the default, C is on tryboot.
set_state 1 2:C:0 1:B:1
set_status B true
sync_ok
expect_default 1 2
expect_entry 1 B 1
expect_entry 2 C 1
# Same with --tryboot instead of the config file.
rm -f "$T/tryboot.conf"
sync_ok --tryboot
expect_default 1 2
# After a tryboot into C, a sync from C makes C the default.
echo 'TRYBOOT=1' > "$T/tryboot.conf"
set_status C false
sync_ok
expect_default 2 1
# bootc rollback from C: the paths get fixed, but C (booted) stays the default and B
# goes on tryboot.
set_state 0 2:B:0 1:C:1
sync_ok
expect_default 1 2
expect_entry 1 C 0
expect_entry 2 B 0
# After a tryboot into B, a sync from B finishes the rollback.
set_status B false
sync_ok
expect_default 2 1
check "no warning" no_warning

# (d) A single entry, like the first sync of a new SD card. The old folder's extra files go.
new_fixture d-single
add_deploy A 7.2.13-200.fc44.aarch64 bcm2712-rpi-5-b.dtb bcm2712d0-rpi-5-b.dtb
set_state 0 1:A:0
mkdir -p "$FAT/bootc/entries/ostree-1/overlays"
echo stale > "$FAT/bootc/entries/ostree-1/bcm2711-rpi-4-b.dtb"
echo stale > "$FAT/bootc/entries/ostree-1/overlays/vc4-kms-v3d.dtbo"
set_status A false
sync_ok
expect_default 1 1
expect_entry 1 A 0
# bootc status in the SD image build doesn't know the booted deployment.
set_status - false
sync_ok
expect_default 1 1
expect_entry 1 A 0

# (e) Neither or both entries marked (ostree:0): the old rule, with a warning.
# Not staged: the booted one is the default. Staged: the other one is.
new_fixture e-unmarked
two_kernels
set_state 0 2:A:- 1:B:-
set_status B false
sync_ok
expect_default 1 2
check "warns about the missing (ostree:0)" has_warning
set_status B true
sync_ok
expect_default 2 1
check "warns about the missing (ostree:0)" has_warning
set_state 1 2:A:0 1:B:0
set_status B false
sync_ok
expect_default 1 2
check "warns when both are (ostree:0)" has_warning

# (f) Stale DTBs and overlays from an older kernel are removed from a reused folder, and an
# ostree-N.new left behind by a power cut is cleaned up.
new_fixture f-stale
two_kernels
set_state 0 2:A:0 1:B:1
set_status A false
mkdir -p "$FAT/bootc/entries/ostree-1/overlays" "$FAT/bootc/entries/ostree-2.new"
for f in bcm2711-rpi-4-b.dtb bcm2711-rpi-400.dtb overlays/vc4-kms-v3d.dtbo overlays/disable-bt.dtbo; do
	echo "old kernel $f" > "$FAT/bootc/entries/ostree-1/$f"
done
echo half > "$FAT/bootc/entries/ostree-2.new/vmlinuz"
sync_ok
expect_default 2 1
expect_entry 1 B 0
expect_entry 2 A 0
check "old DTB is gone" test ! -e "$FAT/bootc/entries/ostree-1/bcm2711-rpi-4-b.dtb"
check "old overlay is gone" test ! -e "$FAT/bootc/entries/ostree-1/overlays/vc4-kms-v3d.dtbo"
check "no ostree-N.new left" no_new_dirs

# (g) /boot/loader is swapped while the sync runs: sync runs again and uses the new entries.
# A fake jq swaps the link the first time it's called, which is in the middle of the sync.
new_fixture g-swap-during-sync
two_kernels
set_state 0 2:A:0 1:B:1
KEEP_OLD=1 set_state 1 2:B:0 1:A:1
set_status B false
mkdir -p "$T/bin"
cat > "$T/bin/jq" <<EOF
#!/bin/bash
if [ ! -e "$T/swapped" ]; then
	touch "$T/swapped"
	ln -sfn loader.0 "$BOOT/loader"
fi
exec $(command -v jq) "\$@"
EOF
chmod +x "$T/bin/jq"
PATH="$T/bin:$PATH" sync_ok
check "noticed the swap and synced again" grep -q 'loader changed during sync 1, syncing again' "$T/err"
expect_default 2 1
expect_entry 2 A 0
expect_entry 1 B 0

# (h) A sync waits for the lock held by another one.
new_fixture h-lock
two_kernels
set_state 0 2:A:0 1:B:1
set_status A false
flock "$T/lock" sleep 2 &
LOCKER=$!
sleep 0.3
START="$(date +%s%N)"
sync_ok
END="$(date +%s%N)"
wait "$LOCKER"
check "waited for the lock" test $(( (END - START) / 1000000 )) -ge 1000
expect_default 2 1

# (i) If the non-default entry can't be built, the default one is still fixed, the old
# non-default folder is kept, and sync fails.
new_fixture i-broken-other
two_kernels
set_state 1 2:B:0 1:A:1
set_status B false
sync_ok
set_state 0 2:A:0 1:B:1
rm "$BOOT/ostree/default-bcB/vmlinuz-$(cat "$T/kver.B")"
check "sync fails" sync_fails
expect_default 2 1
expect_entry 2 A 0
check "old ostree-1 folder is kept" grep -qx "kernel A $(cat "$T/kver.A")" "$FAT/bootc/entries/ostree-1/vmlinuz"
check "no ostree-N.new left" no_new_dirs

# (k) hb2: the FAT is flushed after each new folder is written, after each swap, and
# around each config file change, in an order where nothing points at unflushed data.
new_fixture k-flush-order
two_kernels
set_state 1 2:B:0 1:A:1
set_status B false
rm -f "$T/flushes"
sync_ok
expect_default 2 1
check "ostree-1.new flushed before the swap" flushed_before "write ostree-1.new" "swap ostree-1"
check "ostree-2.new flushed before the swap" flushed_before "write ostree-2.new" "swap ostree-2"
check "non-default folder swapped first" flushed_before "swap ostree-1" "write ostree-2.new"
check "both folders flushed before tryboot.txt" flushed_before "swap ostree-2" "write tryboot.txt"
check "both folders flushed before the default changes" flushed_before "swap ostree-2" "rename config-bootc-default.txt"
check "config-bootc-default.txt flushed before and after the rename" \
	flushed_before "write config-bootc-default.txt" "rename config-bootc-default.txt"
check "trace written last" test "$(tail -n1 "$T/flushes")" = "rename rpi-bootc-log.txt"
check "trace is on the FAT" grep -q 'sync_entry' "$FAT/rpi-bootc-log.txt"
check "no *.tmp left" no_tmp_files
check "no config-bootc-working.txt" test ! -e "$FAT/config-bootc-working.txt"
# After a rollback only what changed is flushed again.
set_state 0 2:A:0 1:B:1
rm -f "$T/flushes"
sync_ok
expect_default 2 1
expect_entry 2 A 0
expect_entry 1 B 0
check "rollback swaps ostree-1" grep -qx "swap ostree-1" "$T/flushes"
check "rollback swaps ostree-2" grep -qx "swap ostree-2" "$T/flushes"
check "config.txt not rewritten" test -z "$(grep 'config.txt' "$T/flushes")"

# (l) hb2: a sync with nothing to change writes nothing to the FAT, not even the trace.
new_fixture l-no-change
two_kernels
set_state 1 2:B:0 1:A:1
set_status B false
sync_ok
LOG_BEFORE="$(md5sum < "$FAT/rpi-bootc-log.txt")"
touch "$T/marker"
sleep 0.05
rm -f "$T/flushes"
sync_ok
check "no flushes" no_flushes
check "nothing on the FAT changed" nothing_written_since "$T/marker"
check "old trace kept" test "$LOG_BEFORE" = "$(md5sum < "$FAT/rpi-bootc-log.txt")"
expect_default 2 1

# (m) hb2: what an interrupted sync left behind is removed, and the folders are still
# not rewritten when their contents are right.
new_fixture m-leftovers
two_kernels
set_state 1 2:B:0 1:A:1
set_status B false
sync_ok
INODE1="$(stat -c %i "$FAT/bootc/entries/ostree-1")"
mkdir -p "$FAT/bootc/entries/ostree-2.new"
echo half > "$FAT/bootc/entries/ostree-2.new/vmlinuz"
echo half > "$FAT/bootc/entries/ostree-1/vmlinuz.tmp"
echo half > "$FAT/tryboot.txt.tmp"
echo old > "$FAT/config-bootc-working.txt"
rm -f "$T/flushes"
sync_ok
check "no ostree-N.new left" no_new_dirs
check "no *.tmp left" no_tmp_files
check "config-bootc-working.txt removed" test ! -e "$FAT/config-bootc-working.txt"
check "removal flushed" grep -qx "remove leftovers" "$T/flushes"
check "ostree-1 not rewritten" test "$INODE1" = "$(stat -c %i "$FAT/bootc/entries/ostree-1")"
check "ostree-1 not swapped" test -z "$(grep 'ostree-1' "$T/flushes")"
expect_entry 1 A 1
expect_entry 2 B 1

# (n) hb2: a changed file inside a folder (a damaged kernel copy) is noticed and the
# folder is rebuilt.
new_fixture n-damaged
two_kernels
set_state 1 2:B:0 1:A:1
set_status B false
sync_ok
echo damaged > "$FAT/bootc/entries/ostree-2/vmlinuz"
rm -f "$T/flushes"
sync_ok
check "ostree-2 rebuilt" grep -qx "swap ostree-2" "$T/flushes"
check "ostree-1 left alone" test -z "$(grep 'ostree-1' "$T/flushes")"
expect_entry 2 B 1

# (j) version
CASE=version
check "version is v0.0.8-hb2" test "$("$SCRIPT" version)" = v0.0.8-hb2

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
