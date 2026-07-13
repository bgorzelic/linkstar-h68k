#!/usr/bin/env python3
"""Build the SpookyWrt flagship H68K image via the OpenWrt ASU build server."""
import json, sys, time, urllib.request, urllib.error
from pathlib import Path

ASU = "https://sysupgrade.openwrt.org/api/v1/build"
WORK = Path("/tmp/h68k-build")

# The flagship superset — every mode's tools available on the box at once.
PACKAGES = [
    # base + UI + in-UI upgrades
    "luci", "luci-ssl", "luci-theme-material", "luci-app-attendedsysupgrade",
    # ubus-over-HTTP backend for the SpookyWrt dashboard (spookywrt/webui/)
    "uhttpd-mod-ubus", "rpcd", "rpcd-mod-rrdns",
    # NICs + Wi-Fi (2.5G, MT7921 internal, MT7925 USB Wi-Fi 7)
    # USB Wi-Fi drivers ship WITHOUT firmware blobs — you MUST add the matching
    # *-firmware package or the adapter fails init ("MCU is not ready"). Live-verified:
    # kmod-mt7925u is a brick without kmod-mt7925-firmware.
    "kmod-r8125", "kmod-mt7921e", "kmod-mt7925u", "kmod-mt7925-firmware",
    "wpad-basic-mbedtls",
    # NAS / storage
    "block-mount", "kmod-usb-storage", "kmod-usb3", "kmod-fs-ext4",
    "kmod-fs-vfat", "kmod-fs-exfat", "kmod-fs-ntfs3",
    "luci-app-samba4", "samba4-server",
    # VPN (luci-app-wireguard was removed upstream; luci-proto-wireguard is the current LuCI integration)
    "wireguard-tools", "kmod-wireguard", "luci-proto-wireguard",
    # DNS ad-block
    "adguardhome",
    # QoS
    "luci-app-sqm", "sqm-scripts",
    # security / honeypot
    "banip", "luci-app-banip", "socat", "tcpdump", "tcpdump-mini",
    # VPN / mesh — Tailscale (off until `tailscale up`) + policy routing (split-tunnel).
    # WireGuard is already above. openvpn/zerotier are heavier → the `--profile vpn` variant.
    "tailscale", "pbr", "luci-app-pbr",
    # toolkit
    "htop", "nano", "curl", "mtr", "nmap", "arp-scan", "ethtool",
    "lldpd", "iperf3", "irqbalance", "usbutils", "pciutils",
]

# --- wifi-audit variant (OPT-IN, --profile wifi-audit) -----------------------------
# Monitor-mode + injection driver zoo and audit tooling. Kept OUT of the default image:
# it widens the attack surface (~15-20 MB) and should be a deliberate choice. All names
# verified against rockchip/armv8 SNAPSHOT (2026-07-13). Steer users to mt76 / ath9k
# adapters — out-of-tree Realtek (rtl8812au) and kismet/mdk4 are NOT in the snapshot feed
# (they fail the build). See docs/wireless-support.md.
WIFI_DRIVERS = [
    "kmod-mt76x2u", "kmod-mt76x0u", "kmod-mt7601u", "kmod-mt7921u",
    "kmod-ath9k-htc", "kmod-carl9170", "kmod-rt2800-usb", "kmod-rtl8xxxu",
]
WIFI_AUDIT = [
    "aircrack-ng", "hcxdumptool", "hcxtools", "reaver", "horst", "iw", "iwinfo",
]
# Best-of-flavor extras, folded into the audit variant per the swarm's build-verified
# manifest (fa654c6100f8): multi-WAN, band steering, travel, bandwidth, DDNS, DoH,
# uplink watchdog, RRD graphs. All resolve on rockchip/armv8 SNAPSHOT.
WIFI_FLAVOR_EXTRA = [
    "mwan3", "luci-app-mwan3", "dawn", "luci-app-dawn",
    "travelmate", "luci-app-travelmate", "nlbwmon", "luci-app-nlbwmon",
    "ddns-scripts", "luci-app-ddns", "https-dns-proxy", "luci-app-https-dns-proxy",
    "watchcat", "luci-app-watchcat", "luci-app-statistics",
]
# --- vpn variant (OPT-IN, --profile vpn) — the heavier VPN engines on top of the base
# Tailscale + pbr (split-tunnel). Build-verified on SNAPSHOT.
VPN_EXTRA = ["openvpn-openssl", "zerotier"]
PROFILES = ("flagship", "wifi-audit", "vpn")

