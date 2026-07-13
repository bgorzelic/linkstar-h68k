# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/). Firmware-image releases use per-OS-track
tags (`<track>/vX.Y`); see [docs/releasing.md](docs/releasing.md).

## [Unreleased]

### Added

- **Release matrix / flavors** (`flavors/`) — `desktop`, `server`, and `casaos` (CasaOS
  home-server UI) flavors of the Ubuntu track, a build workflow, and a
  `<track>[-<flavor>]-<osversion>` tag scheme (see `flavors/README.md`).
- **`docs/upgrading.md`** — in-place distro-upgrade guide (20.04 → 22.04 → 24.04) with
  the real gotchas and rollback.

### In progress

- **Ubuntu 24.04 release** (`ubuntu-desktop-24.04` / `ubuntu-server-24.04`) — pending the
  live in-place upgrade + boot verification, then snapshot → image.

## [0.1.0] — 2026-07-12

First public release — the LinkStar H68K toolkit + guide (Ubuntu 20.04 track).

### Added

- **SD-boot toolchain** (flash Ubuntu from a Mac, no maskrom): `unpack-rkfw.sh`,
  `build-idbloader.sh`, `build-sd-image.sh` — handles the RKFW 32-bit offset overflow
  and the `RKNS` idbloader black-screen fix.
- **Device tooling**: `discover.sh`, `fix-networking.sh`, `expand-rootfs.sh`,
  `harden.sh`, `first-setup.sh` — shellcheck-clean, idempotent, `--dry-run` where they mutate.
- **Reproducible release pipeline**: `bootstrap-tools.sh` (pinnable toolchain),
  `build-release.sh` (one-command build + checksummed manifest), `docs/releasing.md`.
- **First-boot overlay** (`firstboot/`): applies the secure baseline once on a flashed
  image (host-key regen, auto-updater mask, networking, hardening), then self-disables.
- **Docs**: no-maskrom flash guide, RK3568 boot/RKFW internals, a sourced hardware
  reference (4-port NIC breakdown, SKU decoder, OPC-H68K lineage), known issues + fixes,
  flashing & recovery, first-boot, hardening, and a firmware manifest with SHA256s + links.
- **Visuals**: SVG infographic, real device photos (Seeed wiki, CC BY-SA 4.0), Mermaid diagrams.
- **CI**: shellcheck + markdownlint.

### Notes

- Firmware images are not committed — referenced by official SourceForge links + SHA256.
  Pre-baked hardened images and the Internet Archive mirror are planned.

[0.1.0]: https://github.com/bgorzelic/linkstar-h68k/releases/tag/v0.1.0
