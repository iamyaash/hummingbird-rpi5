# chrony (time sync)

[Back to base vs rpi5](README.md)

## The problem

The Pi has no battery-backed clock. Every boot it starts with the wrong time until it syncs over
the network. Until then, HTTPS fails, because every certificate looks like it's not valid yet. That
also breaks `bootc upgrade`.

The base image points chrony at `2.hummingbird.pool.ntp.org`, and that name doesn't resolve. So
the clock never gets fixed.

```text
boot -> clock is wrong -> chrony asks 2.hummingbird.pool.ntp.org -> no such name
     -> clock stays wrong -> HTTPS fails on certificate dates
```

## What we change

The [`Containerfile`](../../Containerfile) swaps the pool in `/etc/chrony.conf`:

| Base | hummingbird-rpi5 |
|---|---|
| `2.hummingbird.pool.ntp.org` | `2.fedora.pool.ntp.org` |

It checks the old line is there before changing it and the new line after, so the build fails if a
base image bump moves it. `chronyd.service` is enabled in
[`70-rpi.preset`](../../files/usr/lib/systemd/system-preset/70-rpi.preset).

## Keeping time across reboots

[`rpi-clock.service`](../../files/usr/lib/systemd/system/rpi-clock.service) sets the clock from
the last saved time before chrony starts. It saves on shutdown, and
[`rpi-clock-save.timer`](../../files/usr/lib/systemd/system/rpi-clock-save.timer) saves every
hour, so a power cut loses at most an hour. The saved time is kept in `/var/lib/rpi-clock`. The
image's build time is the floor, so a fresh card never starts before the image was built. The
script is [`rpi-clock`](../../files/usr/libexec/rpi-clock), and its tests are in
[`tests/clock`](../../tests/clock/run.sh).

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
