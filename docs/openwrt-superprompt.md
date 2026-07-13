# SUPER PROMPT — Build "SpookyWrt": a GL.iNet-class OpenWrt firmware for the LinkStar H68K

<sub>[Home](../README.md) › [Docs](README.md) › OpenWRT brief</sub>

> Paste this whole document to a capable coding agent (or use it as the project brief).
> It is self-contained: mission, verified hardware facts, hard-won gotchas, architecture,
> UX north star, feature scope, build plan, and success criteria. Do not re-derive the
> things marked **VERIFIED** — they cost real hours to learn.

---

## 0. Role & mission

You are a **senior embedded-Linux + full-stack engineer**. Build a polished, production-quality
**OpenWrt-based router/NAS/AP firmware** for the **Seeed LinkStar H68K (Rockchip RK3568)** whose
management experience **rivals GL.iNet's** — clean, guided, mobile-first, delightful for a
non-expert — while keeping **full LuCI** one click away for power users.

Ship a **reproducible image build** + a **custom web UI package** + **flashing/recovery docs**,
integrated as the **v0.2.0 "OpenWrt" track** of the `linkstar-h68k` repo
(github.com/bgorzelic/linkstar-h68k). MIT-licensed; firmware distributed by link+SHA256, not in git.

Codename the build **SpookyWrt** (themeable — treat brand as a variable).

---

## 1. Target device — VERIFIED facts

- **SoC:** Rockchip **RK3568**, quad Cortex-A55, Mali-G52, 1 TOPS NPU. ~4 GB LPDDR4.
- **Storage:** 32 GB eMMC (`mmcblk0`) **and** microSD (`mmcblk1`). **microSD boots first** —
  primary install target; eMMC is the safety fallback.
- **Ethernet (4 ports):**
  - 2× **1 GbE** — Rockchip `rk_gmac-dwmac` (rock solid; these are `eth0/eth1` on the vendor
    kernel, renamed `end0/end1` on newer systemd — **VERIFIED**).
  - 2× **2.5 GbE** — Realtek **RTL8125B**. Vendor Android/Ubuntu 4.19 kernel: **broken/missing driver**.
    OpenWrt/ImmortalWrt: **works** via `kmod-r8125` (occasionally needs a port reset — note it).
- **Wi-Fi:** MediaTek **MT7921 (M7921E)**. Vendor 4.19 kernel: **no driver → dead**.
  **OpenWrt: works** (`mt7921e`, kernel ≥ 5.12). → **AP role is only viable on the OpenWrt track.**
- **Also:** HDMI, USB3/USB2, M.2, front-panel LEDs (vendor-specific), **no RTC battery**
  (**VERIFIED** — clock resets on cold boot; NTP-on-boot is mandatory).
- **Flashing (VERIFIED, from the Ubuntu track — reuse the tooling):**
  - Vendor images are **RKFW containers** (not raw `dd`-able). The repo already has
    `unpack-rkfw.sh` (handles the 32-bit >4 GB overflow), `build-idbloader.sh` (rebuilds the
    **`RKNS` rksd idbloader** — the fix for the black-screen boot), and `build-sd-image.sh`.
  - **OpenWrt/ImmortalWrt ship normal disk images** (`*-sysupgrade.img` / factory `.img`), which
    flash directly with Etcher/`dd` — **no RKFW dance needed for the OpenWrt track.** Keep the RKFW
    tooling only for the Ubuntu/Android tracks and eMMC recovery.
  - No-maskrom, no-Windows: flash the SD from a Mac/Linux with Etcher or `dd`.

---

## 2. Hard-won gotchas — do NOT relearn these

1. **2.5 G ports and Wi-Fi need OpenWrt**, not the vendor kernel. Build/select an image where
   `kmod-r8125` + `mt7921e` + firmware are present. Verify all 4 eth + wifi enumerate before shipping.
2. **No RTC** → enable an NTP client on boot (OpenWrt: `sysntpd` is default — good). Without it,
   TLS/opkg/repo validity fails after a cold boot.
3. **Interface naming differs by kernel/build** — never hard-code `eth0`. Match by role/MAC in
   config, or use OpenWrt's `board.d` to assign WAN/LAN deterministically.
4. **Two DHCP servers = broken LAN.** The device is a DHCP *client* on its uplink; DHCP *server*
   (dnsmasq) belongs only on the LAN bridge. The GL.iNet-style "network mode" switch must handle this.
5. **Vendor image perms defect (VERIFIED):** vendor rootfs shipped `/usr` owned by a phantom uid
   1000, group-writable (priv-esc). Add an image-time check that all of `/usr` is `root:root 755`.
6. **Recovery:** because microSD boots first, a bad flash is never fatal — re-flash the card, or pull
   it to fall back to eMMC. Document this prominently; it removes fear from the whole process.

---

## 3. Base firmware — decision

