# Credits & References

This project stands on a lot of other people's work — hardware, reverse-engineering,
community OS images, and documentation. Thank you to everyone below.

## Acknowledgments

### Vendor & silicon

- **[Seeed Studio](https://www.seeedstudio.com/)** — the LinkStar H68K hardware, the
  [wiki](https://wiki.seeedstudio.com/Linkstar_Datasheet/) (content licensed
  [CC BY-SA 4.0](https://wiki.seeedstudio.com/License/)), and the official firmware on
  [SourceForge](https://sourceforge.net/projects/linkstar-h68k-os/files/). The device
  photos in this repo are theirs, reused under CC BY-SA 4.0 — see
  [`assets/photos/CREDITS.md`](assets/photos/CREDITS.md).
- **HINLINK** — the **OPC-H68K**, the ODM design the LinkStar H68K rebadges (hence the
  `opc-h68k` device tree and the `OWLVisionTech rk3568 opc Board` model string).
- **[Rockchip](https://www.rock-chips.com/)** — the RK3568 SoC, and the
  [`rkdeveloptool`](https://github.com/rockchip-linux/rkdeveloptool) +
  [`rkbin`](https://github.com/rockchip-linux/rkbin) tools the flashing pipeline uses.

### Community projects & people

- **[amazingfate/armbian-h68k-images](https://github.com/amazingfate/armbian-h68k-images)**
  — community Armbian images and board configs (including the H66K sibling).
- **[ophub/amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian)** —
  Armbian builds targeting `rk3568-opc-h68k`, and the
  [RTL8211F 1 GbE PHY report](https://github.com/ophub/amlogic-s9xxx-armbian/issues/1726).
- **[Rockemd/Hinlink-H68K](https://github.com/Rockemd/Hinlink-H68K)** — HINLINK H68K notes.
- The mainline Linux **device-tree** contributors who upstreamed
  `rk3568-linkstar-h68k-1432v1`
  ([patch discussion](https://marc.info/?l=devicetree&m=175283999802447&w=2)).
- The **OpenWRT forum** community — the H68K
  [mega-thread](https://forum.openwrt.org/t/linkstar-h68k-rk3568-dual-2-5gbe-wifi-6/143246)
  and [install thread](https://forum.openwrt.org/t/linkstar-h68k-openwrt-install/152271).
- **[neo-technologies/rockchip-mkbootimg](https://github.com/neo-technologies/rockchip-mkbootimg)**
  — `afptool` / `img_maker`, a reference for the RKFW/RKAF container format.

### Reporting & specifications

- **[CNX Software](https://www.cnx-software.com/2022/11/19/linkstar-h68k-rockchip-rk3568-multimedia-router-with-dual-2-5gbe-dual-gigabit-ethernet/)**
  — the most detailed public spec review of the H68K.

## Tools this project uses

`rkdeveloptool` and `rkbin`/`mkimage` (Rockchip) · `sgdisk` (gptfdisk) · U-Boot
`mkimage` · `xz` · `nmap` · `shellcheck` · `markdownlint`.

## Key references

| Topic | Source |
|-------|--------|
| Datasheet / hardware | <https://wiki.seeedstudio.com/Linkstar_Datasheet/> |
| Install / flashing | <https://wiki.seeedstudio.com/linkstar-install-system/> |
| Wiki content license | <https://wiki.seeedstudio.com/License/> |
| Firmware downloads | <https://sourceforge.net/projects/linkstar-h68k-os/files/> |
| Spec review | CNX Software (link above) |
| Lineage / device trees | amazingfate, ophub, mainline DT (links above) |

## Trademarks

LinkStar, Seeed Studio, HINLINK, Rockchip, Realtek, MediaTek, Ubuntu, OpenWRT, and
other names are trademarks of their respective owners. This is an **unofficial,
community project** — not affiliated with, sponsored by, or endorsed by any of them.
