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

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
