#!/usr/bin/env bash
#
# desktop.sh — the "desktop" flavor: ensure the LXQt desktop + graphical boot.
#
# The vendor base image already ships LXQt, so on a stock unit this is mostly a no-op
# (it just guarantees the graphical target). It's here for symmetry and to restore the
# desktop on a unit that had the server flavor applied. Run ON the device; --dry-run ok.
#
#   sudo flavors/desktop.sh [--dry-run]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "$SCRIPT_DIR/../scripts/lib/common.sh"

[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
require_root
require_cmd apt-get systemctl

export DEBIAN_FRONTEND=noninteractive
if dpkg -l lxqt-core >/dev/null 2>&1; then
  log "LXQt already installed"
else
  log "installing the LXQt desktop"
  run apt-get update
  run apt-get install -y lubuntu-desktop
fi

log "boot to the graphical login"
run systemctl set-default graphical.target

ok "desktop flavor applied."