def build_packages(variant):
    """Return the package list for a build variant. Default flagship stays lean."""
    pkgs = list(PACKAGES)
    if variant == "wifi-audit":
        pkgs += WIFI_DRIVERS + WIFI_AUDIT + WIFI_FLAVOR_EXTRA
        # 6 GHz / WPA3-SAE needs the full supplicant; wpad-basic can't do SAE on 6 GHz.
        pkgs = [p for p in pkgs if p != "wpad-basic-mbedtls"]
        pkgs += ["-wpad-basic-mbedtls", "wpad-mbedtls"]
    elif variant == "vpn":
        pkgs += VPN_EXTRA
    # de-dup while preserving order
    seen, out = set(), []
    for p in pkgs:
        if p not in seen:
            seen.add(p); out.append(p)
    return out

def post(body):
    req = urllib.request.Request(ASU, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")

def main():
    # variant: default "flagship" (lean) or "wifi-audit" (opt-in driver/audit stack)
    variant = "flagship"
    if "--profile" in sys.argv:
        i = sys.argv.index("--profile")
        if i + 1 >= len(sys.argv):          # B2: --profile with no value
            print("[!] --profile needs a value: " + ", ".join(PROFILES)); sys.exit(1)
        variant = sys.argv[i + 1]
    if variant not in PROFILES:
        print(f"[!] unknown --profile '{variant}'. choose one of: {', '.join(PROFILES)}")
        sys.exit(1)
    packages = build_packages(variant)
    WORK.mkdir(parents=True, exist_ok=True)
    # B1: read the first-boot script from the repo, not a manually-staged /tmp copy
    fb = Path(__file__).parent / "first-boot-full.sh"
    defaults = fb.read_text() if fb.exists() else (WORK / "first-boot-full.sh").read_text()
    # onboarding: an unconfigured box raises a "SpookyWrt-Setup" AP so you can configure
    # it over Wi-Fi with no cable (self-disables once you set your own Wi-Fi).
    setup_ap = Path(__file__).parent / "setup-ap.sh"
    if setup_ap.exists():
        defaults += "\n\n# ---- SpookyWrt-Setup onboarding AP ----\n" + setup_ap.read_text()
    # install on-device helper commands into /usr/bin (verbatim, via quoted heredoc so
    # their $vars expand on the device, not at build time).
    for tool in ("spooky", "spooky-capture"):
        tp = Path(__file__).parent / tool
        if tp.exists():
            d = "SPOOKYTOOL_" + tool.replace("-", "_")
            defaults += (f"\n\n# ---- install /usr/bin/{tool} ----\n"
                         f"cat > /usr/bin/{tool} <<'{d}'\n{tp.read_text()}\n{d}\n"
                         f"chmod 0755 /usr/bin/{tool}\n")
    if variant == "wifi-audit":
        # append the fail-closed consent gate (spookywrt/wifi-audit/firstboot.sh)
        gate = Path(__file__).parent / "wifi-audit" / "firstboot.sh"
        if gate.exists():
            defaults += "\n\n# ---- wifi-audit consent gate ----\n" + gate.read_text()
    body = {
        "version": "SNAPSHOT",
        "target": "rockchip/armv8",
        "profile": "hinlink_h68k",
        "packages": packages,
        "defaults": defaults,
        # H68K default rootfs is tiny; we're writing to a 32GB card, so give the
        # squashfs rootfs 1GB of headroom for the full flagship package set.
        "rootfs_size_mb": 1024,
    }
    print(f"[*] variant '{variant}': {len(packages)} packages + {len(defaults)}-byte first-boot script")
    status, data = post(body)
    for _ in range(50):  # poll up to ~5 min
        if status == 200 and data.get("images"):
            break
        if status in (400, 422, 500):  # terminal build failure — surface it and stop
            print(f"[!] BUILD FAILED ({status}): {data.get('detail')}")
            st = data.get("stderr") or ""
            if st:
                print("--- stderr tail ---\n" + st[-900:])
            sys.exit(2)
        print(f"    status={status} state={data.get('status')} … building")
        time.sleep(6)
        status, data = post(body)
    else:
        print("[!] timed out waiting for build"); sys.exit(3)

    bd = data["bin_dir"]
    imgs = data["images"]
    sysup = next((i for i in imgs if i["name"].endswith("squashfs-sysupgrade.img.gz")), None) \
            or next((i for i in imgs if "sysupgrade.img.gz" in i["name"]), imgs[0])
    url = f"https://sysupgrade.openwrt.org/store/{bd}/{sysup['name']}"
    (WORK / "perfect-image.txt").write_text(url)
    (WORK / "perfect-sha.txt").write_text(sysup["sha256"])
    print("[✓] BUILD DONE")
    print(f"    image:  {sysup['name']}")
    print(f"    sha256: {sysup['sha256']}")
    print(f"    url:    {url}")
    print(f"    kernel: {data.get('version_code','?')}  build_at ok")

if __name__ == "__main__":
    main()
