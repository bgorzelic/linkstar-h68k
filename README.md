# LinkStar H68K — Unofficial Guide, Toolkit & Firmware Archive

<p align="center">
  <img src="./assets/h68k-infographic.svg" alt="LinkStar H68K — Rockchip RK3568 edge router & mini-PC: quad Cortex-A55, Mali-G52 + 0.8-TOPS NPU, LPDDR4, ~32 GB eMMC + microSD, 2× 2.5GbE, Wi-Fi. Flash from a Mac with no maskrom; secure-by-default scripts; checksummed firmware archive." width="100%">
</p>

[![Live showcase](https://img.shields.io/badge/showcase-live-b15bff.svg)](https://bgorzelic.github.io/linkstar-h68k/)
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

## Contents

[What is it?](#what-is-the-linkstar-h68k) ·
[The workflow](#the-complete-workflow) ·
[Quick start](#quick-start) ·
[Hardware](#hardware-at-a-glance) ·
[Docs](#documentation) ·
[Firmware](#firmware--os-images) ·
[Roadmap](#roadmap) ·
[Credits](#license--credits)

## Pick your path

New here? Find yourself in the table and jump straight to the right guide — no need to
read the whole thing.

> 🎛️ **Prefer to click, not read?** The **[SpookyWrt Control WebUI](https://bgorzelic.github.io/linkstar-h68k/webui/)**
> configures your box visually — build a custom OpenWRT image or preview first-run setup,
> then download a ready first-boot script. ([source](./webui/index.html))

| I want to… | Start here |
|------------|-----------|
| 🎛️ **Configure my box the easy way** (visual) | [SpookyWrt Control WebUI](https://bgorzelic.github.io/linkstar-h68k/webui/) |
| 🟢 **Just get Ubuntu running** on my H68K | [Flash it from a Mac](./docs/flash-ubuntu-sd-from-mac.md) |
| 🔒 **Secure a unit I already have** (it ships wide open) | [Hardening](./docs/hardening.md) |
| 🖥️ **Run a desktop, server, or home cloud** | [Flavors](./flavors/README.md) · [CasaOS](./docs/casaos.md) |
| 🌐 **Use it as a router / firewall** | [OpenWRT & other Linux](./docs/alternative-os.md) |
| 🗄️ **Run a NAS / web-managed appliance** | [Cockpit + Samba + firewall](./docs/appliance-cockpit-nas-firewall.md) |
| 🤖 **Run edge AI / local LLMs** | [AI flavor](./flavors/README.md) (RK3568 NPU + Ollama) |
| 🕵️ **Build a pentest / security box** | [Hacker flavor](./flavors/README.md) (authorized use) |
| 💽 **Install to internal storage (Windows/eMMC)** | [eMMC over USB](./docs/flash-emmc-windows.md) |
| ⬆️ **Upgrade Ubuntu to the latest** | [Upgrading](./docs/upgrading.md) |
| 🧠 **Understand how it boots** | [How it works](./docs/how-it-works.md) |
| 🆘 **Fix something that's broken** | [Known issues & fixes](./docs/known-issues.md) |
| 📦 **Build my own release image** | [Releasing](./docs/releasing.md) |

## What is the LinkStar H68K?

A fanless **Rockchip RK3568** mini-computer / soft-router: quad-core Cortex-A55,
Mali-G52 GPU, a 0.8-TOPS NPU, onboard eMMC + microSD, and — its headline feature —
**four Ethernet ports** (2× 2.5 GbE + 2× 1 GbE) plus optional Wi-Fi 6. It ships from
the factory with an Android-lineage Ubuntu 20.04 (LXQt) image, and an OpenWRT image
is also available.

It's a great little box. Its documentation, however, is scattered across a wiki,
a few forum posts, and some dead download links. This repo fixes that.

<p align="center">
  <img src="./assets/photos/h68k-overview.jpg" alt="LinkStar H68K device" width="55%">
</p>

<sub align="center">Device photo © Seeed Studio, reused under CC BY-SA 4.0 — see [`assets/photos/CREDITS.md`](./assets/photos/CREDITS.md).</sub>

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

## The complete workflow

<p align="center">
  <img src="./assets/diagrams/workflow.svg" alt="The complete LinkStar H68K workflow: vendor firmware → flash → boot + baseline → optional 24.04 upgrade → flavor (desktop/server/casaos) → release, plus the OpenWRT/Armbian shortcut and a gotchas-and-fixes band." width="100%">
</p>

## Hardware at a glance

| | |
| --- | --- |
| **SoC** | Rockchip RK3568 — 4× Cortex-A55, Mali-G52 GPU, 0.8-TOPS NPU |
| **RAM** | LPDDR4/4x (unit verified: ~4 GB) |
| **Storage** | ~32 GB eMMC + microSD (boots from either) |
| **Network** | 2× 2.5 GbE (RTL8125B) + 2× 1 GbE (RTL8211F) + optional Wi-Fi 6 (MT7921) |
| **OS (stock)** | Ubuntu 20.04.5 LTS (Lubuntu / LXQt), kernel 4.19 vendor BSP |

Full breakdown, sourced and verified: **[`docs/hardware.md`](./docs/hardware.md)**.

## Repository layout

```text
linkstar-h68k/
├── docs/         # the guide (16 docs) — start at docs/README.md
├── scripts/      # the toolkit — flash, discover, fix-networking, harden, build-release…
├── flavors/      # desktop / server / casaos release variants
├── firstboot/    # secure-baseline overlay (runs once on a flashed image)
├── firmware/     # official download links + SHA256 (no binaries in git)
└── assets/       # the infographic, diagrams, and device photos
```

## Quick start

> 🟢 **Just want it working?** Follow the friendly step-by-step:
> **[Flash Ubuntu to an SD from a Mac](./docs/flash-ubuntu-sd-from-mac.md)**. For OpenWRT
> or Armbian, it's even simpler — flash the image with [balenaEtcher](https://etcher.balena.io/)
> and boot.

**Already have a unit running?** Find it and lock it down (it ships wide open):

```bash
scripts/discover.sh                                # find it on your network
scp -r scripts <you>@<ip>:~/ && ssh <you>@<ip>     # copy the toolkit over, log in
sudo ~/scripts/fix-networking.sh                   # sane networking + DNS
sudo ~/scripts/harden.sh --pubkey-file ~/.ssh/authorized_keys   # close ADB/FTP, add a firewall
```

<details>
<summary><b>Advanced:</b> build the SD from the raw vendor image yourself</summary>

```bash
scripts/unpack-rkfw.sh   ubuntu20.04-...-update.img  ./work/parts
scripts/build-idbloader.sh  MiniLoaderAll.bin  ./work/idbloader.img
scripts/build-sd-image.sh   ./work/parts  ./work/idbloader.img  /dev/diskN   # DESTRUCTIVE
```

</details>

Every script supports `--dry-run` and `--help` — see [`scripts/README.md`](./scripts/README.md).

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

- **v0.1.0 — Ubuntu desktop (20.04)** ✅ — toolkit, docs, first-boot overlay, released.
- **v0.2.0 — the release matrix**: Ubuntu 24.04 in **desktop** *and* **server** flavors,
  plus the **OpenWRT** and **Android** tracks. See [`flavors/README.md`](./flavors/README.md)
  and [`docs/releasing.md`](./docs/releasing.md).
- Later: pre-baked hardened images mirrored to the Internet Archive; more flavors (NAS, Docker).

## Contributing

Corrections and additions from other H68K owners are very welcome — see
[`CONTRIBUTING.md`](./CONTRIBUTING.md). Facts should cite a source; guesses should
be labeled as such.

## License & credits

- Scripts & original docs: **MIT** (docs also **CC BY 4.0**) — see [`LICENSE`](./LICENSE).
- Hardware, stock firmware, and release notes are **© Seeed Studio / Rockchip** and
  their respective owners; mirrored here with attribution for preservation only.
- **Credits & references** — this project builds on the community's work (Seeed,
  HINLINK, Rockchip, the Armbian/OpenWRT communities, and more). See
  [`CREDITS.md`](./CREDITS.md).
- Maintained by Brian Gorzelic and contributors.
