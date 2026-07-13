# PROPOSAL — SpookyWrt `wifi-audit` build variant (DEFINITIVE spec)

> **STATUS (CLI, 2026-07-13): integrated.** `build.py --profile wifi-audit` includes the full
> verified delta incl. the 15 best-of-flavor packages (73 tokens = 70 + my 3 dashboard backend
> pkgs). The §4 consent gate ships as `spookywrt/wifi-audit/firstboot.sh` (fail-closed
> `spooky-audit` wrapper + `spooky-audit-consent` recorder + banner + regdom/rfkill preflight),
> appended to first-boot when building the variant. Docs synced.

Status: **build-verified, shippable.** ASU SNAPSHOT, `rockchip/armv8`, profile `hinlink_h68k`, HTTP 200
with images, `rootfs_size_mb: 1024` (no storage-exceed, zero missing, zero conflicts). 70 package tokens.
For the terminal (repo-owner) session to integrate as `flavors/wifi-audit`. Docs owner: this staging dir.

---

## 1. FINAL manifest (only build-proven packages)

**Do NOT ship in the flagship default.** Opt-in variant download only (see §4). `rootfs_size_mb: 1024`.

The variant = **BASE manifest** (39 tokens) **with the wpad swap** + **8 drivers** + **7 audit tools** +
**15 best-of-flavor** packages. Delta over base is listed below (base is unchanged and assumed present).

### wpad swap (2 tokens) — order matters, they conflict

```text
-wpad-basic-mbedtls
wpad-mbedtls
```

> NOTE: per the 6 GHz finding this swap is **optional** (basic wpad already has SAE/OWE/PMF). It is
> included here because the shippable set was build-verified *with* it and full wpad adds enterprise/EAP.
> If you prefer a smaller supplicant, drop both tokens and keep `wpad-basic-mbedtls` — 6 GHz still works.

### Drivers — injection/monitor USB (8 tokens)

```text
kmod-mt76x2u        # MT7612U  — best injection (Alfa AWUS036ACM)
kmod-mt76x0u        # MT7610U
kmod-mt7601u        # MT7601U
kmod-mt7921u        # MT7921AU (Wi-Fi 6)
kmod-ath9k-htc      # AR9271/AR7010 — classic gold standard
kmod-carl9170       # AR9170
kmod-rt2800-usb     # Ralink RT2870/3070/5370
kmod-rtl8xxxu       # in-tree Realtek (connectivity; limited monitor)
```

(`kmod-mt7925u` = the 6 GHz driver and `kmod-mt7921e` = internal radio are already in BASE.)

### Audit tools (7 tokens)

```text
aircrack-ng
hcxdumptool
hcxtools
reaver
horst
iw
iwinfo
```

(`tcpdump` already in BASE.) **Excluded — NOT in aarch64 snapshot, would fail the build:** `kismet`,
`mdk4`, and every out-of-tree `rtl88*` driver.

### Best-of-flavor (15 tokens)

```text
mwan3                    luci-app-mwan3            # multi-WAN failover/balance (4 ports)
dawn                     luci-app-dawn             # 802.11k/v band steering (⚠ not WPA3-compatible)
travelmate               luci-app-travelmate       # travel-router upstream join
nlbwmon                  luci-app-nlbwmon          # per-device bandwidth
ddns-scripts             luci-app-ddns             # dynamic DNS
https-dns-proxy          luci-app-https-dns-proxy  # DoH resolver
watchcat                 luci-app-watchcat         # auto-heal dead uplink
luci-app-statistics                                # collectd rrd graphs
```

**Token count:** 38 base (39 − `wpad-basic-mbedtls`) + 2 swap + 8 + 7 + 15 = **70**. Build id `fa654c6100f8`.

---

## 2. build.py DELTA (add `--profile wifi-audit` on top of base PACKAGES — do NOT rewrite the file)

Drop-in; adapt names to the file's existing structure. Assumes a base list `PACKAGES` (or `BASE_PACKAGES`)
and an argparse `parser`. The swap is done correctly: append the audit delta, then remove
`wpad-basic-mbedtls` and add `wpad-mbedtls` — de-duped, order-preserved.

