# Build the image

You can let CI build the image, or build it yourself on an arm64 machine.

## Option 1: CI

The workflow is [`.github/workflows/build.yml`](../.github/workflows/build.yml). It runs on a
native arm64 runner and only starts when you trigger it by hand:

```sh
gh workflow run build.yml --ref main
gh run watch
gh run download <run-id> --name hummingbird-rpi5-unstable-sdcard-image
```

Each run does two things:

- Uploads a compressed SD card image (`hummingbird-rpi5-unstable-<date>-<sha>.raw.xz`) as a
  workflow artifact. Artifacts are kept for 14 days.
- Pushes the bootc image to `ghcr.io/<owner>/hummingbird-rpi5`.

The image tags work like this:

| Tag | When it's pushed | What it's for |
|---|---|---|
| `unstable-<date>-<sha>` and `unstable-<sha>` | Every run, from any branch | Pinning one exact build |
| `unstable` | Runs on `main` only | Following `main`. Cards track this tag |

There's no `latest` tag. That name is saved for a stable channel later. Older builds were pushed
as `latest`, but it no longer gets updated and still points to an old build with AlmaLinux's
kernel, so don't track it.

The channel name is set by the `CHANNEL` variable in the workflow.

## Option 2: build locally

You need an arm64 machine with podman. Don't try this on x86: the container builds under qemu,
but `bootc install` fails with `setns: Invalid argument`, because qemu-user is multithreaded.

Run these from the repo root, as root:

```sh
# 1. Build the bootc image
sudo podman build -t localhost/hummingbird-rpi5:unstable -f Containerfile .

# 2. Make the SD card image
#    Arguments: <local image> <image the Pi pulls on upgrade> <output file> [size, default 8G]
sudo scripts/build-sd-image.sh \
  localhost/hummingbird-rpi5:unstable \
  ghcr.io/<owner>/hummingbird-rpi5:unstable \
  hummingbird-rpi5-unstable.raw

# 3. Optional: compress it
xz -T0 hummingbird-rpi5-unstable.raw
```

Next: [install it on an SD card](install.md).
