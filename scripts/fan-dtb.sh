#!/bin/bash
# Add the Pi 5 fan to a DTB with dts/rpi5-fan.dtso, and check the result.
#
# Usage:
#   scripts/fan-dtb.sh apply <in.dtb> <rpi5-fan.dtbo> <out.dtb>
#   scripts/fan-dtb.sh check <dtb>
#
# apply refuses a DTB that already has a pwm-fan node or cooling maps (then upstream has the fan
# and our patch should go), runs fdtoverlay and then check on the result.
# check exits non-zero unless the pwm-fan node, the trips and the cooling maps are all there
# with the values from dts/rpi5-fan.dtso.
# Needs dtc (dtc, fdtget, fdtoverlay). Uses the base DTB's __symbols__ to find the nodes.

set -euo pipefail

die() { echo "fan-dtb: $*" >&2; exit 1; }

# sym <dtb> <label>: the node path for a label
sym() {
	fdtget -t s "$1" /__symbols__ "$2" 2>/dev/null \
		|| die "$1: no __symbols__ entry for $2 (DTB not built with -@?)"
}

# want <dtb> <node> <prop> <type> <value>
want() {
	local got
	got="$(fdtget -t "$4" "$1" "$2" "$3" 2>/dev/null)" || die "$1: $2 has no $3"
	[ "$got" = "$5" ] || die "$1: $2 $3 is '$got', want '$5'"
}

check() {
	local dtb="$1" fan pwm trips maps fan_ph t name temp level
	[ -f "$dtb" ] || die "$dtb: not found"
	fan="$(sym "$dtb" fan)"
	pwm="$(sym "$dtb" rp1_pwm1)"
	trips="$(sym "$dtb" thermal_trips)"
	maps="$(sym "$dtb" cooling_maps)"

	want "$dtb" "$fan" compatible s pwm-fan
	want "$dtb" "$fan" pwms u "$(fdtget -t u "$dtb" "$pwm" phandle) 3 41566 1"
	want "$dtb" "$fan" cooling-levels u "0 75 125 175 250"
	want "$dtb" "$fan" '#cooling-cells' u 2
	want "$dtb" "$pwm" status s okay
	fan_ph="$(fdtget -t u "$dtb" "$fan" phandle)"

	want "$dtb" "$(sym "$dtb" cpu_crit)" temperature u 110000
	want "$dtb" "$(sym "$dtb" cpu_crit)" type s critical
	for t in tepid:50000:1 warm:60000:2 hot:67500:3 vhot:75000:4; do
		IFS=: read -r name temp level <<<"$t"
		want "$dtb" "$trips/cpu-$name" temperature u "$temp"
		want "$dtb" "$trips/cpu-$name" hysteresis u 5000
		want "$dtb" "$trips/cpu-$name" type s active
		want "$dtb" "$maps/map-$name" trip u "$(fdtget -t u "$dtb" "$trips/cpu-$name" phandle)"
		want "$dtb" "$maps/map-$name" cooling-device u "$fan_ph $level $level"
	done
	echo "fan-dtb: $dtb: pwm-fan, 4 active trips and 4 cooling maps ok"
}

apply() {
	local in="$1" dtbo="$2" out="$3" maps
	[ -f "$in" ] || die "$in: not found"
	[ -f "$dtbo" ] || die "$dtbo: not found"
	if dtc -q -I dtb -O dts "$in" | grep -q 'compatible = "pwm-fan"'; then
		die "$in already has a pwm-fan node. Upstream has the fan now, drop dts/rpi5-fan.dtso"
	fi
	maps="$(sym "$in" cooling_maps)"
	[ -z "$(fdtget -l "$in" "$maps")" ] \
		|| die "$in already has cooling maps in $maps. Check dts/rpi5-fan.dtso against it"
	fdtoverlay -i "$in" -o "$out" "$dtbo" || die "fdtoverlay failed on $in"
	check "$out"
}

case "${1:-}" in
	apply) [ $# = 4 ] || die "usage: $0 apply <in.dtb> <rpi5-fan.dtbo> <out.dtb>"; apply "$2" "$3" "$4" ;;
	check) [ $# = 2 ] || die "usage: $0 check <dtb>"; check "$2" ;;
	*) die "usage: $0 apply <in.dtb> <rpi5-fan.dtbo> <out.dtb> | check <dtb>" ;;
esac
