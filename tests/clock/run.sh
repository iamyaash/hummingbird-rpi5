#!/bin/bash
# shellcheck disable=SC2016,SC2034  # checks are strings that run later with eval
# Tests for files/usr/libexec/rpi-clock, in a temp dir. The clock is never changed:
# restore runs with RPI_CLOCK_DRY=1, which prints the time it would set.
#
# Usage: tests/clock/run.sh
# Needs bash and coreutils. Exits non-zero if a check fails.

set -u

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/files/usr/libexec/rpi-clock"
WORK="$(realpath "$(mktemp -d)")"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0

ok() { PASSED=$((PASSED + 1)); echo "ok - $1"; }
not_ok() { FAILED=$((FAILED + 1)); echo "not ok - $1"; }

# check <description> <shell condition>: the condition runs in this shell, so it can use $STATE etc.
check() {
	local desc="$1" cond="$2"
	if eval "$cond"; then ok "$desc"; else not_ok "$desc"; fi
}

PAST=1000000000      # 2001-09-09, before now
FUTURE=4000000000    # 2096, after now

# new_case <name>: a fresh state file and build-time file for this case.
new_case() {
	STATE="$WORK/$1/saved-time"
	FLOOR="$WORK/$1/build-time"
	mkdir -p "$WORK/$1"
	export RPI_CLOCK_STATE="$STATE" RPI_CLOCK_FLOOR="$FLOOR"
}

dry_restore() { RPI_CLOCK_DRY=1 "$SCRIPT" restore; }

# ---- restore

new_case no-files
check "restore with no files leaves the clock alone" \
	'dry_restore | grep -q "no saved time"'

new_case state-ahead
echo "$FUTURE" > "$STATE"
check "restore uses a saved time ahead of now" \
	'[ "$(dry_restore)" = "$FUTURE" ]'

new_case state-behind
echo "$PAST" > "$STATE"
check "restore ignores a saved time behind now" \
	'dry_restore | grep -q "already ahead"'

new_case floor-only
echo "$FUTURE" > "$FLOOR"
check "restore uses the build time when there is no saved time" \
	'[ "$(dry_restore)" = "$FUTURE" ]'

new_case floor-newer
echo "$PAST" > "$STATE"
echo "$FUTURE" > "$FLOOR"
check "restore prefers the build time when it's newer than the saved time" \
	'[ "$(dry_restore)" = "$FUTURE" ]'

new_case state-newer
echo "$FUTURE" > "$STATE"
echo "$PAST" > "$FLOOR"
check "restore prefers the saved time when it's newer than the build time" \
	'[ "$(dry_restore)" = "$FUTURE" ]'

new_case garbage-state
echo "not a number" > "$STATE"
check "restore ignores a saved time that isn't a number" \
	'dry_restore | grep -q "no saved time"'

# ---- save

new_case save-writes
before="$(date +%s)"
"$SCRIPT" save
after="$(date +%s)"
check "save writes the current time" \
	'saved="$(cat "$STATE")"; [ "$saved" -ge "$before" ] && [ "$saved" -le "$after" ]'
check "save leaves no temp files behind" \
	'[ "$(ls -A "$WORK/save-writes" | wc -l)" = 1 ]'

new_case save-before-floor
echo "$FUTURE" > "$FLOOR"
"$SCRIPT" save 2> "$WORK/save-before-floor.err"
check "save skips when the clock is before the build time" \
	'[ ! -e "$STATE" ]'
check "save warns when it skips" \
	'grep -q "before the image build time" "$WORK/save-before-floor.err"'

# ---- usage

check "an unknown command fails" \
	'! "$SCRIPT" nope 2>/dev/null'

echo "# $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
