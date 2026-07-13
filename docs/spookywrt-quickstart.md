# SpookyWrt — Quickstart

<sub>[Home](../README.md) › [Docs](README.md) › SpookyWrt quickstart</sub>

**SpookyWrt** is a free, professional-grade OpenWrt firmware with a GL.iNet-class experience, on the
SpookyJuice brand. The flagship target is the **Seeed LinkStar H68K (RK3568)**, but the same recipe
builds for any board OpenWrt supports (arm64 SBCs, x86-64 mini-PCs/VMs, MIPS routers).

Three steps: **build → flash → onboard.** No toolchain, no account, no Windows.

> **Point-and-click builder + config generator:** the showcase page assembles the image and writes the
> first-boot config for you — Build image / Configure box tabs. (Artifact link in the repo.)

---

## 1. Build the image

SpookyWrt compiles server-side on OpenWrt's free **Attended-Sysupgrade** build server (~30s) — you just
send a package list + a first-boot `uci-defaults` script. The reproducible recipe lives in `scripts/`:

- `scripts/build-perfect.py` — posts the flagship manifest + `perfect-defaults-full.sh`, polls, prints
  the image URL + sha256.
- `scripts/perfect-defaults.sh` — the first-boot script (branding, Wi-Fi, NTP, **eth0=WAN topology**).
- `scripts/perfect-defaults-full.sh` — the above **with `spooky-setup` embedded** (self-contained image).

```bash
cd scripts && python3 build-perfect.py     # → prints image URL + sha256
```

The **flagship loadout** (≈39 packages, 1 GB rootfs) makes every mode available on one image:
LuCI + Material + Attended-Sysupgrade · r8125/mt7921/mt7925u drivers · Samba · WireGuard · AdGuardHome ·
SQM · banip + honeypot decoys · full CLI toolkit · and the `spooky-setup` wizard baked in.

**Gotchas that cost real time (already fixed in the recipe):**

- `luci-app-wireguard` was **removed** upstream (snapshots moved to the `apk` package manager). Use
  `luci-proto-wireguard`.
- 39 packages **overflow the default rootfs** → set `rootfs_size_mb: 1024` in the build request.
- Configuring Wi-Fi in `uci-defaults` **races the mt7921 driver** (radio loads *after* first-boot
  scripts) and the AP comes up open. The recipe defers Wi-Fi to a one-shot boot service that waits for
  the radio, secures the AP, then self-removes.

## 2. Flash the card

The image is a self-contained bootable disk image (bootloader included) — a straight `dd`, **no maskrom**.

```bash
IMG=<url from step 1>
curl -sLO "$IMG"
shasum -a256 *.img.gz            # must match the printed sha256
diskutil list                    # find the card — a ~32GB EXTERNAL disk (NOT an internal one)
diskutil unmountDisk /dev/diskN
gunzip -c *.img.gz | sudo dd of=/dev/rdiskN bs=4m    # rdiskN (raw) is much faster on macOS
```

> ⚠️ Confirm `/dev/diskN` is the card before writing — `dd` wipes the whole target.
> The squashfs `.img.gz` from the build server carries gzip padding, so `gunzip -t` reports "trailing
> garbage" even on a good file — trust the **sha256 match**; `gunzip -c` extracts it cleanly.

## 3. First boot + onboarding

The box boots to a branded SPOOKY console + live status MOTD, LuCI at `http://192.168.1.1`, DHCP serving.
Two ways to configure it (**really simple or really complex**):

- **On the box** — SSH/serial in and run **`spooky-setup`**:
  - **Express** — password → hostname → timezone → Wi-Fi → mode → LAN IP → apply (~60s).
  - **Advanced** — System / Wi-Fi / Network (LAN IP, DHCP, WAN-port) / Services & modes, section by section.
  - Any network change applies under a **90s auto-rollback** so you can't lock yourself out.
- **From the browser** — the showcase's **Configure box** tab generates the exact `uci` block to paste.

Set a root password immediately (`passwd` or `spooky-setup`) — a fresh image has none and SSH is open.

---

## The H68K port map — read this before you plug anything in

This is the single biggest source of confusion. **OpenWrt's default for `hinlink_h68k` is:**

```text
ucidef_set_interfaces_lan_wan 'eth0 eth2 eth3' 'eth1'
```

| Kernel | Port | Default role | Notes |
|--------|------|--------------|-------|
| eth0 | 1 GbE | LAN | most reliable LAN jack |
| **eth1** | 1 GbE | **WAN** | your internet uplink goes here (by default) |
| eth2 | 2.5 GbE | LAN | Realtek r8125 (needs `kmod-r8125`) |
| eth3 | 2.5 GbE | LAN | Realtek r8125 |

**SpookyWrt's recipe flips this to `eth0 = WAN`, `eth1+eth2+eth3 = LAN`** (the more intuitive layout).
So on a SpookyWrt image, **plug your uplink into eth0.**

Symptoms of getting it wrong:

- *"Only eth0 comes up / no link on eth1"* → eth1 is the **WAN** port on stock; with nothing plugged in
  it correctly shows no link. The LAN is the *other* ports.
- *"It's passing through the 192.168.4.x network"* → your uplink is plugged into a **LAN** port, which
  bridges your main network into the H68K LAN (two DHCP servers fighting). Move it to the WAN port.
- Physical jack labels don't always match kernel `ethN` order — identify by function: whichever port
  leases you a `192.168.1.x` is a LAN port; the WAN port pulls an address from *your* router.

To flip WAN live (connected via a LAN port that stays LAN, e.g. eth2), with a rollback safety net:

```bash
BR=$(uci show network | sed -n "s/^network\.\([^.]*\)\.name='br-lan'.*/\1/p" | head -1)
uci del_list network.$BR.ports='eth0'; uci add_list network.$BR.ports='eth1'
uci set network.wan.device='eth0'; uci set network.wan6.device='eth0'
uci commit network && /etc/init.d/network reload
```

Other verified H68K facts: **no RTC battery** (clock resets cold → NTP-on-boot is mandatory); the 2.5 G
ports and Wi-Fi are **dead on the vendor 4.19 kernel** but work on OpenWrt (kernel ≥ 5.12 / ≥ 6.7 for
Wi-Fi 7 USB). See `docs/known-issues-and-hardware.md`.

---

## Operating modes

One switch reconfigures netifd + firewall + services (rollback-protected). All available on the
flagship image; flip them with `spooky-setup`.

| Mode | What it does |
|------|--------------|
| **Router** | Full gateway — WAN + LAN bridge + DHCP + NAT + firewall (default) |
| **Access Point** | Bridge into an existing LAN; extend Wi-Fi |
| **NAS** | Samba file sharing off USB/NVMe storage |
| **Travel / VPN** | WireGuard always-on |
| **Hacker / Lab** | CLI audit toolkit (nmap, arp-scan, mtr, tcpdump) — **authorized/own-network only** |
| **Honeypot** | Decoy listeners on `:21/:23/:2323/:8080` → trap log + `tcpdump` capture + `banip` auto-ban — **own-network only** |

---

## Multi-platform

The catalog is a starting set, not a whitelist — if OpenWrt has a profile, SpookyWrt can target it:
arm64 SBCs (H68K, Pi 5/4, NanoPi R5S, GL-MT6000), **x86-64** (mini-PC / thin client / VM / VPS), and
cheap **MIPS** routers (ramips/ath79 — the "$15 revival"). The UI, config, and workflow are identical;
only drivers + form factor change per board. See §9b of `openwrt-superprompt.md`.
