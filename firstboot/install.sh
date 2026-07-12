#!/usr/bin/env bash
#
# install.sh — install the first-boot overlay into a target rootfs.
#
# Two modes:
#   ONLINE  (on the device):      sudo firstboot/install.sh
#   OFFLINE (baking an image):    ROOT=/mnt/rootfs firstboot/install.sh
#
# Copies the toolkit to /opt/linkstar-h68k, installs the oneshot unit, and enables
# it so the secure-baseline (firstboot/run.sh) runs once on the next boot.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "$REPO_DIR/scripts/lib/common.sh"

ROOT="${ROOT:-}"
require_cmd install
[ -z "$ROOT" ] && [ "$(id -u)" -ne 0 ] && die "run with sudo (or set ROOT=/mnt/rootfs for an offline install)"

dest="$ROOT/opt/linkstar-h68k"
log "installing toolkit into $dest"
install -d "$dest/scripts/lib" "$dest/firstboot"
install -m 0755 "$REPO_DIR"/scripts/*.sh          "$dest/scripts/"
install -m 0644 "$REPO_DIR/scripts/lib/common.sh" "$dest/scripts/lib/common.sh"
install -m 0755 "$SCRIPT_DIR/run.sh"              "$dest/firstboot/run.sh"
install -d "$ROOT/etc/systemd/system"
install -m 0644 "$SCRIPT_DIR/linkstar-firstboot.service" \
  "$ROOT/etc/systemd/system/linkstar-firstboot.service"

log "enabling linkstar-firstboot.service"
if [ -z "$ROOT" ]; then
  systemctl daemon-reload
  systemctl enable linkstar-firstboot.service
else
  # Offline: create the WantedBy symlink by hand (no running systemd to talk to).
  install -d "$ROOT/etc/systemd/system/multi-user.target.wants"
  ln -sf /etc/systemd/system/linkstar-firstboot.service \
    "$ROOT/etc/systemd/system/multi-user.target.wants/linkstar-firstboot.service"
fi

ok "installed — the secure baseline will apply once on next boot, then self-disable."
log "log will be at /var/log/linkstar-firstboot.log on the device."
