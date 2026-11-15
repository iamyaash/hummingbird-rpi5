# vcmailbox

[Back to Raspberry Pi tools](rpi-tools.md)

## What it is

`vcmailbox` sends a raw message to the VideoCore firmware through [`/dev/vcio`](vcio-device.md)
and prints the reply. Where [`vcgencmd`](vcgencmd.md) gives you named commands, `vcmailbox` takes
the tag number and buffer sizes directly.

It comes from AlmaLinux's `raspberrypi-userland` package.

## Message format

```text
vcmailbox <tag> <buffer size> <request size> <values...>
```

## Examples

| Command | Does | Safe? |
|---|---|---|
| `vcmailbox 0x00000001 4 4 0` | Reads the firmware revision | Yes, read only. Good for checking it works. |
| `vcmailbox 0x00038064 4 4 1` | Arms tryboot, so the next boot uses `tryboot.txt` | **Careful.** It changes the next boot. |

## Why we need it

Most people won't run it by hand. It matters because
`rpi-bootc-bootloader tryreboot` uses it to arm [tryboot](tryboot.md). Without `vcmailbox`, there's
no safe way to test the other deployment.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
