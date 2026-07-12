# Firmware & OS Images

This project **does not store firmware binaries in git** — they are multi-gigabyte
files. Instead, each official image is listed here with its **SHA256 checksum**, so
any copy you download (from Seeed, a mirror, or the Internet Archive) can be
verified as bit-for-bit authentic.

> [!IMPORTANT]
> Firmware images are **© Seeed Studio / Rockchip** and their respective owners.
> They are catalogued (and, where mirrored, preserved) here for convenience and
> archival only, with attribution to the original source. This repository's MIT/CC
> license does **not** cover the firmware.

## Verify a download

```bash
# Put the image(s) next to this SHA256SUMS file, then:
shasum -a 256 -c SHA256SUMS
# each line should print "OK"
```

On Linux: `sha256sum -c SHA256SUMS`.

## Image catalogue

| Image | Purpose | Size | SHA256 |
| ------- | --------- | ------ | -------- |
| `ubuntu20.04-v0.0.1-update(linkstar-linkstar-root--root).img` | Stock **Ubuntu 20.04** (LXQt) OS image, v0.0.1 (2023-02-06) — raw `.img` | 6.64 GiB | `9e780950…5b1c24fe` |
| `ubuntu20.04-v0.0.1-update(linkstar-linkstar-root--root).zip` | Same Ubuntu image, zipped for download | 2.59 GiB | `7fc9da2d…e1f097ff` |
| `LinkStar-H68K-EraseFlash.img` | **Erase/blank** image — wipes eMMC to a clean state before reflashing | 1.60 GiB | `63f4218b…9810f984` |
| `openwrt-rockchip-R22.11.18_opc-h68k-d-squashfs-sysupgrade.img` | **OpenWRT** R22.11.18 sysupgrade image (opc-h68k-d) | 528 MiB | `4ca5383a…70467f96` |
| `H68K-Boot-Loader_20220922_180313.bin` | Rockchip **bootloader / loader** (for maskrom flashing) | 454 KiB | `7074db2b…30e3d8b0` |

Full checksums are in [`SHA256SUMS`](./SHA256SUMS).

## Where to download

**Official host — SourceForge project [`linkstar-h68k-os`](https://sourceforge.net/projects/linkstar-h68k-os/files/)**
(linked from the Seeed wiki). Prefer the official source when reachable:

| Image | Folder on SourceForge |
|-------|-----------------------|
| Ubuntu 20.04 (`.zip`) | [`/Ubuntu 20.04/`](https://sourceforge.net/projects/linkstar-h68k-os/files/Ubuntu%2020.04/) |
| OpenWRT (`.img`) | [`/Openwrt/`](https://sourceforge.net/projects/linkstar-h68k-os/files/Openwrt/) |
| Bootloader (`.bin`) | [`/Openwrt/`](https://sourceforge.net/projects/linkstar-h68k-os/files/Openwrt/) |
| EraseFlash (`.img`) | [`/Erase-tool/`](https://sourceforge.net/projects/linkstar-h68k-os/files/) |
| Android, flash tools | `/Android/`, `/Flash-to-eMMC-tool/`, `/Flash-to-TF-card-tool/` |

Vendor Windows flashing bundle uses **RKDevTool v2.84** + **Rockchip DriverAssistant
v5.1.1** (in `/Flash-to-eMMC-tool/`).

- **Preservation mirrors (planned):** the Internet Archive (all images, incl. the
  >2 GB Ubuntu files GitHub can't hold) + the matching GitHub Release for the sub-2 GB
  images (EraseFlash, OpenWRT, bootloader). Always verify any copy against the
  `SHA256SUMS` above.

## Flashing

See [`../docs/flashing-and-recovery.md`](../docs/flashing-and-recovery.md) for the
full procedure (RKDevTool on Windows, `rkdeveloptool`/`upgrade_tool` on
Linux/macOS, maskrom mode, and how the EraseFlash image + bootloader are used).
