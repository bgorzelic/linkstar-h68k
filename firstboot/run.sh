#!/usr/bin/env bash
#
# linkstar first-boot baseline — applied ONCE on a freshly flashed image, then the
# service disables itself. Makes a vendor image secure-and-sane on first boot:
#   - regenerate SSH host keys (the vendor image ships keys shared across all units)
#   - mask the auto-updaters (avoids the first-boot dpkg-lock hang)
#   - expand rootfs, fix networking, disable adb/FTP + add a firewall
#
# It deliberately does NOT disable SSH password auth (a generic image has no user
# key yet) — run `harden.sh --pubkey-file …` yourself for key-only login.
#
# Installed + enabled by firstboot/install.sh. Logs to /var/log/linkstar-firstboot.log.
set -uo pipefail

BASE="/opt/linkstar-h68k/scripts"
LOG="/var/log/linkstar-firstboot.log"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1
echo "===== linkstar-firstboot $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo) ====="

# 1. Regenerate SSH host keys (vendor image bakes in shared keys).
echo "[1/5] regenerating SSH host keys"
rm -f /etc/ssh/ssh_host_*
if command -v dpkg-reconfigure >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server || ssh-keygen -A
else
  ssh-keygen -A
fi
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

# 2. Mask the auto-updaters (first-boot apt-lock trap).
echo "[2/5] masking auto-updaters"
systemctl mask unattended-upgrades apt-daily.service apt-daily-upgrade.service \
               apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

# 3-5. Reuse the toolkit for storage, networking, and hardening.
echo "[3/5] expanding rootfs"
[ -x "$BASE/expand-rootfs.sh" ] && "$BASE/expand-rootfs.sh" || echo "  (expand-rootfs.sh missing/failed — skipping)"
echo "[4/5] fixing networking"
[ -x "$BASE/fix-networking.sh" ] && "$BASE/fix-networking.sh" || echo "  (fix-networking.sh missing/failed — skipping)"
echo "[5/5] hardening (adb/FTP/firewall; SSH password auth left ON)"
[ -x "$BASE/harden.sh" ] && "$BASE/harden.sh" --skip-ssh || echo "  (harden.sh missing/failed — skipping)"

echo "linkstar-firstboot complete; disabling service"
systemctl disable linkstar-firstboot.service 2>/dev/null || true
