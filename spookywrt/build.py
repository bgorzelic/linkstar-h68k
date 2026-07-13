#!/usr/bin/env python3
"""Build SpookyWrt H68K images via the OpenWrt ASU build server.

Four editions on one shared core (see proposals/spookywrt-editions-spec.md):

    casper       (basic)              lean appliance, agent-forward, Basic mode
    poltergeist  (pro, flagship)      full console + VPN/capture + agent, default
    reaper       (hacker, wifi-audit) injection+audit zoo, consent-gated, SEPARATE image
    seance       (dev)                Pro + on-device dev tools, agent as coding buddy

No local toolchain: the ASU server compiles it and you download the ~35 MB result.
The on-device tools + branding ship as a gzip+base64 self-extracting overlay inside
the uci-defaults "defaults" string (raw inlining blew past ASU's 40960-char cap).
"""
import base64
import gzip
import io
import json
import sys
import tarfile
import time
import urllib.error
import urllib.request
from pathlib import Path

ASU = "https://sysupgrade.openwrt.org/api/v1/build"
WORK = Path("/tmp/h68k-build")
HERE = Path(__file__).parent
DEFAULTS_LIMIT = 40960  # ASU hard cap on the uci-defaults string (live-verified)

# --- shared core: every edition gets these -----------------------------------
# base + UI + in-UI upgrades; ubus-over-HTTP backend for the dashboard; NICs +
# Wi-Fi (USB Wi-Fi drivers ship WITHOUT firmware — kmod-mt7925u is a brick without
# kmod-mt7925-firmware, live-verified); storage; WireGuard + Tailscale + policy
# routing; python3 for the on-device agent (the primary interface on Casper); a
# lean toolkit. Heavier prosumer apps live in PRO_APPS.
CORE = [
    "luci", "luci-ssl", "luci-theme-material", "luci-app-attendedsysupgrade",
    "uhttpd-mod-ubus", "rpcd", "rpcd-mod-rrdns",
    "kmod-r8125", "kmod-mt7921e", "kmod-mt7925u", "kmod-mt7925-firmware",
    "wpad-basic-mbedtls",
    "block-mount", "kmod-usb-storage", "kmod-usb3", "kmod-fs-ext4",
    "kmod-fs-vfat", "kmod-fs-exfat", "kmod-fs-ntfs3",
    "wireguard-tools", "kmod-wireguard", "luci-proto-wireguard",
    "tailscale", "pbr", "luci-app-pbr",
    "python3-light", "python3-urllib",           # the on-device agent is CORE
    "tcpdump-mini",
    "htop", "nano", "curl", "mtr", "ethtool", "iw", "iwinfo",
    "usbutils", "pciutils",
]

# --- prosumer apps: Poltergeist / Reaper / Séance (dropped on the Casper appliance)
PRO_APPS = [
    "luci-app-samba4", "samba4-server",          # NAS
    "adguardhome",                               # DNS ad-block
    "luci-app-sqm", "sqm-scripts",               # QoS
    "banip", "luci-app-banip", "socat", "tcpdump",   # security
    "nmap", "arp-scan", "lldpd", "iperf3", "irqbalance",
    "openvpn-openssl", "zerotier",               # full VPN engines (WG/TS are core)
    "python3-scapy",                             # client profiling (spooky-profiler)
    "mwan3", "luci-app-mwan3", "nlbwmon", "luci-app-nlbwmon", "luci-app-statistics",
]

# --- Séance dev tools (kept lean + in-snapshot) ------------------------------
DEV_EXTRA = ["git", "git-http"]

# --- Reaper (Hacker) injection/audit — SEPARATE image, consent-gated ---------
# Names verified against rockchip/armv8 SNAPSHOT (2026-07-13). Steer users to
# mt76 / ath9k adapters — out-of-tree Realtek (rtl8812au) and kismet/mdk4 are NOT
# in the snapshot feed (they fail the build). See docs/wireless-support.md.
WIFI_DRIVERS = [
    "kmod-mt76x2u", "kmod-mt76x0u", "kmod-mt7601u", "kmod-mt7921u",
    "kmod-ath9k-htc", "kmod-carl9170", "kmod-rt2800-usb", "kmod-rtl8xxxu",
]
WIFI_AUDIT = ["aircrack-ng", "hcxdumptool", "hcxtools", "reaver", "horst"]
# Reaper-unique extras (multi-WAN/statistics/nlbwmon already come via PRO_APPS).
WIFI_FLAVOR_EXTRA = [
    "dawn", "luci-app-dawn", "travelmate", "luci-app-travelmate",
    "ddns-scripts", "luci-app-ddns", "https-dns-proxy", "luci-app-https-dns-proxy",
    "watchcat", "luci-app-watchcat",
]