```python
# --- SpookyWrt wifi-audit variant (append near the package/flavor definitions) ---

WIFI_AUDIT_EXTRA: list[str] = [
    # injection / monitor USB drivers (mt7925u + mt7921e already in base)
    "kmod-mt76x2u", "kmod-mt76x0u", "kmod-mt7601u", "kmod-mt7921u",
    "kmod-ath9k-htc", "kmod-carl9170", "kmod-rt2800-usb", "kmod-rtl8xxxu",
    # audit suite (tcpdump already in base)
    "aircrack-ng", "hcxdumptool", "hcxtools", "reaver", "horst", "iw", "iwinfo",
    # best-of-flavor
    "mwan3", "luci-app-mwan3", "dawn", "luci-app-dawn",
    "travelmate", "luci-app-travelmate", "nlbwmon", "luci-app-nlbwmon",
    "ddns-scripts", "luci-app-ddns", "https-dns-proxy", "luci-app-https-dns-proxy",
    "watchcat", "luci-app-watchcat", "luci-app-statistics",
]

# 6 GHz / WPA3-enterprise supplicant swap (they conflict — remove basic, add full).
# Optional per the 6 GHz finding (basic wpad already has SAE/OWE); included as build-verified default.
WIFI_AUDIT_WPAD_SWAP = ("wpad-basic-mbedtls", "wpad-mbedtls")


def build_wifi_audit_packages(base: list[str]) -> list[str]:
    """Base manifest + audit delta with the wpad swap applied. Order-preserved, de-duped."""
    drop, add = WIFI_AUDIT_WPAD_SWAP
    pkgs = [p for p in base if p != drop]          # remove wpad-basic-mbedtls
    for p in (*WIFI_AUDIT_EXTRA, add):             # append extras + wpad-mbedtls
        if p not in pkgs:
            pkgs.append(p)
    return pkgs


FLAVORS: dict[str, callable] = {
    # "flagship": lambda base: base,   # default — untouched
    "wifi-audit": build_wifi_audit_packages,
}

# --- in argument parsing ---
parser.add_argument(
    "--profile", "--flavor", dest="flavor", default="flagship",
    choices=["flagship", "wifi-audit"],
    help="build flavor: flagship (default router) or wifi-audit (opt-in field tool)",
)

# --- where the request body is assembled ---
packages = FLAVORS.get(args.flavor, lambda base: base)(PACKAGES)
body = {
    "version": "SNAPSHOT",
    "target": "rockchip/armv8",
    "profile": "hinlink_h68k",
    "packages": packages,
    "rootfs_size_mb": 1024,   # verified fits with wide margin; only bump on "exceed device storage"
}
```

**Downstream pin:** if any later flavor re-adds `wpad-basic-mbedtls`, the conflict returns — keep it
pinned out of the wifi-audit variant.

---

## 3. Docs

Captured in `docs/wireless-support.md` (Addendum §A/§B/§C, 2026-07-13): 6 GHz on MT7925U (driver + the
US `NO-IR` regulatory blocker + UCI config) and the ImmortalWrt no-H68K-profile verdict. Two now-stale
claims in that doc's body were corrected inline (wpad "required" → optional; "ship SpookyWrt-IW" → do not).

---

## 4. Safety guardrail decision — VARIANT, not always-on

**Ship `wifi-audit` as an opt-in build variant, never fused into the flagship default.** The flagship is a
*router* people put on their home WAN and forget; the audit image is an *offensive-capable field tool* with
monitor-mode injection radios + WPA-handshake/PMKID capture (`hcxdumptool`, `aircrack-ng`, `reaver`).
Fusing them turns every casual flagship unit into a pre-armed attack platform — a compromised router
(banIP/AdGuard/Samba all face the LAN) would hand an attacker injection radios for lateral pivoting — and
changes the device's legal character (US CFAA, UK CMA 1990, EU equivalents) without the user's informed
choice. A separate download is a clean consent boundary; it also mirrors the brand's existing
honeypot/hacker-mode pattern (gated, labeled, logged — not ambient). Build cost is immaterial (fits 1024 MB
with headroom; boot adds low-single-digit seconds only when adapters are plugged), so the case is about
consent and liability, not resources. Two runtime guardrails are load-bearing and must ship with it:
**force a regdom before injection** (unset regdom silently no-IRs channels / TXes out-of-spec) and
**rfkill-preflight**; audit helpers target by phy/driver, never hardcoded `wlan0`.

### First-boot consent gate (LuCI interstitial + SSH MOTD)

Offensive tooling stays off `$PATH` behind a `spooky-audit <tool>` wrapper that **fails closed** until
consent is recorded AND `uci get spookywrt.audit.enabled == 1`. UCI flags:

```text
spookywrt.audit.enabled      # 0 default; 1 only after consent
spookywrt.audit.scope        # free-text authorized scope (logged)
spookywrt.audit.consent_ts   # epoch
spookywrt.audit.regdom       # ISO country — REQUIRED before injection
```

Consent + scope + timestamp + acknowledger persist to `/etc/spookywrt/audit-consent.json` (0600) and
append to the tamper-evident audit trail; every tool invocation logs actor/tool/timestamp/scope. Captures
stay local — no auto-upload.

**Exact banner/consent text:**

> **SpookyWrt — Wi-Fi Audit Edition — Authorized Use Only**
> This image contains packet-injection drivers and wireless audit tools (aircrack-ng, hcxdumptool, reaver).
> Using them against any network, device, or radio spectrum you do not own or have **explicit written
> authorization** to test is illegal in most jurisdictions (e.g. US CFAA 18 U.S.C. §1030, UK Computer
> Misuse Act 1990) and may violate radio regulations (FCC Part 15 / your local regulator).
> By continuing you attest: (1) you are the owner or hold written authorization for the target scope;
> (2) you accept full legal responsibility; (3) SpookyJuice provides this tool with no warranty and no
> liability.
> Type the target scope you are authorized to test, then `I ACCEPT` to enable audit tooling.
