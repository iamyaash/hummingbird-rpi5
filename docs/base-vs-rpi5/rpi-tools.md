# Raspberry Pi tools

[Back to base vs rpi5](README.md)

The Pi has a second processor, the VideoCore GPU, that runs its own firmware. That firmware knows
things Linux doesn't, like the chip temperature or whether the board is being throttled. It also
controls how the Pi boots. These tools are how Linux talks to it.

| Page | What it is |
|---|---|
| [`/dev/vcio`](vcio-device.md) | The device file the tools use to reach the firmware |
| [`vcgencmd`](vcgencmd.md) | Reads firmware info: temperature, throttling, clocks |
| [`vcmailbox`](vcmailbox.md) | Sends raw messages to the firmware |
| [tryboot](tryboot.md) | Boots the other deployment once, as a safe test |

```text
vcgencmd --+
           +--> /dev/vcio --> vcio.ko --> mailbox --> VideoCore firmware
vcmailbox -+
   ^
   +-- rpi-bootc-bootloader tryreboot
```

None of them work on the base image, because Fedora's kernel has no `/dev/vcio`. We add it with
[`vcio.ko`](vcio-ko.md).

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
