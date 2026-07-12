# Releasing (reproducible builds)

How to cut a release so anyone — including future-you building the next OS version —
gets the **same artifacts from the same inputs**. Reproducibility rests on three
pins:

1. **Pinned inputs** — every vendor image is fixed by SHA256 in
   [`../firmware/SHA256SUMS`](../firmware/SHA256SUMS).
2. **Pinned tools** — the Rockchip toolchain is fetched at exact commits by
   [`../scripts/bootstrap-tools.sh`](../scripts/bootstrap-tools.sh).
3. **One command** — [`../scripts/build-release.sh`](../scripts/build-release.sh)
   chains unpack → idbloader → (optional) flash and emits a checksummed manifest.

## Prerequisites

```bash
# macOS build host
brew install automake autoconf libtool libusb pkg-config
# Docker Desktop (rkbin's mkimage runs as linux/amd64)

# Debian/Ubuntu build host
sudo apt-get install -y build-essential autoconf automake libtool \
  libusb-1.0-0-dev pkg-config docker.io
```

## Cut a release

```bash
# 1. Get + verify the vendor image (see firmware/README.md for the source URL)
shasum -a 256 -c firmware/SHA256SUMS        # the target image line must say "OK"

# 2. Build the pinned toolchain (once per machine)
scripts/bootstrap-tools.sh
export RKDEVELOPTOOL="$PWD/tools/rkdeveloptool/rkdeveloptool"
export RKBIN="$PWD/tools/rkbin"

# 3. Build the release artifacts (add /dev/diskN to also flash a test card)
scripts/build-release.sh  path/to/ubuntu20.04-...-update.img  ./work

# 4. Verify + smoke-test
( cd work && shasum -a 256 -c SHA256SUMS )   # artifacts reproduce
#   → flash a card, boot a real H68K, confirm it comes up (see flash-ubuntu-sd-from-mac.md)
```

`work/release-manifest.txt` records the vendor-image hash, the idbloader hash, and
the tool paths used — attach it to the GitHub Release for provenance.

## Publish

- **GitHub Release** — tag `-<track>/v<x.y>` (below), attach the sub-2 GB images
  (EraseFlash, OpenWRT, bootloader) + `release-manifest.txt` + `SHA256SUMS`.
- **Internet Archive** — upload every image (including the >2 GB Ubuntu files GitHub
  can't hold) to a permanent item; this is the "forever" mirror.
- Update [`../firmware/README.md`](../firmware/README.md) with the new download URLs
  and add any new checksums to [`../firmware/SHA256SUMS`](../firmware/SHA256SUMS).

## Versioning & release tracks

Tag as `<track>/v<major>.<minor>` so multiple OS lines coexist:

| Track | Status | Notes |
|-------|--------|-------|
| `ubuntu-20.04` | **v0.1.0 (current)** | Stock vendor Lubuntu 20.04, hardened |
| `ubuntu-latest` | planned | Upgrade to the newest supported Ubuntu, then release |
| `openwrt` | planned | OpenWRT / LuCI track (image already catalogued) |
| *(other OSes)* | exploratory | Armbian / Debian / etc. — evaluate & add as tracks |

## Adding a new OS track (e.g. Ubuntu-latest, Armbian)

The pipeline is parameterized by **vendor image + partition layout**, so a new track
is the same runbook with different inputs:

1. Obtain the new vendor/base image; add it to `firmware/README.md` + `SHA256SUMS`.
2. `unpack-rkfw.sh` it and read the embedded `parameter.txt`.
3. **Check the partition layout.** `build-sd-image.sh` currently hard-codes the
   Ubuntu-20.04 layout; if the new image's `parameter.txt` differs, update the
   `LAYOUT` table (or generalize it to parse `parameter.txt`) and set the correct
   rootfs PARTUUID. This is the one step that isn't yet fully auto-derived.
4. `build-release.sh` → flash → **boot a real unit** and verify before tagging.
5. Carry the fixes forward (host-key regen, networking, harden) via the first-boot
   overlay so every track is secure-by-default.

## Reproducibility checklist

- [ ] Vendor image verified against `SHA256SUMS`
- [ ] `bootstrap-tools.sh` refs pinned to commits (not `master`) for the release
- [ ] `build-release.sh` run clean; `work/SHA256SUMS` re-verifies
- [ ] Booted and smoke-tested on real hardware
- [ ] `release-manifest.txt` attached to the GitHub Release
- [ ] Images mirrored to the Internet Archive; `firmware/README.md` URLs updated
