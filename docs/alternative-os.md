# Running other operating systems

<sub>[Home](../README.md) › [Docs](README.md) › Other OSes</sub>

The H68K is not locked to the vendor Ubuntu. It's a mainstream RK3568 board, so it
runs **OpenWRT, Armbian, Debian, and Android** too. There are two families of images,
and they flash very differently:

- **RKFW vendor images** (Ubuntu, Android) — a container, not a disk image. Use this
  repo's [SD pipeline](flash-ubuntu-sd-from-mac.md) or [RKDevTool](flash-emmc-windows.md).
- **Raw disk images** (OpenWRT, Armbian, Debian) — a real disk image. Flash it directly
  with `dd` or balenaEtcher. **This is the simplest path** — no unpack, no idbloader rebuild.

<p align="center">
  <img src="../assets/diagrams/flash-decision.svg" alt="Which flashing path? microSD vendor Ubuntu (RKFW pipeline, no maskrom), microSD OpenWRT/Armbian (raw image, simplest), or eMMC over USB (any OS, needs maskrom)." width="100%">
</p>

## OS matrix

| OS | Image type | How to flash | Drivers (Wi-Fi / 2.5 G / LED) | Best for |
|----|-----------|--------------|-------------------------------|----------|
| **Ubuntu 20.04** (vendor) | RKFW | [SD pipeline](flash-ubuntu-sd-from-mac.md) / RKDevTool | vendor bugs | LXQt desktop |
| **OpenWRT** (vendor + community) | raw `.img` | `dd`/Etcher to SD, or eMMC | 2.5 G works in current builds | router / firewall |
| **Armbian** (amazingfate / ophub) | raw `.img` | `dd`/Etcher | **mainline — fixes all three** | server / NAS, best drivers |
| **Debian** (Armbian-based / community) | raw `.img` | `dd`/Etcher | mainline | minimal server |
| **Android 11** (vendor) | RKFW | RKDevTool → eMMC | vendor | media / TV box |

> [!TIP]
> If the vendor Ubuntu's **Wi-Fi / 2.5 G / front-LED bugs** bother you, the real fix is
> a community **Armbian** build with a mainline kernel — see [known-issues.md](known-issues.md).

## Armbian — the route to working drivers

Community Armbian images target `rk3568-opc-h68k` and ship a modern kernel, so the
`mt7921e` Wi-Fi, `r8125` 2.5 G, and GPIO LED all work.

- **Where:** [amazingfate/armbian-h68k-images](https://github.com/amazingfate/armbian-h68k-images)
  and [ophub/amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian).
- **Flash:** raw `.img.xz` → SD with Etcher (or `dd`). Boot from SD.
- **First boot:** Armbian's usual flow — log in as `root` / `1234`, then it forces a
  password change and creates your user. Use `armbian-config` for tuning.
- **Caveat:** on *some* ophub kernels the 1 G ports (RTL8211F) can fail
  (`phy_poll_reset … -110`) — test all four ports after flashing. See
  [known-issues.md](known-issues.md).

## OpenWRT — router / firewall

- **Where:** the vendor image on [SourceForge](https://sourceforge.net/projects/linkstar-h68k-os/files/Openwrt/)
  (`openwrt-rockchip-R22.11.18_opc-h68k-d-…-sysupgrade.img`) plus community builds.
- **Flash:** it's a raw sysupgrade image — `dd`/Etcher to SD, or flash to eMMC via RKDevTool.
- **Access:** LuCI web UI; default mapping `eth0` = WAN, the rest LAN; login `root` / `password`.

## Android 11 — media / TV box

Vendor Android (R22.11.17) flashes to **eMMC** via RKDevTool — see
[flash-emmc-windows.md](flash-emmc-windows.md). Best for HDMI media-player use.

## How to flash a raw image (the simple path)

```bash
# macOS  (rdiskN is much faster than diskN)
diskutil list
diskutil unmountDisk /dev/diskN
xz -dc image.img.xz | sudo dd of=/dev/rdiskN bs=4m
sync

# Linux
lsblk
xzcat image.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync
```

Or use **[balenaEtcher](https://etcher.balena.io/)** — cross-platform, handles
compressed images, and won't let you pick the wrong disk. Grow the rootfs on first
boot if the image doesn't ([`expand-rootfs.sh`](../scripts/expand-rootfs.sh)).

## SD vs eMMC

Try things from **microSD** (pull it to revert); commit a favorite to **eMMC** for a
card-free permanent install. See [flashing-and-recovery.md](flashing-and-recovery.md).

## Credit

Armbian for the H68K is community work — thanks to the maintainers listed in
[`../CREDITS.md`](../CREDITS.md).