**Base = ImmortalWrt for RK3568** (best H68K hardware support: r8125 2.5 G + mt7921 wifi + rk3568
target), tracking the community **WIP OpenWrt H68K DTS** work upstream. Rationale: mainline OpenWrt
RK3568/H68K support is still WIP; ImmortalWrt carries the working kmods and DTS today. Keep the build
**rebaseable onto mainline OpenWrt** when H68K support lands there.

- Pin the ImmortalWrt release + feeds revision for reproducibility.
- Produce a **device profile** for `linkstar-h68k` (DTS/board.d: WAN = a 2.5 G or 1 G port, LAN =
  bridge of the rest + wifi; sane default `192.168.8.1` GL.iNet-style LAN subnet).
- Output: `sysupgrade.img` (SD) + a `factory` image; publish with SHA256 (link, not in git).

---

## 4. UX north star — GL.iNet, distilled

GL.iNet's brilliance = **progressive disclosure**. Replicate these principles exactly:

- **Mobile-first responsive SPA.** Looks native on a phone; the router is often configured from one.
- **Dashboard-first.** Landing screen = at-a-glance cards: Internet status, upload/download live
  graph, # clients, Wi-Fi (2.4/5 GHz toggles + SSID/QR), VPN status, storage/NAS. No menu-diving to
  see health.
- **Guided first-setup wizard.** On first boot: language → set admin password → Wi-Fi SSID/pass →
  detect uplink (DHCP/PPPoE/static/repeater) → done. 4 steps, no jargon.
- **One-click common tasks.** Change Wi-Fi, add a client to block/limit, toggle guest network,
  set up **VPN (WireGuard/OpenVPN) client *and* server** in a few taps (VPN is a first-class citizen,
  not buried — this is core GL.iNet DNA), port-forwarding, DDNS.
