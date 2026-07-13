#!/usr/bin/env bash
#
# optimize-boot.sh — de-bloat the vendor Ubuntu image for appliance use (Ubuntu track).
#
# Disables desktop/appliance services a router/NAS never needs, closes the adbd (:5555) and
# vsftpd (:21) security holes, and masks snapd. All reversible. Verifies the SSH/networkd/ntpsec
# lifeline after. Run on the device with sudo. Idempotent. Honors DRY_RUN=1.
#
# Keeps: systemd-networkd, ssh, ntpsec (no RTC!), avahi, and the desktop (pass --headless to drop it).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[ "$(id -u)" -eq 0 ] || die "run with sudo"
HEADLESS=0; [ "${1:-}" = "--headless" ] && HEADLESS=1

BLOAT=(
  fwupd.service fwupd-refresh.timer apport.service gnome-remote-desktop.service
  ModemManager.service switcheroo-control.service whoopsie.service kerneloops.service
  cups.service cups-browsed.service cups.socket cups.path bluetooth.service packagekit.service
)
log "disabling appliance/desktop bloat (reversible)"
for u in "${BLOAT[@]}"; do run systemctl disable --now "$u" >/dev/null 2>&1 || true; done

log "masking snapd"
run systemctl disable --now snapd.service snapd.socket >/dev/null 2>&1 || true
run systemctl mask snapd.service snapd.socket >/dev/null 2>&1 || true

log "closing security holes: adbd (:5555), vsftpd (:21)"
run systemctl disable --now adbd >/dev/null 2>&1 || true
run update-rc.d -f adbd remove >/dev/null 2>&1 || true
run systemctl disable --now vsftpd >/dev/null 2>&1 || true

if [ "$HEADLESS" -eq 1 ]; then
  warn "headless mode: dropping the graphical desktop"
  run systemctl set-default multi-user.target
  for dm in lightdm lxdm sddm gdm3 display-manager; do run systemctl disable --now "$dm" >/dev/null 2>&1 || true; done
fi

log "verifying lifeline (must stay up)"
for svc in ssh systemd-networkd ntpsec; do
  state="$(systemctl is-active "$svc" 2>/dev/null || true)"
  if [ "$state" = active ]; then ok "$svc: active"; else warn "$svc: $state  (CHECK THIS)"; fi
done
if ip -br addr show | grep -qE "UP.*inet "; then
  ok "network has an IP"
else
  warn "no IP on any interface — verify before rebooting"
fi

ok "done. Reboot to realize the boot-time win, then: systemd-analyze ; systemctl --failed"
warn "only SSH should listen now — confirm with: sudo ss -tlnp"
