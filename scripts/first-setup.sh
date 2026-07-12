#!/usr/bin/env bash
#
# first-setup.sh — first-run housekeeping for a fresh LinkStar H68K.
#
# Sets hostname, timezone + NTP, applies pending updates, and (optionally) creates
# an admin user. Idempotent; safe to re-run. Pair it with harden.sh.
#
# Runs ON the device as root:
#   sudo ./first-setup.sh --hostname h68k-01 --timezone America/New_York --update
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: sudo first-setup.sh [options]
  --hostname <name>       set the system hostname
  --timezone <tz>         set timezone (e.g. America/New_York) and enable NTP
  --update                run apt-get update && full-upgrade (needs free disk + network)
  --create-user <name>    create a sudo-enabled admin user (prompts for password)
  --dry-run               print actions without executing
  -h, --help              this help
EOF
}

HOSTNAME_NEW=""; TZ_NEW=""; DO_UPDATE=0; NEW_USER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hostname)    HOSTNAME_NEW="${2:-}"; shift 2 ;;
    --timezone)    TZ_NEW="${2:-}"; shift 2 ;;
    --update)      DO_UPDATE=1; shift ;;
    --create-user) NEW_USER="${2:-}"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "unknown option: $1 (try --help)" ;;
  esac
done

require_root

if [[ -n "$HOSTNAME_NEW" ]]; then
  log "setting hostname → $HOSTNAME_NEW"
  run hostnamectl set-hostname "$HOSTNAME_NEW"
  ok "hostname set"
fi

if [[ -n "$TZ_NEW" ]]; then
  log "setting timezone → $TZ_NEW and enabling NTP"
  run timedatectl set-timezone "$TZ_NEW"
  run timedatectl set-ntp true
  ok "timezone/NTP set (note: the H68K has no RTC battery — NTP corrects the clock after boot)"
fi

if [[ -n "$NEW_USER" ]]; then
  if id "$NEW_USER" >/dev/null 2>&1; then
    log "user '$NEW_USER' already exists — ensuring sudo group"
  else
    log "creating admin user '$NEW_USER'…"
    run adduser --gecos "" "$NEW_USER"
  fi
  run usermod -aG sudo "$NEW_USER"
  ok "user '$NEW_USER' is a sudoer"
fi

if [[ "$DO_UPDATE" == "1" ]]; then
  log "applying package updates (this can take a while)…"
  run apt-get update
  run env DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade
  run apt-get -y autoremove --purge
  run apt-get clean
  ok "system updated"
  warn "Ubuntu 20.04 left standard support in Apr 2025 — consider Ubuntu Pro (free ESM) or the OpenWRT track."
fi

echo
ok "first-setup complete.${DRY_RUN:+ (dry-run — nothing was changed)}"
