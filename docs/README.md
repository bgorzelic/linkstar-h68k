# LinkStar H68K Documentation

The complete guide to the Seeed Studio LinkStar H68K (RK3568). Everything here was
either verified on real hardware or is clearly marked as unverified.

## Start here

- **[Flash Ubuntu to an SD from a Mac](flash-ubuntu-sd-from-mac.md)** — the
  recommended way to (re)install: no maskrom, no Windows. ⭐
- **[Flashing & recovery overview](flashing-and-recovery.md)** — all the paths,
  including maskrom/eMMC recovery when SD boot isn't enough.

## Reference

- **[Hardware](hardware.md)** — SoC, RAM, NICs, LEDs, ports, with real photos + infographic.
- **[How SD boot works (RK3568 internals)](how-it-works.md)** — boot chain, the
  RKFW/RKAF container format, the idbloader black-screen fix, networking.
- **[Known issues & fixes](known-issues.md)** — the release driver bugs + the stock
  image's insecure defaults, with remediations.
- **[First boot](first-boot.md)** — default credentials and what the stock image does
  on first boot (+ the fast path).
- **[Hardening](hardening.md)** — locking the box down (companion to `scripts/harden.sh`).
- **[OS images](os-images/)** — image matrix + the archived vendor release note.
- **[Firmware downloads & checksums](../firmware/README.md)**

## Building & releasing

- **[Releasing (reproducible builds)](releasing.md)** — the pinned, one-command
  release process, versioning, and how to add new OS tracks.

## Planned

Being written:

- `networking.md` — deeper interface mapping and the /22 discovery quirk
- `storage.md` — eMMC vs microSD boot, moving root, expanding the rootfs

Contributions welcome — see [`../CONTRIBUTING.md`](../CONTRIBUTING.md).
