# Proposal: wireless driver + injection + 6 GHz packages for `spookywrt/build.py`

> **STATUS (CLI, 2026-07-13): implemented as a variant.** `build.py` now has
> `--profile wifi-audit` (`WIFI_DRIVERS` + `WIFI_AUDIT` + the `wpad-basic→mbedtls` swap);
> the default `flagship` stays lean, per §4's recommendation. Swarm-verified refinements
> (6 GHz regulatory, ImmortalWrt, best-of-flavors) fold in as a follow-up delta.

Verified-buildable additions (all resolve against `rockchip/armv8` SNAPSHOT — tested 2026-07-13).
Apply as a delta to the existing `PACKAGES` list; don't replace the file (it has your PSK/WebUI changes).

## 1. Add these package groups to `build.py`

```python
# --- Wireless: monitor-mode + injection USB chipset zoo (in-tree, injection-grade) ---
# Steer users to mt76 / ath9k adapters — out-of-tree Realtek (rtl8812au etc.) is NOT in
# the snapshot feed and has poor monitor support on OpenWrt. See docs/wireless-support.md.
WIFI_DRIVERS = [
    "kmod-mt76x2u",    # MT7612U — best-in-class monitor+injection (Alfa AWUS036ACM)
    "kmod-mt76x0u",    # MT7610U
    "kmod-mt7601u",    # MT7601U
    "kmod-mt7921u",    # MT7921AU — Wi-Fi 6 USB
    # kmod-mt7925u already in base — MT7925 Wi-Fi 7 / 6 GHz USB
    "kmod-ath9k-htc",  # AR9271/AR7010 — classic injection gold standard (2.4 GHz)
    "kmod-carl9170",   # AR9170
    "kmod-rt2800-usb", # Ralink RT2870/3070/5370
    "kmod-rtl8xxxu",   # in-tree Realtek USB (connectivity; limited monitor)
]

# --- Wireless audit tooling (verified in snapshot) ---
WIFI_AUDIT = [
    "aircrack-ng", "hcxdumptool", "hcxtools", "reaver", "horst", "iw", "iwinfo",
    # NOT in aarch64 snapshot — do NOT add: kismet, mdk4 (build fails). Document opkg/extra-feed instead.
]
```

Then include them in the build:

```python
PACKAGES = [ ... existing ... ] + WIFI_DRIVERS + WIFI_AUDIT
```

## 2. 6 GHz: swap the supplicant (they conflict)

`wpad-basic-mbedtls` can't do WPA3-SAE on 6 GHz. For the 6 GHz / Wi-Fi 7 path (`kmod-mt7925u`):

```python
# remove basic, add full — order matters; ASU accepts the "-pkg" removal syntax
PACKAGES = [p for p in PACKAGES if p != "wpad-basic-mbedtls"]
PACKAGES += ["-wpad-basic-mbedtls", "wpad-mbedtls"]
```

(If you'd rather keep images lean, gate this behind a `--sixghz` / wireless-audit variant flag.)

## 3. rootfs size

The base flagship already sets `rootfs_size_mb: 1024`. Adding ~9 drivers + audit tools stays well under
that; no change needed. A full wireless-audit variant (drivers + all audit tools + kismet-from-feed)
should keep the 1 GB rootfs.

## 4. Suggested: a wireless-audit *variant*, not always-on

These drivers/tools widen attack surface and add ~15–20 MB. Recommend a build variant (mirrors the
flavor idea): default flagship stays clean; `build.py --profile wifi-audit` adds `WIFI_DRIVERS +
WIFI_AUDIT + wpad-mbedtls`. Ties into the **hacker/honeypot** modes already in the modes list.

## 5. Best-of-flavors packages (optional, high value — see docs/wireless-support.md)

`mwan3`+`luci-app-mwan3` (dual-WAN — 4 ports!), `dawn`+`luci-app-dawn` (band steering, ⚠ no WPA3),
`travelmate`+`luci-app-travelmate` (Travel mode), `nlbwmon`+`luci-app-nlbwmon`, `ddns-scripts`+
`luci-app-ddns`, `https-dns-proxy`+`luci-app-https-dns-proxy`, `watchcat`+`luci-app-watchcat`.
All resolve on snapshot (spot-checked). ImmortalWrt as an alternate base flavor for max H68K hw support.
