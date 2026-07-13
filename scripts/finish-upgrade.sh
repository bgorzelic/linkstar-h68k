#!/bin/bash
#
# finish-upgrade.sh — one-shot self-repair for an interrupted Ubuntu 24.04 upgrade.
#
# Pair with a systemd oneshot (WantedBy=multi-user.target) that runs this on next boot.
# Injectable offline via debugfs (see docs/offline-sd-repair-debugfs.md). Needs NO network:
# dpkg --configure -a configures the already-downloaded packages. Self-removes and reboots.
#
# The systemd unit (write to /etc/systemd/system/finish-upgrade.service):
#   [Unit]
#   Description=Auto-finish interrupted Ubuntu 24.04 upgrade
#   After=basic.target
#   [Service]
#   Type=oneshot
#   ExecStart=/bin/bash /etc/finish-upgrade.sh
#   TimeoutStartSec=3600
#   [Install]
#   WantedBy=multi-user.target
exec >>/var/log/finish-upgrade.log 2>&1
echo "=== finish-upgrade started $(date) ==="
export DEBIAN_FRONTEND=noninteractive

# 1. purge the firefox snap-transition package that aborts the 24.04 upgrade
dpkg --purge --force-all firefox firefox-locale-en 2>/dev/null || true

# 2. configure the already-unpacked packages (no network required)
dpkg --configure -a || true
apt-get -f -y install 2>/dev/null || true

# 3. re-assert single-stack networking (name-independent; survives eth0->end0 rename)
rm -f /etc/systemd/system/multi-user.target.wants/NetworkManager.service
ln -sf /dev/null /etc/systemd/system/NetworkManager.service
mkdir -p /etc/systemd/network
cat >/etc/systemd/network/05-dhcp-all.network <<'EOF'
[Match]
Name=en* eth* end*
[Network]
DHCP=ipv4
[Link]
RequiredForOnline=no
EOF
mkdir -p /etc/systemd/system/multi-user.target.wants /etc/systemd/system/sockets.target.wants
ln -sf /lib/systemd/system/systemd-networkd.service /etc/systemd/system/multi-user.target.wants/systemd-networkd.service
ln -sf /lib/systemd/system/systemd-networkd.socket  /etc/systemd/system/sockets.target.wants/systemd-networkd.socket

# 4. fix /etc/hosts (dpkg postinsts need localhost to resolve)
grep -q "127.0.0.1 .*localhost" /etc/hosts || echo "127.0.0.1 localhost.localdomain localhost" >>/etc/hosts

# 5. keep auto-updaters from re-triggering
systemctl mask unattended-upgrades apt-daily.service apt-daily-upgrade.service \
                apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

# 6. self-remove and reboot clean
rm -f /etc/systemd/system/multi-user.target.wants/finish-upgrade.service \
      /etc/systemd/system/finish-upgrade.service /etc/finish-upgrade.sh
echo "=== finish-upgrade done $(date); rebooting ==="
sync
systemctl reboot
