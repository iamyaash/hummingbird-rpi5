# Raw kernel Image

[Back to the kernel changes](kernel.md)

## The problem

Fedora ships `vmlinuz` as an EFI zboot file: a small EFI stub with a zstd-compressed kernel
inside. A UEFI bootloader like GRUB knows how to run that. The Pi firmware doesn't. It loads the
kernel straight off the FAT partition and wants the plain arm64 `Image`.

| File | What's inside | Pi firmware can boot it? |
|---|---|---|
| Fedora `vmlinuz` (zboot) | EFI stub + zstd-compressed kernel | No |
| Raw `Image` | The decompressed arm64 kernel | Yes |

## What the build does

The `kernel-build` stage of the [`Containerfile`](../../Containerfile) unwraps it:

| Step | What happens |
|---|---|
| 1 | Check the file really is zboot with zstd (`zimg` and `zstd` magic bytes) |
| 2 | Read the payload offset and size from the header |
| 3 | Cut the payload out and decompress it with `zstd` |
| 4 | Check the result is an arm64 `Image` (`ARMd` magic) |
| 5 | Install it as `/usr/lib/modules/<kver>/vmlinuz` |
| 6 | Remove `.vmlinuz.hmac`, since it hashed the old zboot file |

If any check fails, the build stops.

## Things to know

- It's the same kernel, only decompressed. Nothing is patched.
- It's about 79 MB, much bigger than Fedora's compressed file. That's fine on the FAT partition.
- The file keeps the name `vmlinuz`, so bootc and rpi-bootc-bootloader find it where they expect.

---

*This page was written by Claude Opus 5.5 using data and checks provided by the author.*
