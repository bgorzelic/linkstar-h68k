# LinkStar H68K — Unofficial Guide, Toolkit & Firmware Archive

<p align="center">
  <img src="./assets/h68k-infographic.svg" alt="LinkStar H68K — Rockchip RK3568 edge router & mini-PC: quad Cortex-A55, Mali-G52 + 0.8-TOPS NPU, LPDDR4, ~32 GB eMMC + microSD, 2× 2.5GbE, Wi-Fi. Flash from a Mac with no maskrom; secure-by-default scripts; checksummed firmware archive." width="100%">
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Docs: CC BY 4.0](https://img.shields.io/badge/Docs-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](./CONTRIBUTING.md)
[![Platform: RK3568](https://img.shields.io/badge/SoC-Rockchip%20RK3568-blue.svg)](./docs/hardware.md)

Everything you need to run, reset, harden, and understand the **Seeed Studio
LinkStar H68K** — the documentation the internet never gave you, plus a set of
idempotent setup/hardening scripts and a checksummed archive of the official
firmware.

> **Unofficial & community-maintained.** Not affiliated with or endorsed by Seeed
> Studio or Rockchip. Firmware images remain the property of their original
> owners (see [`firmware/README.md`](./firmware/README.md)). Everything here is
> provided **as-is** — flashing embedded devices carries risk. Read
> [`docs/flashing-and-recovery.md`](./docs/flashing-and-recovery.md) before you
> touch the bootloader.

---

## What is the LinkStar H68K?

A fanless **Rockchip RK3568** mini-computer / soft-router: quad-core Cortex-A55,
Mali-G52 GPU, a 0.8-TOPS NPU, onboard eMMC + microSD, and — its headline feature
— **two 2.5 GbE ports** (Realtek RTL8125B) plus Wi-Fi. It ships from the factory
with an Android-lineage Ubuntu 20.04 (LXQt) image, and an OpenWRT image is also
available.

It's a great little box. Its documentation, however, is scattered across a wiki,
a few forum posts, and some dead download links. This repo fixes that.

## Why this repo exists

- 💽 **Flash it from a Mac — no maskrom, no Windows.** The vendor only documents
  Windows + RKDevTool + maskrom-to-eMMC. We boot Ubuntu from microSD instead, with
  the tricky bits (RKFW container unpack, the `RKNS` idbloader that fixes the
  black-screen boot) fully scripted. See
  [`docs/flash-ubuntu-sd-from-mac.md`](./docs/flash-ubuntu-sd-from-mac.md).
- 🧭 **Findable, complete docs** — hardware internals, partition/boot layout,
  flashing & recovery, first-boot behavior, and the known driver bugs, all in one place.
- 🔒 **Secure-by-default tooling** — the stock image exposes **unauthenticated ADB
  on the LAN**, **cleartext FTP**, and **no firewall**. Our scripts close all of that.
- 📦 **A firmware archive that won't rot** — official images preserved with
  **SHA256 checksums** so you can always get a verifiable copy.

## Hardware at a glance

| | |
|---|---|
| **SoC** | Rockchip RK3568 — 4× Cortex-A55, Mali-G52 GPU, 0.8-TOPS NPU |
| **RAM** | LPDDR4/4x (unit verified: ~4 GB) |
| **Storage** | ~32 GB eMMC + microSD (boots from either) |
| **Network** | 2× 2.5 GbE (Realtek RTL8125B) + Wi-Fi (MediaTek MT7921 / "M7921E") |
| **OS (stock)** | Ubuntu 20.04.5 LTS (Lubuntu / LXQt), kernel 4.19 vendor BSP |

Full breakdown, sourced and verified: **[`docs/hardware.md`](./docs/hardware.md)**.

## Repository layout

```
linkstar-h68k/
├── docs/                            # the guide — start at docs/README.md
│   ├── flash-ubuntu-sd-from-mac.md  # ⭐ flash Ubuntu to SD from a Mac (no maskrom)
│   ├── how-it-works.md              # RK3568 boot chain + RKFW / idbloader internals
│   ├── flashing-and-recovery.md     # all flashing paths + maskrom/eMMC recovery
│   ├── os-images/                   # image matrix + archived vendor release note
│   └── (hardware, known-issues, hardening, networking… — in progress)
├── scripts/                         # idempotent bash tooling (see scripts/README.md)
│   ├── unpack-rkfw.sh               # RKFW vendor image → partition images
│   ├── build-idbloader.sh           # → RKNS rksd loader (black-screen fix)
│   ├── build-sd-image.sh            # write a bootable Ubuntu SD
│   ├── discover.sh                  # find the device on your subnet (-Pn)
│   ├── fix-networking.sh            # one sane network stack (systemd-networkd)
│   ├── expand-rootfs.sh             # grow rootfs to fill the card
│   ├── harden.sh                    # disable adb/FTP, firewall, SSH keys
│   ├── first-setup.sh               # hostname, updates, timezone, admin user
│   └── lib/common.sh                # shared helpers
└── firmware/                        # download links + SHA256 (NOT the binaries)
    ├── README.md
    └── SHA256SUMS
```

## Quick start

**Flash Ubuntu to an SD card** (on your Mac/Linux workstation — full guide in
[`docs/flash-ubuntu-sd-from-mac.md`](./docs/flash-ubuntu-sd-from-mac.md)):

```bash
scripts/unpack-rkfw.sh   ubuntu20.04-...-update.img  ./work/parts
scripts/build-idbloader.sh  MiniLoaderAll.bin  ./work/idbloader.img
scripts/build-sd-image.sh   ./work/parts  ./work/idbloader.img  /dev/diskN   # DESTRUCTIVE
```

**Find a running unit on your network** (it blocks ping but answers on SSH, so a
normal ping-sweep misses it):

```bash
scripts/discover.sh            # auto-detects your subnet CIDR (often a /22)
```

**Secure & set up a running unit** (copy the toolkit over, then run on the device):

```bash
scp -r scripts <you>@<device-ip>:~/
ssh <you>@<device-ip>
sudo ~/scripts/fix-networking.sh
sudo ~/scripts/expand-rootfs.sh
sudo ~/scripts/harden.sh --pubkey-file ~/.ssh/authorized_keys
```

See [`scripts/README.md`](./scripts/README.md) for every flag and a `--dry-run` mode.

## Documentation

Start at **[`docs/README.md`](./docs/README.md)** for the full table of contents.

## Firmware & OS images

Images are **not** stored in git (they're multi-GB). Instead,
[`firmware/README.md`](./firmware/README.md) lists every official image with its
**SHA256**, and mirrors are published to GitHub Releases / the Internet Archive
for permanence. Verify any download with:

```bash
shasum -a 256 -c firmware/SHA256SUMS
```

## Roadmap

- **v0.1.0 — Ubuntu base**: core docs + hardening/setup scripts + Ubuntu image manifest.
- **v0.2.0 — OpenWRT / LuCI**: OpenWRT track docs + image manifest.
- Later: NVMe/boot-from-SD guides, kernel/driver notes, automated first-boot image.

## Contributing

Corrections and additions from other H68K owners are very welcome — see
[`CONTRIBUTING.md`](./CONTRIBUTING.md). Facts should cite a source; guesses should
be labeled as such.

## License & credits

- Scripts & original docs: **MIT** (docs also **CC BY 4.0**) — see [`LICENSE`](./LICENSE).
- Hardware, stock firmware, and release notes are **© Seeed Studio / Rockchip** and
  their respective owners; mirrored here with attribution for preservation only.
- Maintained by Brian Gorzelic / AI Aerial Solutions and contributors.