# --- the four editions -------------------------------------------------------
EDITIONS = {
    "casper": {
        "ghost": "Casper", "aliases": ["basic"], "mode": "basic",
        "packages": CORE,
        "desc": "Basic appliance — lean, agent-forward, everything just works",
    },
    "poltergeist": {
        "ghost": "Poltergeist", "aliases": ["pro", "flagship"], "mode": "advanced",
        "packages": CORE + PRO_APPS,
        "desc": "Pro flagship — full console, VPN/capture, profiler-ready, agentic agent",
    },
    "reaper": {
        "ghost": "Reaper", "aliases": ["hacker", "wifi-audit"], "mode": "advanced",
        "packages": CORE + PRO_APPS + WIFI_DRIVERS + WIFI_AUDIT + WIFI_FLAVOR_EXTRA,
        "wpad6ghz": True, "audit": True, "separate": True,
        "desc": "Hacker — injection+audit zoo, consent-gated, services-off (authorized use)",
    },
    "seance": {
        "ghost": "Séance", "aliases": ["dev"], "mode": "advanced",
        "packages": CORE + PRO_APPS + DEV_EXTRA,
        "desc": "Dev — Pro + on-device dev tools, agent as coding buddy",
    },
}
DEFAULT_EDITION = "poltergeist"
ALIASES = {a: name for name, ed in EDITIONS.items() for a in ed["aliases"]}


def resolve(profile):
    """Map an edition name or alias to its canonical key (or None)."""
    profile = profile.lower()
    if profile in EDITIONS:
        return profile
    return ALIASES.get(profile)


def build_packages(ed):
    """Return the deduplicated package list for an edition dict."""
    pkgs = list(ed["packages"])
    if ed.get("wpad6ghz"):
        # 6 GHz / WPA3-SAE needs the full supplicant; wpad-basic can't do SAE there.
        pkgs = [p for p in pkgs if p != "wpad-basic-mbedtls"]
        pkgs += ["-wpad-basic-mbedtls", "wpad-mbedtls"]
    seen, out = set(), []
    for p in pkgs:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out


def build_overlay(ed):
    """Return the uci-defaults 'defaults' string for an edition: a self-extracting
    gzip+base64 overlay that places the on-device files, then sources each run-script
    in its own subshell (so an early `exit 0` can't skip later steps). Compressed to
    stay under DEFAULTS_LIMIT — raw inlining of the ~56 KB overlay does not fit."""
    buf = io.BytesIO()
    tar = tarfile.open(fileobj=buf, mode="w")

    def add_bytes(path, mode, data):
        ti = tarfile.TarInfo(path)
        ti.size = len(data)
        ti.mode = mode
        tar.addfile(ti, io.BytesIO(data))

    def add_file(path, mode, src):
        p = HERE / src
        if p.exists():
            add_bytes(path, mode, p.read_bytes())

    # 1) files placed on the device (tar creates parent dirs; modes preserved)
    add_file("usr/bin/spooky", 0o755, "spooky")
    add_file("usr/bin/spooky-capture", 0o755, "spooky-capture")
    add_file("usr/bin/spooky-vpn", 0o755, "spooky-vpn")
    add_file("usr/bin/spooky-agent", 0o755, "spooky-agent")        # agent is core
    add_file("etc/spooky-agent.conf.example", 0o644, "spooky-agent.conf.example")
    add_file("www/luci-static/spooky/cascade.css", 0o644, "luci-theme-spooky/cascade.css")
    # edition markers — read by the console + `spooky status`
    add_bytes("etc/spookywrt/edition", 0o644, (ed["ghost"] + "\n").encode())
    add_bytes("etc/spookywrt/console-mode", 0o644, (ed["mode"] + "\n").encode())

    # 2) run-scripts, extracted to /tmp/spk/run and sourced in glob (numeric) order
    add_file("tmp/spk/run/10-first-boot.sh", 0o755, "first-boot-full.sh")   # ends `exit 0`
    add_file("tmp/spk/run/50-setup-ap.sh", 0o755, "setup-ap.sh")
    # theme: css already placed above — here just point LuCI at it
    add_bytes("tmp/spk/run/60-theme.sh", 0o755, (
        "uci -q set luci.themes.Spooky='/luci-static/spooky'\n"
        "uci -q set luci.main.mediaurlbase='/luci-static/spooky'\n"
        "uci -q commit luci\n"
    ).encode())
    if ed.get("audit"):
        add_file("tmp/spk/run/70-audit-gate.sh", 0o755, "wifi-audit/firstboot.sh")
    tar.close()

    blob = base64.encodebytes(gzip.compress(buf.getvalue(), 9)).decode()
    return (
        "#!/bin/sh\n"
        f"# ---- SpookyWrt '{ed['ghost']}' self-extracting overlay "
        "(gzip+base64; fits ASU's 40960 cap) ----\n"
        "mkdir -p /tmp/spk\n"
        "cat > /tmp/spk/o.b64 <<'SPK_B64_EOF'\n"
        f"{blob}"
        "SPK_B64_EOF\n"
        "( base64 -d /tmp/spk/o.b64 2>/dev/null "
        "|| openssl base64 -d -A -in /tmp/spk/o.b64 ) > /tmp/spk/o.gz\n"
        "gunzip -c /tmp/spk/o.gz 2>/dev/null | tar -xf - -C /\n"
        "# run each first-boot step as its own process (numeric glob order); full\n"
        "# isolation so an early `exit 0` or `set` in one step can't skip the rest.\n"
        'for s in /tmp/spk/run/*.sh; do [ -f "$s" ] && sh "$s"; done\n'
        "rm -rf /tmp/spk\n"
    )


