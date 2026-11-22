#!/bin/bash
# Tests for the fan DTB patch (dts/rpi5-fan.dtso and scripts/fan-dtb.sh), run against unpatched
# Pi 5 DTBs from the Fedora kernel, in a temp dir.
#
# Usage: tests/fan-dtb/run.sh <bcm2712-rpi-5-b.dtb> [<bcm2712-d-rpi-5-b.dtb>...]
# The DTBs are in /usr/lib/modules/<kver>/dtb/broadcom/ in the base image.
# Needs bash and dtc (dtc, fdtget, fdtoverlay). Exits non-zero if a check fails.
#
# To check the DTBs in a built image instead, run scripts/fan-dtb.sh check on
# /usr/share/raspberrypi2-kernel-fedora/<kver>/boot/*.dtb.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TOOL="$REPO/scripts/fan-dtb.sh"
WORK="$(realpath "$(mktemp -d)")"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0

ok() { PASSED=$((PASSED + 1)); echo "ok - $1"; }
not_ok() { FAILED=$((FAILED + 1)); echo "not ok - $1"; }

# check <description> <command...>: passes if the command succeeds
check() {
	local desc="$1"; shift
	if "$@" > "$WORK/out" 2>&1; then ok "$desc"; else not_ok "$desc"; sed 's/^/    /' "$WORK/out"; fi
}

# refuse <description> <command...>: passes if the command fails
refuse() {
	local desc="$1"; shift
	if "$@" > "$WORK/out" 2>&1; then not_ok "$desc"; else ok "$desc"; fi
}

[ $# -ge 1 ] || { echo "usage: $0 <unpatched Pi 5 dtb>..." >&2; exit 2; }
for t in dtc fdtget fdtoverlay; do
	command -v "$t" > /dev/null || { echo "$t not found, install dtc" >&2; exit 2; }
done

DTBO="$WORK/rpi5-fan.dtbo"
check "overlay compiles" dtc -@ -I dts -O dtb -o "$DTBO" "$REPO/dts/rpi5-fan.dtso"

for src in "$@"; do
	b="$(basename "$src" .dtb)"
	out="$WORK/$b.dtb"
	refuse "$b: unpatched DTB fails the check" "$TOOL" check "$src"
	check "$b: patch applies and checks out" "$TOOL" apply "$src" "$DTBO" "$out"
	check "$b: patched DTB passes the check again" "$TOOL" check "$out"
	refuse "$b: patching twice is refused" "$TOOL" apply "$out" "$DTBO" "$WORK/$b.twice.dtb"
	check "$b: pwm-fan is at /pwm-fan" fdtget -t s "$out" /pwm-fan compatible
	check "$b: model is unchanged" \
		test "$(fdtget -t s "$src" / model)" = "$(fdtget -t s "$out" / model)"
done

refuse "a missing DTB is refused" "$TOOL" apply "$WORK/missing.dtb" "$DTBO" "$WORK/x.dtb"

echo "$PASSED passed, $FAILED failed"
[ "$FAILED" = 0 ]
