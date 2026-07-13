# SpookyWrt — the flagship OpenWRT build

<sub>[Home](../README.md) › SpookyWrt</sub>

**SpookyWrt** is a custom, GL.iNet-class OpenWRT firmware for the LinkStar H68K — a full
router / NAS / AP in one image, built on real OpenWRT so the **MT7921 Wi-Fi and 2.5 G NICs
actually work** (unlike the vendor 4.19 Ubuntu/Android track). The design brief is
[`../docs/openwrt-superprompt.md`](../docs/openwrt-superprompt.md); this directory is the
build.

> 🎛️ **Configure it visually:** the **[SpookyWrt Control WebUI](https://bgorzelic.github.io/linkstar-h68k/webui/)**
> ([source](../webui/index.html)) builds a recipe and generates a first-boot script for you —
> a click-driven front end to everything below.

## What's here

| File | Purpose |
|------|---------|
| `build.py` | Requests a custom image from the OpenWRT **ASU build server** (package list + first-boot script) and prints the download URL + SHA256. |
| `first-boot.sh` | The `uci-defaults` first-boot script — branded banner + MOTD, `eth0`=WAN topology, NTP (no RTC), and a deferred Wi-Fi-AP setup. |
| `first-boot-full.sh` | The flagship variant — also installs the `spooky-setup` wizard onto the device. |
| `spooky-setup` | An on-device onboarding wizard (POSIX/ash): Express or Advanced, every network change under a **rollback timer** so you can't lock yourself out. |

## The on-device dashboard

[`webui/index.html`](webui/index.html) is the **SpookyWrt dashboard** — a modern, GL.iNet-class
single-page WebUI that runs *on the box* alongside LuCI. Live status, an instrument-cluster of
gauges (CPU / memory / temp / throughput), quick toggles (Wi-Fi, guest, AdGuard), an
operating-mode switcher, and the client list — all driven by **ubus over HTTP**, no build step.

**Preview it** (demo data): <https://bgorzelic.github.io/linkstar-h68k/spookywrt/webui/>

**Install on a device:**

```bash
# the image already bundles the backend (uhttpd-mod-ubus + rpcd — see build.py)
scp webui/index.html root@192.168.1.1:/www/spooky/index.html   # mkdir -p /www/spooky first
# open http://192.168.1.1/spooky/
```

It auto-detects the device: a reachable `ubus` flips the badge from **demo** to **live**; with no
device (e.g. the Pages preview) it runs a self-contained demo engine so the design is fully
navigable. Full LuCI stays one click away for advanced settings.

## Build it

No local toolchain needed — the [ASU server](https://sysupgrade.openwrt.org/) compiles it
and you download the ~35 MB result:

```bash
mkdir -p /tmp/h68k-build
cp spookywrt/first-boot-full.sh /tmp/h68k-build/
python3 spookywrt/build.py        # prints the image URL + SHA256 when done
```

Then flash the downloaded `*-squashfs-sysupgrade.img.gz` to a microSD (`dd`/Etcher) and boot.

### Build variants

```bash
python3 spookywrt/build.py                        # flagship (default, lean — 42 pkgs)
python3 spookywrt/build.py --profile wifi-audit   # + monitor/injection drivers + audit tools
```

The **`wifi-audit`** variant adds a monitor-mode/injection driver zoo (mt76 / ath9k / rt2800)
and audit tooling (aircrack-ng, hcxdumptool, reaver, horst) plus the 6 GHz-capable
`wpad-mbedtls`. It's **opt-in on purpose** — kept out of the default image so the flagship
stays lean and the attack surface is a deliberate choice (authorized use only). Verified
chipset/adapter matrix: [`../docs/wireless-support.md`](../docs/wireless-support.md).
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

The AP comes up with a **random per-device WPA2 password** (never a static shipped key). It's
recorded root-only at **`/etc/spooky-initial-wifi.txt`** on the device — read it over SSH, or
change it in `spooky-setup` / LuCI. SSID: `SpookyWrt-H68K`.
