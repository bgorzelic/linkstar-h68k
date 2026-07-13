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

## The `spooky` control shell

Once the box is up, **`spooky`** is your one command to run and troubleshoot it — over SSH or
the serial console. Run it bare for a menu, or as a one-shot:

```sh
spooky              # interactive menu: status · network · wifi · diag · services · capture · vpn
spooky status       # health snapshot (WAN/LAN/Wi-Fi/clients/internet)
spooky diag         # checks the known gotchas: DNS, clock/NTP, Wi-Fi driver, dnsmasq, recent errors
spooky capture wan  # packet capture on the WAN uplink (→ spooky-capture)
spooky bundle       # collect a diagnostic tarball for support (+ the scp line to grab it)
```

It ties together `spooky-setup` (config wizard), `spooky-capture`, and live diagnostics — the
"single pane of glass" for the device from a terminal. Installed to `/usr/bin/spooky` by first-boot.

## First-time setup over Wi-Fi (no cable)

A freshly flashed SpookyWrt raises an **open onboarding AP named `SpookyWrt-Setup`** on first
boot (deferred until the MT7921 driver loads). Join it from a phone or laptop, open
**`http://192.168.1.1`**, and configure the box via LuCI, the
[on-device dashboard](webui/index.html), or `spooky-setup`. As soon as you set your own Wi-Fi
the setup AP **retires itself** (or run `spooky-setup-done`).

Implemented in [`setup-ap.sh`](setup-ap.sh) (appended to first-boot on every build). It's open
because it's transient and onboarding-only — set a WPA key in the wizard, and complete setup
promptly. No Wi-Fi radio (e.g. a no-Wi-Fi H68K SKU)? Use a LAN cable to `192.168.1.1` instead.

## What's here

| File | Purpose |
|------|---------|
| `build.py` | Requests a custom image from the OpenWRT **ASU build server** (package list + first-boot script) and prints the download URL + SHA256. |
| `first-boot.sh` | The `uci-defaults` first-boot script — branded banner + MOTD, `eth0`=WAN topology, NTP (no RTC), and a deferred Wi-Fi-AP setup. |
| `first-boot-full.sh` | The flagship variant — also installs the `spooky-setup` wizard onto the device. |
| `spooky` | The **control shell** — a menu-driven config + troubleshooting TUI for SSH/console. Status, network, Wi-Fi, diagnostics, services, capture, VPN, and a diag bundle in one command. |
| `spooky-setup` | An on-device onboarding wizard (POSIX/ash): Express or Advanced, every network change under a **rollback timer** so you can't lock yourself out. |
| `spooky-capture` | Dead-simple packet capture (`tcpdump` wrapper) — auto-saves to a USB stick or a RAM ring buffer, prints the retrieval line. |
| `setup-ap.sh` | First-boot onboarding: raises the open `SpookyWrt-Setup` Wi-Fi AP so you can configure the box with no cable; self-retires after setup. |
| `wifi-audit/firstboot.sh` | The `wifi-audit` variant's consent gate + boot-safety (services-off). |
| `luci-theme-spooky/` | The **SpookyJuice-branded LuCI theme** — repaints the on-device OpenWRT web UI (slime-green on near-black). Installed to `/www/luci-static/spooky/` by first-boot; LuCI points at it automatically. |

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

The **`wifi-audit`** variant adds a monitor-mode/injection driver zoo (mt76 / ath9k / rt2800),
audit tooling (aircrack-ng, hcxdumptool, reaver, horst), best-of-flavor extras (multi-WAN,
band-steering, travelmate, DoH, DDNS, bandwidth graphs) and the 6 GHz-capable `wpad-mbedtls`.
It's **opt-in on purpose** — kept out of the default image so the flagship stays lean and the
attack surface is a deliberate choice.

> [!IMPORTANT]
> **Consent gate.** Because this image ships packet-injection tooling, the offensive tools are
> **fail-closed**: they're only reachable via `spooky-audit <tool>`, which refuses to run until
> the operator records authorization + a regulatory domain with `spooky-audit-consent`
> (scope + `I ACCEPT`, persisted to `/etc/spookywrt/audit-consent.json`, every run logged).
> Implemented in [`wifi-audit/firstboot.sh`](wifi-audit/firstboot.sh). **Authorized use only.**

<!-- -->

> [!NOTE]
> The audit variant ships its extra daemons (`mwan3`, `collectd`, `travelmate`, `dawn`,
> `watchcat`…) **disabled by default** — they stall a fresh image's first boot. Enable the ones
> you configure (`/etc/init.d/<svc> enable`). If a build ever won't boot, the
> [USB serial console](../docs/serial-console.md) shows the stalling service.

Verified chipset/adapter matrix and the 6 GHz reality: [`../docs/wireless-support.md`](../docs/wireless-support.md).
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
