# SpookyWrt — Wireless chipset, monitor-mode & injection support

<sub>[Home](../README.md) › [Docs](README.md) › Wireless support</sub>

Goal: bake in the widest **monitor-mode + packet-injection** Wi-Fi coverage that actually works on
OpenWrt, plus a clear 6 GHz story. Every package below was **verified to resolve** against the current
`rockchip/armv8` SNAPSHOT via the Attended-Sysupgrade build server (2026-07-13).

## The rule: mt76 + ath9k are the injection stack, not Realtek

The community + our own build test agree: on OpenWrt, use **in-tree mac80211 drivers** (mt76, ath9k_htc,
carl9170, rt2800usb). The out-of-tree Realtek drivers (`rtl8812au`, `rtl8821cu`, `rtl88x2bu`, `rtl8814au`,
`rtl8188eu`…) have poor/no monitor-mode support on OpenWrt **and are not in the snapshot feed at all**
(build resolver: `missing (kmod-rtl8812au-ct, kmod-rtl8814au, kmod-rtl8821cu, kmod-rtl88x2bu, …)`).
Steer users to mt76/ath9k adapters rather than shipping brittle Realtek blobs.

## Verified-buildable driver matrix (bake these in)

| Package | Chipset | Band | Monitor / inject | Notable adapters |
|---------|---------|------|------------------|------------------|
| `kmod-mt76x2u` | **MT7612U** | 2.4/5 (AC1200) | ★ best — 85–95% inject | Alfa AWUS036ACM, tested pentest favorite |
| `kmod-mt76x0u` | MT7610U | 2.4/5 (AC600) | ✓ solid | Alfa AWUS036ACS |
| `kmod-mt7601u` | MT7601U | 2.4 | ✓ | cheap N150 dongles |
| `kmod-mt7921u` | MT7921AU | 2.4/5 (Wi-Fi 6) | ✓ | modern AX USB |
| `kmod-mt7925u` | **MT7925** | 2.4/5/**6** (Wi-Fi 7) | ✓ | **the 6 GHz path** (Netgear BE-class USB) |
| `kmod-ath9k-htc` | **AR9271 / AR7010** | 2.4 | ★ classic gold standard | TP-Link TL-WN722N v1, Alfa AWUS036NHA |
| `kmod-carl9170` | AR9170 | 2.4 | ✓ | legacy |
| `kmod-rt2800-usb` | Ralink RT2870/3070/5370 | 2.4 | ✓ | Alfa AWUS036NH |
| `kmod-rtl8xxxu` | RTL8188/8192/8723 (in-tree) | 2.4/5 | client (limited monitor) | generic dongles — connectivity, not injection |

Plus the internal radio: `kmod-mt7921e` (H68K's onboard MT7921, 2.4/5 GHz, Wi-Fi 6 — **no 6 GHz**).

## 6 GHz — the honest answer

- **The H68K's internal MT7921 is Wi-Fi 6, 2.4/5 GHz only — no 6 GHz.** 6 GHz needs Wi-Fi 6E/7 silicon.
- **6 GHz path = a MT7925 (Wi-Fi 7) USB adapter** → `kmod-mt7925u`. Baked in.
- 6 GHz uses WPA3-SAE/OWE + PMF. **Correction (see Addendum §A):** `wpad-basic-mbedtls` already includes
  SAE, OWE and 802.11w, so it is *sufficient* for 6 GHz — the `wpad-basic-mbedtls` → **`wpad-mbedtls`**
  swap (`-wpad-basic-mbedtls`, `+wpad-mbedtls`; they conflict) is an **optional** enterprise/EAP upgrade,
  **not** a 6 GHz prerequisite. Also needs `wireless-regdb` (in base) and a country that permits 6 GHz —
  and **US 6 GHz AP is blocked by default** (Addendum §B).
- AP-side 6 GHz on a *board* (not USB) would need MT7916/MT7986a (Filogic 6E) or ath11k/ath12k hardware —
  out of scope for the H68K, relevant to the multi-platform targets.

## Audit tooling (verified in snapshot)

`aircrack-ng` · `hcxdumptool` + `hcxtools` (WPA/PMKID capture — the modern workflow) · `reaver` (WPS) ·
`horst` (live radio analyzer) · `iw` · `iwinfo` · `tcpdump`.

**Not in the aarch64 snapshot** (don't add — build will fail): `kismet`, `mdk4`, and every out-of-tree
`rtl88*` driver. If a user wants kismet/mdk4, document `opkg`-ing from a third-party feed or building
Image Builder with an extra feed — don't bake them into the default manifest.

## Best features worth stealing from other OpenWrt flavors

| Feature | Package(s) | Why | Note |
|---------|-----------|-----|------|
| **Multi-WAN failover/balance** | `mwan3`, `luci-app-mwan3` | the H68K has 4 ports — perfect for dual-WAN | high value |
| **Band steering / fast roaming** | `dawn`, `luci-app-dawn` | 802.11k/v steering across APs | ⚠ not compatible with WPA3 |
| **Travel-router upstream join** | `travelmate`, `luci-app-travelmate` | captive-portal + repeater for Travel mode | pairs with the Travel mode |
| **Per-device bandwidth** | `nlbwmon`, `luci-app-nlbwmon` | who's using the pipe | light |
| **Graphs / telemetry** | `luci-app-statistics` (collectd) | historical rrd graphs in LuCI | heavier |
| **Dynamic DNS** | `ddns-scripts`, `luci-app-ddns` | reach the box on a dynamic IP | |
| **DoH resolver** | `https-dns-proxy`, `luci-app-https-dns-proxy` | encrypted DNS | complements AdGuard |
| **Auto-heal** | `watchcat`, `luci-app-watchcat` | reboot/reconnect on dead uplink | headless resilience |

### Base distro option: ImmortalWrt — DO NOT SHIP (see Addendum §C)

**Correction:** empirical profile checks show ImmortalWrt has **no `hinlink_h68k` profile** in either
24.10.0 stable or SNAPSHOT rockchip/armv8 — a `build` request for that profile 500s. Its ASU is the same
`openwrt/asu` codebase (host swap works *in principle*), and its Realtek USB breadth is genuinely wider,
but with no H68K profile a "SpookyWrt-IW" variant is a **non-starter today**. Stay on upstream OpenWrt.
Full analysis + the one condition that would change this: Addendum §C.

## Recommended adapters to document (buy-this list)

- **Alfa AWUS036ACM** (MT7612U) — the do-everything dual-band injection adapter.
- **AR9271** (TL-WN722N *v1*, Alfa AWUS036NHA) — rock-solid 2.4 GHz injection, universally supported.
- **MT7925 USB** (Wi-Fi 7) — the only way to touch **6 GHz** on the H68K.

---

## Sources

- [MT7612U monitor mode + injection guide](https://www.aliexpress.com/s/wiki-ssr/article/mt76-mt7612u-monitor-mode-injection-linux)
- [USB Wi-Fi adapters for monitor mode — InfiShark](https://infishark.com/blogs/learn/usb-wifi-adapters-for-monitor-mode)
- [morrownr 8812au driver (why out-of-tree Realtek is painful)](https://github.com/morrownr/8812au-20210820)
- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) · [firmware selector](https://firmware-selector.immortalwrt.org/)
- [OpenWrt forum — DAWN band steering (WPA3 caveat)](https://forum.openwrt.org/t/dawn-band-steering/71767)
- [OpenWrt forum — LinkStar H68K](https://forum.openwrt.org/t/linkstar-h68k-rk3568-dual-2-5gbe-wifi-6/143246)

---

# Addendum (2026-07-13) — 6 GHz deep-dive, regulatory blocker & ImmortalWrt verdict

Supersedes the two "Correction" pointers above. Every claim here is empirically checked (kernel driver
history, upstream regdb behavior, and direct ImmortalWrt profile-manifest reads).

## §A — wpad: the 6 GHz swap is OPTIONAL, not required

`kmod-mt7925u` (already in base) is the whole radio story on SNAPSHOT: the `mt7925` driver landed in
**Linux 6.7**; SNAPSHOT ships ~6.12, so 2.4/5/**6 GHz** + Wi-Fi 7 (802.11be/MLO) all enumerate, and the
MT7925 firmware blobs are pulled in with the kmod (confirm `dmesg | grep mt7925` on first boot).

`wpad-basic-mbedtls` **already includes WPA3-SAE, OWE, and 802.11w (PMF)** — which is exactly and all that
6 GHz mandates (6 GHz allows only SAE or OWE, PMF required). So basic wpad brings up a 6 GHz AP fine.
Full `wpad-mbedtls` only adds 802.1X/EAP-server, RADIUS, Hotspot 2.0, OWE-transition — none needed for a
standard PSK/SAE or open-OWE AP. **Net: keep `wpad-basic-mbedtls` in base; swap to full wpad only if you
actually want enterprise/EAP.** If you do swap, they conflict — use `-wpad-basic-mbedtls` then `wpad-mbedtls`.
Maturity flag: the USB path (`mt7925u`) is less battle-tested than PCIe (`mt7925e`); expect occasional
MLO/stability rough edges — "works, watch it," not a blocker.

## §B — Regulatory: US 6 GHz AP is BLOCKED by default (the real work)

MediaTek chips defer to OpenWrt's `wireless-regdb` (no self-managed regdom). The upstream regdb marks
**US 6 GHz with `NO-IR` (No-Initiate-Radiation)** → the kernel/hostapd refuses AP mode. Signature in logs:
`Frequency 59xx… not allowed for AP mode, flags: 0x10001 … NO-IR`. STA/client mode works; **AP mode does not.**
Root cause: regdb can't yet express US 6 GHz LPI (Low-Power-Indoor, no-AFC) vs Standard-Power (AFC) PSD
rules, so the conservative `NO-IR` stays (regressed from 23.05 → SNAPSHOT).

- **Regdomains that DO unlock 6 GHz AP (UNII-5..8) today: `GB`, `JP`, `CA`.** `US` (and DE-style) block it.
- **Two ways to ship US 6 GHz AP:**
  1. **Patch `wireless-regdb`** — clone regdb, strip `NO-IR` from the US 6 GHz `db.txt` line, rebuild
     `regulatory.db`, drop it at `/lib/firmware/regulatory.db`. **ASU cannot build a patched regdb** — this
     is a post-flash overlay / optional custom package, *not* a package-list line. Ship it as an opt-in
     override so the default image stays legally conservative.
  2. **Set `country=CA`** (or GB/JP) on the 6 GHz radio — zero patching, works immediately, but a
     regulatory/legal compromise for US operators.
- **Flavor recommendation:** default `US` for 2.4/5 GHz; document that 6 GHz AP on US needs the regdb
  override package **or** a permissive country code. Do **not** assume `country=US` "just works" on 6 GHz.

### UCI: 6 GHz radio (MT7925U)

```text
config wifi-device 'radio2'
    option type    'mac80211'
    option path    '...usb.../mt7925u'   # find the adapter's phy: `iw dev` / `ls /sys/class/ieee80211`
    option band    '6g'                   # REQUIRED — do not rely on 5 GHz auto-detect
    option channel '37'                   # a PSC channel: 5/37/69/101/133/165/197 (fast 6E/7 discovery)
    option htmode  'HE80'                 # Wi-Fi 6E; 'EHT160'/'EHT320' for Wi-Fi 7 (320 MHz region-gated)
    option country 'CA'                   # 'US' only with a patched regdb (see §B)
    option cell_density '0'

config wifi-iface 'default_radio2'
    option device     'radio2'
    option network    'lan'
    option mode       'ap'
    option ssid       'SpookyJuice-6G'
    option encryption 'sae'               # 6 GHz = SAE only (or 'owe' for open). NO wpa2/psk/mixed.
    option key        '...'
    option ieee80211w '2'                 # PMF MANDATORY on 6 GHz (2 = required)
```

Rules: `band='6g'` mandatory; prefer a **PSC** channel; `encryption` must be `sae`/`owe` (hostapd rejects
WPA2/PSK/mixed on 6 GHz); `ieee80211w='2'` mandatory; start `HE80` for bring-up, move to EHT once proven.

## §C — ImmortalWrt verdict: DO NOT ship a SpookyWrt-IW H68K variant

One hard blocker kills it: **no H68K profile.** Direct manifest reads:

- 24.10.0 stable rockchip/armv8: 44 profiles — **no `hinlink_h68k`/`h68k`/`hinlink`/`linkstar`**.
- SNAPSHOT (r40154) rockchip/armv8: 64 profiles — **still none.** (Upstream OpenWrt SNAPSHOT *has* it.)

ImmortalWrt has other RK3568 boards (`lyt_t68m`, `firefly_roc-rk3568-pc`, `9tripod_x3568-v4`) but not the
H68K, so a `POST /api/v1/build` with `profile: hinlink_h68k` to its ASU 500s (unsupported profile). Its ASU
runs the same `openwrt/asu` codebase (apk snapshot, same 202/200/500 semantics — host swap works *once a
profile exists*), and its aarch64 kmods feed genuinely carries what upstream refuses (`rtl8188eu`,
`rtl8189es`, `rtl8812au-ct`, full rtw88/rtw89 USB: 8812/8814/8821/8822/8852 — mac80211-native injection).
But none of that is reachable without an H68K profile. (Also: `sysupgrade.immortalwrt.org` returned
Cloudflare 526 during testing — endpoint reliability is worse than OpenWrt's.)

- **Stay on upstream OpenWrt** — the in-tree injection drivers already verified cover most common USB
  dongles without Realtek OOT trees.
- **Only if Realtek-USB becomes a hard requirement:** upstream a `hinlink_h68k` DTS/target port to
  ImmortalWrt (same rockchip/armv8 target — a profile+DTS addition, not a new target), then revisit.
- Optics note: ImmortalWrt's China-oriented brand defaults (zh-cn LuCI, CN mirrors, extra proxy pkgs) are
  cosmetic/removable and it's source-auditable (no known telemetry), but worth weighing for a security brand.

## Addendum sources

- [Linux Wireless — MediaTek driver (mt7925 = 6.7+)](https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html)
- [morrownr/USB-WiFi #308 — mt7925 USB/PCIe kernel 6.7](https://github.com/morrownr/USB-WiFi/issues/308)
- [OpenWrt forum — "US 6GHz: how to proceed" (NO-IR, regdb patch, GB/JP/CA)](https://forum.openwrt.org/t/us-6ghz-how-to-proceed/245998)
- [openwrt/openwrt #18079 — 6GHz not working with US country code](https://github.com/openwrt/openwrt/issues/18079)
- [openwrt/openwrt #14238 — mt7921u AP won't start in 6GHz (NO-IR)](https://github.com/openwrt/openwrt/issues/14238)
- [OpenWrt forum — wpad-basic-mbedtls includes SAE/OWE/802.11w](https://forum.openwrt.org/t/replacing-libustream-mbedtls-and-wpad-basic-mbedtls-packages-with-openssl-variants/153263)
- [luci #7553 — 6GHz mandates WPA3/OWE](https://github.com/openwrt/luci/issues/7553)
- Direct manifest checks: `downloads.immortalwrt.org` 24.10.0 + snapshot rockchip/armv8 `profiles.json`,
  aarch64 `kmods/*/index.json`; `downloads.openwrt.org` snapshot for the upstream contrast.
