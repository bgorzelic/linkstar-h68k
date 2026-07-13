#!/usr/bin/env bash
#
# make-release-image.sh — build a clean, flashable LinkStar H68K release image.
#
# Reproducible "build-fresh" pipeline: vendor RKFW firmware -> unpack -> rebuild
# RKNS idbloader -> apply the networking fix + baseline hardening -> SANITIZE
# (no personal accounts, regenerated SSH host keys on first boot, cleared
# machine-id/logs/history/apt-cache) -> assemble a single GPT disk image ->
# zero free space -> xz. Output is a directly-flashable <name>.img.xz + SHA256.
#
# The image auto-expands its rootfs to fill the card on first boot.
#
# Requires: python3, dd, xz, docker (for sgdisk + the x86-64 rkbin mkimage and
# the privileged loop-mount used to edit the rootfs). Run on macOS or Linux.
#
# Usage: make-release-image.sh <vendor-ubuntu.img> <loader.bin> <out-dir>
# Env:   RKDEVELOPTOOL=/path  RKBIN=/path/to/rkbin   (see build-idbloader.sh)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[[ $# -eq 3 ]] || die "usage: $(basename "$0") <vendor-ubuntu.img> <loader.bin> <out-dir>"
VENDOR="$1"; LOADER="$2"; OUTDIR="$3"
[[ -f "$VENDOR" ]] || die "no such file: $VENDOR"
[[ -f "$LOADER" ]] || die "no such file: $LOADER"
require_cmd python3; require_cmd dd; require_cmd xz; require_cmd docker
mkdir -p "$OUTDIR"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
parts="$work/parts"

log "1/6 unpacking vendor firmware"
"$SCRIPT_DIR/unpack-rkfw.sh" "$VENDOR" "$parts"

log "2/6 rebuilding RKNS idbloader"
"$SCRIPT_DIR/build-idbloader.sh" "$LOADER" "$work/idbloader.img"

log "3/6 applying networking fix + hardening + sanitize to rootfs (offline)"
docker run --rm --privileged -v "$parts:/parts" ubuntu:22.04 bash -c '
set -e
mkdir -p /mnt/r
LOOP=$(losetup -f); losetup "$LOOP" /parts/rootfs.img
mount "$LOOP" /mnt/r
R=/mnt/r; S=$R/etc/systemd/system

# --- networking: single systemd-networkd stack, DHCP on all four ports ---
mkdir -p "$S/multi-user.target.wants" "$S/sockets.target.wants"
ln -sf /lib/systemd/system/systemd-networkd.service "$S/multi-user.target.wants/systemd-networkd.service"
ln -sf /lib/systemd/system/systemd-networkd.socket  "$S/sockets.target.wants/systemd-networkd.socket"
ln -sf /lib/systemd/system/systemd-networkd.service "$S/dbus-org.freedesktop.network1.service"
rm -f "$S/multi-user.target.wants/NetworkManager.service"
rm -f "$S/network-online.target.wants/NetworkManager-wait-online.service"
ln -sf /dev/null "$S/NetworkManager.service"
mkdir -p "$R/etc/netplan"
cat >"$R/etc/netplan/config.yaml" <<YAML
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0: { dhcp4: true, dhcp6: false, optional: true }
    eth1: { dhcp4: true, dhcp6: false, optional: true }
    eth2: { dhcp4: true, dhcp6: false, optional: true }
    eth3: { dhcp4: true, dhcp6: false, optional: true }
YAML
chmod 600 "$R/etc/netplan/config.yaml"

# --- baseline hardening: kill network ADB + FTP, mask first-boot auto-updaters ---
for u in adbd.service vsftpd.service unattended-upgrades.service \
         apt-daily.service apt-daily.timer apt-daily-upgrade.service apt-daily-upgrade.timer; do
  rm -f "$S/multi-user.target.wants/$u" "$S/timers.target.wants/$u"
  ln -sf /dev/null "$S/$u"
done

