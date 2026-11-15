# /dev/vcio

[Back to Raspberry Pi tools](rpi-tools.md)

## What it is

`/dev/vcio` is a character device. A program opens it and sends a message with an `ioctl` call.
The kernel passes it through the mailbox to the VideoCore firmware and hands back the reply.

It's a door to the firmware. It doesn't do anything on its own.

## Who uses it

| User | For |
|---|---|
| [`vcgencmd`](vcgencmd.md) | Reading temperature, clocks, voltages, throttling |
| [`vcmailbox`](vcmailbox.md) | Raw mailbox messages |
| [tryboot](tryboot.md) | Through `vcmailbox`, setting the flag that boots the other deployment |

## Base image vs hummingbird-rpi5

| | Base image | hummingbird-rpi5 |
|---|---|---|
| `CONFIG_BCM_VCIO` | Not set | Still not set, it's the same kernel |
| `/dev/vcio` | Missing | Created by [`vcio.ko`](vcio-ko.md) |
| Loaded at boot | n/a | Yes, from `modules-load.d/vcio.conf` |
| Owner and mode | n/a | `root:video`, `0660` |

## Checking it

```sh
ls -l /dev/vcio          # crw-rw---- root video
lsmod | grep vcio
```

Users in the `video` group can use it without sudo. The `hummingbird` user made by cloud-init is
in that group.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
