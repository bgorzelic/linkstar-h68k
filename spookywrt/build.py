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
    # NICs + Wi-Fi (2.5G, MT7921, BE6500 USB Wi-Fi 7)
    "kmod-r8125", "kmod-mt7921e", "kmod-mt7925u", "wpad-basic-mbedtls",
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
    "banip", "luci-app-banip", "socat", "tcpdump",
    # toolkit
    "htop", "nano", "curl", "mtr", "nmap", "arp-scan", "ethtool",
    "lldpd", "iperf3", "irqbalance", "usbutils", "pciutils",
]

def post(body):
    req = urllib.request.Request(ASU, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")

def main():
    defaults = (WORK / "first-boot-full.sh").read_text()
    body = {
        "version": "SNAPSHOT",
        "target": "rockchip/armv8",
        "profile": "hinlink_h68k",
        "packages": PACKAGES,
        "defaults": defaults,
        # H68K default rootfs is tiny; we're writing to a 32GB card, so give the
        # squashfs rootfs 1GB of headroom for the full flagship package set.
        "rootfs_size_mb": 1024,
    }
    print(f"[*] requesting build: {len(PACKAGES)} packages + {len(defaults)}-byte first-boot script")
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