def post(body):
    req = urllib.request.Request(ASU, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")


def usage():
    print("SpookyWrt editions (one core, four flavors):")
    for name, ed in EDITIONS.items():
        tag = " [separate image]" if ed.get("separate") else ""
        aka = "/".join(ed["aliases"])
        print(f"  {name:12s} ({aka}){tag}\n      {ed['desc']}")
    print(f"\nDefault: {DEFAULT_EDITION}. Usage: build.py [--profile <edition>]")


def main():
    if "--help" in sys.argv or "-h" in sys.argv:
        usage()
        return
    profile = DEFAULT_EDITION
    if "--profile" in sys.argv:
        i = sys.argv.index("--profile")
        if i + 1 >= len(sys.argv):
            print("[!] --profile needs a value.\n")
            usage()
            sys.exit(1)
        profile = sys.argv[i + 1]
    edition = resolve(profile)
    if edition is None:
        print(f"[!] unknown --profile '{profile}'.\n")
        usage()
        sys.exit(1)
    ed = EDITIONS[edition]
    packages = build_packages(ed)
    defaults = build_overlay(ed)
    if len(defaults) > DEFAULTS_LIMIT:
        print(f"[!] first-boot overlay is {len(defaults)} bytes > ASU cap {DEFAULTS_LIMIT}. "
              "Trim the on-device tools or ship them via Image Builder files/.")
        sys.exit(4)
    WORK.mkdir(parents=True, exist_ok=True)
    body = {
        "version": "SNAPSHOT",
        "target": "rockchip/armv8",
        "profile": "hinlink_h68k",
        "packages": packages,
        "defaults": defaults,
        # H68K default rootfs is tiny; we write to a 32 GB card, so give the squashfs
        # rootfs 1 GB of headroom for the full package set.
        "rootfs_size_mb": 1024,
    }
    print(f"[*] {edition} \"{ed['ghost']}\" ({ed['mode']} mode): {len(packages)} packages, "
          f"{len(defaults)}-byte first-boot overlay ({DEFAULTS_LIMIT - len(defaults)} free)")
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
        print("[!] timed out waiting for build")
        sys.exit(3)

    bd = data["bin_dir"]
    imgs = data["images"]
    sysup = next((i for i in imgs if i["name"].endswith("squashfs-sysupgrade.img.gz")), None) \
        or next((i for i in imgs if "sysupgrade.img.gz" in i["name"]), imgs[0])
    url = f"https://sysupgrade.openwrt.org/store/{bd}/{sysup['name']}"
    (WORK / "perfect-image.txt").write_text(url)
    (WORK / "perfect-sha.txt").write_text(sysup["sha256"])
    print("[✓] BUILD DONE")
    print(f"    edition: {edition} ({ed['ghost']})")
    print(f"    image:  {sysup['name']}")
    print(f"    sha256: {sysup['sha256']}")
    print(f"    url:    {url}")
    print(f"    kernel: {data.get('version_code','?')}  build_at ok")


if __name__ == "__main__":
    main()