- **Network-mode switcher.** Router / Access-Point / Repeater / WISP / Extender as a single visual
  chooser that safely reconfigures netifd + firewall + dnsmasq (respect gotcha #4).
- **Plain language + great empty states + inline help.** Never show a raw uci key without a human label.
- **Advanced = LuCI, one click away.** A visible "Advanced (LuCI)" link. Do not reimplement all of
  LuCI — cover the 90% beautifully, delegate the long tail.
- **Real-time.** Live stats via ubus polling / websocket; optimistic UI with clear success/error toasts.
- **Consistent design system.** Cards, toggles, iconography, dark+light, one accent color. Feels like
  one product, not a settings dump.

---

## 5. Architecture — how to actually build the GL.iNet feel

```text
┌───────────────────────────────────────────────┐
│  Vue 3 SPA  (the "SpookyWrt Console")          │  ← mobile-first, design system, wizards
├───────────────────────────────────────────────┤
│  JSON-RPC over ubus  (rpcd + acl)              │  ← auth (rpcd-mod-file/login), sessioned
├───────────────────────────────────────────────┤
│  ubus objects  ← rpcd plugins (lua/shell/C)    │  ← thin methods: get_status, set_wifi,
│                                                │     set_wan, vpn_up, mode_switch, clients…
├───────────────────────────────────────────────┤
│  OpenWrt core: uci · netifd · dnsmasq ·        │
│  firewall4/nftables · hostapd/mt7921 · wireguard│
│  · ksmbd/samba (NAS) · sysntpd · sysupgrade    │
└───────────────────────────────────────────────┘
        LuCI stays installed as the "Advanced" escape hatch
```

- **Strongly recommended frontend base: `oui`** (github.com/zhaojh329/oui) — a Vue-based OpenWrt UI
  framework built on ubus/rpcd, explicitly designed to be GL.iNet-like. Fork it, apply the design
  system, add the wizard + dashboard + VPN/mode flows. It gives you auth, ubus RPC, i18n, build
  integration (OpenWrt package) out of the box. If `oui` is stale, replicate its pattern with a fresh
  Vue 3 + Vite SPA served by `uhttpd`, talking to `rpcd` via the ubus JSON-RPC endpoint.
- **Backend = small rpcd plugins**, not a monolith. Each screen maps to a few ubus methods that wrap
  `uci`/`netifd`/`ubus call` + a `reload_config`. Keep business logic in the backend; the SPA is a view.
- **Package everything as OpenWrt feed packages** (`spookywrt-ui`, `spookywrt-rpc`, `spookywrt-theme`)
  so the image is reproducible and OTA-upgradable via sysupgrade.

---

## 6. Feature scope — the trifecta (all viable on OpenWrt)

- **Router (works):** WAN modes (DHCP/PPPoE/static/repeater), LAN bridge, DHCP/DNS (dnsmasq),
  firewall4/NAT, port-forwarding, DDNS, QoS/SQM (`luci-app-sqm`/`qosify`), per-client controls.
- **Access Point / Wi-Fi (works — MT7921):** 2.4/5 GHz, guest network w/ isolation, WPA2/WPA3,
  SSID QR code, band steering where supported. **This is the role the Ubuntu track could never do.**
- **NAS (works):** `ksmbd` (kernel SMB, light) or samba4; share wizard in the UI; mount USB/SD/eMMC;
  optional `luci-app-diskman`. Expose "Storage" as a dashboard card + a shares screen.
- **VPN (first-class):** WireGuard client+server (config import + QR), OpenVPN client+server. One-tap
  up/down with live status. This is the headline GL.iNet feature — treat it as such.
- **Nice-to-have:** AdGuard Home / adblock, Tailscale, UPnP toggle, scheduled reboot, LED control.

---

## 7. Design system (make it *feel* awesome)

- **Mobile-first**, 8-pt grid, generous white space, large tap targets. Card-based dashboard.
- **One accent color** + neutral gray scale; **light + dark** with a system toggle. (Brand accent is a
  variable — default to a SpookyJuice violet/cyan if branding as SpookyWrt.)
- Consistent icon set (Lucide/Tabler). Toggles for booleans, never checkboxes-in-tables.
- Live sparkline for throughput; status pills (green/amber/red) with words, not just color (a11y).
- Empty states with a one-line "what this is + do X" CTA. Inline `?` tooltips mapping to plain English.
- Every destructive/network-reconfiguring action uses the **rollback-timer pattern** (VERIFIED safe on
  this project): apply → 60–90 s auto-revert unless the user confirms connectivity. GL.iNet does this
  for Wi-Fi/network changes; it prevents lockout. Bake it into `set_wan`, `set_wifi`, `mode_switch`.

---

## 8. Build, deliverables, repo integration

Deliver into `linkstar-h68k`:

- `openwrt/` — the ImmortalWrt build config: `.config` seed, device profile, pinned feeds, a
  `build.sh` that produces `spookywrt-linkstar-h68k-<ver>-{sd,factory}.img` reproducibly (Docker
  buildroot so it runs anywhere).
- `openwrt/packages/` — the `spookywrt-ui` (Vue SPA), `spookywrt-rpc` (rpcd plugins), `spookywrt-theme`
  feed packages, each with a proper OpenWrt Makefile.
- `docs/openwrt.md` — flash (Etcher/`dd` to SD), first-setup wizard walkthrough, recovery (re-flash /
  fall back to eMMC), known issues (2.5 G reset quirk, wifi regulatory).
- `firmware/README.md` — add the OpenWrt image rows: link + SHA256 (no binaries in git).
- CI: shellcheck the scripts; lint the Vue app; optionally a scheduled buildroot job.

**Reproducibility is mandatory** (the user's explicit requirement): pin every source revision;
`build.sh` from a clean checkout must yield a bit-reproducible-enough image + matching SHA256.

---

## 9. Constraints & non-negotiables

- **Never hard-code interface names**; assign WAN/LAN via board.d/DTS by role.
- **NTP-on-boot on** (no RTC). **Firewall default-deny inbound** except LAN + explicitly opened.
- **No secrets in the image**; first-boot forces admin-password set (the wizard does this).
- **Regenerate SSH/host keys + any TLS on first boot** (avoid shared-key defect from the Ubuntu track).
- Keep **LuCI installed**; the custom UI augments, never traps.
- **microSD-first recovery** documented so users are never afraid to experiment.

---

## 10. Success criteria (definition of done)

1. Fresh flash to microSD → boots → **first-setup wizard** on `http://192.168.8.1` (and via mDNS name).
2. **All 4 ethernet + Wi-Fi enumerate**; can run as Router **and** as AP; guest Wi-Fi isolates.
3. **VPN**: import a WireGuard config via QR and reach the tunnel in < 1 min, one-tap up/down.
4. **NAS**: create an SMB share in the UI; mount it from macOS/Windows.
5. **Mobile**: the whole console is usable one-handed on a phone; dashboard tells the story at a glance.
6. **Advanced (LuCI)** reachable in one click.
7. Network-changing actions **auto-rollback** on lost connectivity.
8. `build.sh` reproduces the image + SHA256 from a clean checkout.
9. Cold boot with no network briefly, then NTP corrects the clock; opkg/TLS work.
10. Boots in a comparable-or-better time than stock OpenWrt; minimal attack surface (only intended ports).

---

### Sources to consult

- WIP OpenWrt H68K support: <https://forum.openwrt.org/t/wip-support-for-linkstar-h68k-rk3568/233527>
- Main H68K thread: <https://forum.openwrt.org/t/linkstar-h68k-rk3568-dual-2-5gbe-wifi-6/143246>
- ImmortalWrt firmware selector: <https://firmware-selector.immortalwrt.org/>
- GL.iNet SDK (architecture reference): <https://github.com/gl-inet/sdk>
- `oui` GL.iNet-like Vue/ubus UI framework: <https://github.com/zhaojh329/oui>
