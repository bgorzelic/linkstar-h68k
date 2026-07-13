#!/usr/bin/env bash
#
# casaos.sh — the "casaos" flavor: install CasaOS on top of the Ubuntu base.
#
# CasaOS is a Docker-based personal-cloud / home-server web UI with an app store. This
# runs its official installer (which installs Docker + the CasaOS stack). Run ON a booted
# Ubuntu unit with internet, then snapshot the SD for a casaos release.
#
#   sudo flavors/casaos.sh [--dry-run]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "$SCRIPT_DIR/../scripts/lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
require_root
require_cmd curl

INSTALLER="https://get.casaos.io"
log "installing CasaOS via the official installer ($INSTALLER)"
warn "this runs the vendor install script, which also installs Docker + the CasaOS stack."

if [ "$DRY_RUN" = "1" ]; then
  printf '%s[dry-run]%s would download %s and run it as root\n' "$C_YEL" "$C_RST" "$INSTALLER" >&2
else
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  curl -fsSL "$INSTALLER" -o "$tmp"     # saved so you can inspect it first: less "$tmp"
  bash "$tmp"
fi

ok "CasaOS installed. Open the web UI at http://<device-ip>/ (port 80) to set the admin account."
log "Then snapshot the SD for a casaos release."
warn "harden.sh's firewall denies inbound by default — keep the UI reachable with: harden.sh --allow-port 80"
