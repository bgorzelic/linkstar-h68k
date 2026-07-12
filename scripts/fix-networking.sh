#!/usr/bin/env bash
#
# fix-networking.sh — resolve the "no DHCP" problem on the vendor Ubuntu image.
#
# The image enables THREE network stacks at once (netplan/systemd-networkd,
# NetworkManager, and ifupdown), which race for eth0/eth1 and often leave the
# box with no address. This standardizes on systemd-networkd, masks
# NetworkManager, and sets DHCP on all four ports.
#
# Run on the device with sudo, or against an offline rootfs with ROOT=/mnt/root.
# Idempotent.
#
# Usage: sudo ./fix-networking.sh
#        ROOT=/mnt/root ./fix-networking.sh   # offline (mounted rootfs)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${ROOT:-}"
sysd="$ROOT/etc/systemd/system"
[ -d "$ROOT/etc/systemd" ] || die "no systemd tree at ${ROOT:-/}etc/systemd — wrong ROOT?"
[ -z "$ROOT" ] && [ "$(id -u)" -ne 0 ] && die "run with sudo (or set ROOT= for offline)"

log "enabling systemd-networkd"
mkdir -p "$sysd/multi-user.target.wants" "$sysd/sockets.target.wants"
ln -sf /lib/systemd/system/systemd-networkd.service "$sysd/multi-user.target.wants/systemd-networkd.service"
ln -sf /lib/systemd/system/systemd-networkd.socket  "$sysd/sockets.target.wants/systemd-networkd.socket"
ln -sf /lib/systemd/system/systemd-networkd.service "$sysd/dbus-org.freedesktop.network1.service"

log "masking NetworkManager (stops the stack conflict)"
rm -f "$sysd/multi-user.target.wants/NetworkManager.service"
rm -f "$sysd/network-online.target.wants/NetworkManager-wait-online.service"
ln -sf /dev/null "$sysd/NetworkManager.service"

log "writing netplan: DHCP on eth0-eth3 (optional so a down port never blocks boot)"
mkdir -p "$ROOT/etc/netplan"
cat >"$ROOT/etc/netplan/config.yaml" <<'YAML'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0: { dhcp4: true, dhcp6: false, optional: true }
    eth1: { dhcp4: true, dhcp6: false, optional: true }
    eth2: { dhcp4: true, dhcp6: false, optional: true }
    eth3: { dhcp4: true, dhcp6: false, optional: true }
YAML
chmod 600 "$ROOT/etc/netplan/config.yaml"

if [ -z "$ROOT" ]; then
  log "applying now"
  netplan generate 2>/dev/null || true
  systemctl enable --now systemd-networkd 2>/dev/null || true
  netplan apply 2>/dev/null || warn "netplan apply reported an issue; a reboot will apply cleanly"
  ok "done. Check with: ip -brief addr"
else
  ok "offline changes written under $ROOT — will take effect on next boot"
fi

warn "note: eth2/eth3 are the 2.5G RTL8125B ports; their driver is a known vendor bug and may not come up"