# --- sanitize: regenerate SSH host keys on first boot; no shared identity ---
rm -f "$R"/etc/ssh/ssh_host_*
cat >"$S/regen-ssh-host-keys.service" <<UNIT
[Unit]
Description=Regenerate SSH host keys on first boot
ConditionPathExistsGlob=!/etc/ssh/ssh_host_*_key
Before=ssh.service
[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
[Install]
WantedBy=multi-user.target
UNIT
ln -sf "$S/regen-ssh-host-keys.service" "$S/multi-user.target.wants/regen-ssh-host-keys.service"

# --- first-boot rootfs auto-expand (the vendor image does NOT auto-grow) ---
cat >"$S/expand-rootfs.service" <<UNIT
[Unit]
Description=Expand root filesystem to fill the card (first boot)
ConditionPathExists=!/var/lib/expand-rootfs.done
[Service]
Type=oneshot
ExecStart=/bin/sh -c "resize2fs \$(findmnt -no SOURCE /) && touch /var/lib/expand-rootfs.done"
[Install]
WantedBy=multi-user.target
UNIT
ln -sf "$S/expand-rootfs.service" "$S/multi-user.target.wants/expand-rootfs.service"

# --- scrub identity + bloat so every flash is fresh and compresses well ---
: > "$R/etc/machine-id"; rm -f "$R/var/lib/dbus/machine-id"
find "$R/var/log" -type f -exec truncate -s0 {} + 2>/dev/null || true
rm -f "$R"/var/cache/apt/archives/*.deb "$R"/var/lib/apt/lists/*Packages* 2>/dev/null || true
rm -f "$R"/root/.bash_history "$R"/home/*/.bash_history 2>/dev/null || true

# --- zero free space so xz squashes the empty part of the fs ---
dd if=/dev/zero of="$R/ZERO.tmp" bs=1M 2>/dev/null || true; rm -f "$R/ZERO.tmp"; sync

umount /mnt/r; losetup -d "$LOOP"
echo "rootfs prepared"
'

log "4/6 assembling GPT disk image"
IMG="$work/release.img"
python3 - "$parts" "$IMG" <<'PY'
import os, subprocess, sys
parts, img = sys.argv[1], sys.argv[2]
SEC = 512
# (name, start_sector, image_or_None)
layout = [
    ("uboot",    16384,   "uboot.img"),
    ("misc",     24576,   "misc.img"),
    ("boot",     32768,   "boot.img"),
    ("recovery", 98304,   "recovery.img"),
    ("backup",   163840,  None),
    ("oem",      229376,  "oem.img"),
    ("userdata", 491520,  "userdata.img"),
    ("rootfs",   2588672, "rootfs.img"),
]
rootfs_bytes = os.path.getsize(os.path.join(parts, "rootfs.img"))
rootfs_secs = (rootfs_bytes + SEC - 1) // SEC
total = 2588672 + rootfs_secs + 34          # + backup GPT
with open(img, "wb") as f:
    f.truncate(total * SEC)
# write idbloader at sector 64 handled by caller; here just partitions
for name, start, fn in layout:
    if not fn:
        continue
    src = os.path.join(parts, fn)
    with open(src, "rb") as s, open(img, "r+b") as d:
        d.seek(start * SEC)
        while True:
            b = s.read(8 << 20)
            if not b:
                break
            d.write(b)
print(f"{total}")   # total sectors, for the GPT step
PY
ROOT_END=$(python3 -c "import os;print(2588672+((os.path.getsize('$parts/rootfs.img')+511)//512)-1)")

# GPT via docker sgdisk, sized to the fixed release image
docker run --rm -v "$work:/w" ubuntu:22.04 sh -c '
  command -v sgdisk >/dev/null || { apt-get update -qq && apt-get install -y -qq gdisk >/dev/null; }
  sgdisk -Z /w/release.img >/dev/null 2>&1 || true
  sgdisk -a 1 \
    -n 1:16384:24575    -c 1:uboot \
    -n 2:24576:32767    -c 2:misc \
    -n 3:32768:98303    -c 3:boot \
    -n 4:98304:163839   -c 4:recovery \
    -n 5:163840:229375  -c 5:backup \
    -n 6:229376:491519  -c 6:oem \
    -n 7:491520:2588671 -c 7:userdata \
    -n 8:2588672:'"$ROOT_END"' -c 8:rootfs -u 8:614e0000-0000-4b53-8000-1d28000054a9 \
    /w/release.img >/dev/null
'
# idbloader at sector 64
dd if="$work/idbloader.img" of="$IMG" bs=512 seek=64 conv=notrunc status=none

log "5/6 compressing (xz -T0)"
base="$(basename "$VENDOR" .img)"
out="$OUTDIR/linkstar-h68k-ubuntu-${base}.img"
mv "$IMG" "$out"
xz -T0 -9 -f "$out"

log "6/6 checksum"
( cd "$OUTDIR" && shasum -a 256 "$(basename "$out").xz" | tee "$(basename "$out").xz.sha256" )
ok "release image: $out.xz"
