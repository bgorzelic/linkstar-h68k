#!/usr/bin/env bash
#
# server.sh — the "server" flavor: strip the LXQt desktop for a headless image.
#
# Run ON a booted base Ubuntu unit, then snapshot the SD to produce a server release
# image (see flavors/README.md). Idempotent; supports --dry-run.
#
#   sudo flavors/server.sh [--dry-run]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "$SCRIPT_DIR/../scripts/lib/common.sh"

# shellcheck disable=SC2034  # DRY_RUN is consumed by run() in ../scripts/lib/common.sh
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
require_root
require_cmd apt-get systemctl

log "server flavor — removing the desktop environment and booting to console"

# Desktop environment + display managers. Globs are quoted so apt (not the shell)
# expands them; anything already absent is tolerated.
DESKTOP=(
  'lxqt*' 'lubuntu-desktop' 'lubuntu-*' 'lxdm' 'lightdm*' 'sddm' 'openbox*'
)
export DEBIAN_FRONTEND=noninteractive
run apt-get purge -y "${DESKTOP[@]}" || warn "some desktop packages were already absent"

log "boot to a console instead of a graphical login"
run systemctl set-default multi-user.target

log "removing now-orphaned X / desktop dependencies"
run apt-get autoremove --purge -y
run apt-get clean

ok "server flavor applied. Reboot to verify it comes up headless, then snapshot the SD."
log "Reminder: also run scripts/harden.sh + first-setup.sh before releasing the image."
