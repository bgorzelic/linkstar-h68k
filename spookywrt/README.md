# SpookyWrt — the flagship OpenWRT build

<sub>[Home](../README.md) › SpookyWrt</sub>

**SpookyWrt** is a custom, GL.iNet-class OpenWRT firmware for the LinkStar H68K — a full
router / NAS / AP in one image, built on real OpenWRT so the **MT7921 Wi-Fi and 2.5 G NICs
actually work** (unlike the vendor 4.19 Ubuntu/Android track). The design brief is
[`../docs/openwrt-superprompt.md`](../docs/openwrt-superprompt.md); this directory is the
build.

## What's here

| File | Purpose |
|------|---------|
| `build.py` | Requests a custom image from the OpenWRT **ASU build server** (package list + first-boot script) and prints the download URL + SHA256. |
| `first-boot.sh` | The `uci-defaults` first-boot script — branded banner + MOTD, `eth0`=WAN topology, NTP (no RTC), and a deferred Wi-Fi-AP setup. |
| `first-boot-full.sh` | The flagship variant — also installs the `spooky-setup` wizard onto the device. |
| `spooky-setup` | An on-device onboarding wizard (POSIX/ash): Express or Advanced, every network change under a **rollback timer** so you can't lock yourself out. |

## Build it

No local toolchain needed — the [ASU server](https://sysupgrade.openwrt.org/) compiles it
and you download the ~35 MB result:

```bash
mkdir -p /tmp/h68k-build
cp spookywrt/first-boot-full.sh /tmp/h68k-build/
python3 spookywrt/build.py        # prints the image URL + SHA256 when done
```

Then flash the downloaded `*-squashfs-sysupgrade.img.gz` to a microSD (`dd`/Etcher) and boot.
First boot applies the branding, topology, and (deferred) secured Wi-Fi AP; log in over SSH
and run `spooky-setup` to finish provisioning.

> Target: `rockchip/armv8` · profile `hinlink_h68k` · rootfs 1 GB (flagship package set).
> See [`build.py`](build.py) for the full package list (LuCI, Samba, WireGuard, AdGuard,
> SQM, banIP, mt7921/mt7925u Wi-Fi, kmod-r8125 for 2.5 G, and the toolkit).

## Why the Wi-Fi setup is deferred

The `mt7921` driver loads **after** `uci-defaults` runs on first boot, so configuring the
radio inline races the driver and the AP can come up open. `first-boot.sh` instead installs
a one-shot init service that **waits for the radio to appear**, secures the AP, then removes
itself — the reliable pattern for driver-dependent first-boot config.
