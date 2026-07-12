# LinkStar H68K Documentation

The complete guide to the Seeed Studio LinkStar H68K (RK3568). Everything here was
either verified on real hardware or is clearly marked as unverified.

## Start here

- **[Flash Ubuntu to an SD from a Mac](flash-ubuntu-sd-from-mac.md)** — the
  recommended way to (re)install: no maskrom, no Windows. ⭐
- **[Flashing & recovery overview](flashing-and-recovery.md)** — all the paths,
  including maskrom/eMMC recovery when SD boot isn't enough.

## Reference

- **[How SD boot works (RK3568 internals)](how-it-works.md)** — boot chain, the
  RKFW/RKAF container format, the idbloader black-screen fix, networking.
- **[OS images](os-images/)** — image matrix + the archived vendor release note.
- **[Firmware downloads & checksums](../firmware/README.md)**

## Planned (tracked in the project roadmap)

These are being written; some depend on sourcing specs against the Seeed wiki:

- `hardware.md` — SoC, RAM, NICs, LEDs, ports, GPIO breakdown
- `known-issues.md` — the release driver bugs (Wi-Fi / 2.5 G NICs / LED) + insecure defaults, with fixes
- `hardening.md` — locking the box down (companion to `scripts/harden.sh`)
- `networking.md` — interface mapping and the /22 discovery quirk
- `storage.md` — eMMC vs microSD boot, expanding the rootfs
- `first-boot.md` — default credentials and first-boot behavior

Contributions welcome — see [`../CONTRIBUTING.md`](../CONTRIBUTING.md).
