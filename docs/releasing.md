# Releasing (reproducible builds)

<sub>[Home](../README.md) › [Docs](README.md) › Releasing</sub>

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

Tag as `<track>[-<flavor>]-<osversion>/v<major>.<minor>` so tracks *and* flavors coexist
(see [`../flavors/README.md`](../flavors/README.md) for the matrix):

| Release / track | Type | Status | Notes |
|-----------------|------|--------|-------|
| `ubuntu-desktop-20.04` | Ubuntu flavor | **v0.1.0 ✅** | Stock Lubuntu 20.04 (LXQt), hardened |
| `ubuntu-desktop-24.04` | Ubuntu flavor | in progress | Upgraded to 24.04, LXQt |
| `ubuntu-server-24.04` | Ubuntu flavor | in progress | Headless ([`flavors/server.sh`](../flavors/server.sh)) |
| `ubuntu-casaos-24.04` | Ubuntu flavor | in progress | CasaOS home cloud ([`flavors/casaos.sh`](../flavors/casaos.sh)) |
| `ubuntu-ai-24.04` | Ubuntu flavor | planned | Edge-AI: RK3568 NPU (RKNN) + Python ML ([`flavors/ai.sh`](../flavors/ai.sh)) |
| `ubuntu-hacker-24.04` | Ubuntu flavor | planned | Pentest / security toolkit ([`flavors/hacker.sh`](../flavors/hacker.sh)) |
| `openwrt` | OS track | planned | Router / LuCI (vendor image catalogued) |
| `immortalwrt` | OS track | planned | Router fork — 2.5 G + Wi-Fi work (mainline drivers) |
| `armbian` | OS track | planned | Mainline-kernel base (Wi-Fi / 2.5 G work) |
| `debian` | OS track | exploratory | via Armbian |
| `android` | OS track | planned | Vendor A11 (no Wi-Fi); A13/14 build-from-SDK |
| `libreelec` | OS track | exploratory | Kodi media center |
| `batocera` | OS track | exploratory | Retro gaming |
| `openmediavault` | appliance / Armbian | exploratory | NAS web UI |
| `dietpi` | appliance / Armbian | exploratory | Minimal server |
| `home-assistant` | appliance | exploratory | Home automation |
| `manjaro-arm` | OS track | exploratory | Arch (HDMI caveat) |
| `buildroot` | OS track | exploratory | Custom / minimal |

Community-track detail: [alternative-os.md](alternative-os.md). Ubuntu flavors are built from
one base — [`../flavors/README.md`](../flavors/README.md).

## Adding a new OS track (e.g. Ubuntu-latest, Armbian)

The pipeline is parameterized by **vendor image + partition layout**, so a new track
is the same runbook with different inputs:

1. Obtain the new vendor/base image; add it to `firmware/README.md` + `SHA256SUMS`.
2. `unpack-rkfw.sh` it and read the embedded `parameter.txt`.
3. **Partition layout is auto-derived.** `build-sd-image.sh` reads the layout + rootfs
   PARTUUID from the image's own `parameter.txt`, so a differing layout is handled
   automatically. (An in-place `apt` upgrade keeps the same layout — nothing changes.)
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
