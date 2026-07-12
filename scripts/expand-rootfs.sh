#!/usr/bin/env bash
#
# expand-rootfs.sh — grow the root filesystem to fill its card/eMMC.
#
# The stock image auto-expands on first boot, but if that ever fails (or you
# `dd` the image onto a bigger card yourself), the rootfs can be stuck at ~6 GB
# on a much larger partition. This grows the partition (if there's free space
# after it) and then the ext4 filesystem. ext4 grows ONLINE, so no unmount/reboot.
#
# Runs ON the device as root:  sudo ./expand-rootfs.sh [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# shellcheck disable=SC2034  # DRY_RUN is consumed by run() in lib/common.sh
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1
require_root
require_cmd findmnt
require_cmd resize2fs

root_src="$(findmnt -no SOURCE /)"
root_fs="$(findmnt -no FSTYPE /)"
log "root device: $root_src  (fstype: $root_fs)"

if [[ "$root_fs" != "ext4" && "$root_fs" != "ext3" && "$root_fs" != "ext2" ]]; then
  die "root is $root_fs, not ext*. resize2fs can't grow this; nothing done."
fi

# Split /dev/mmcblk1p8 -> disk=/dev/mmcblk1 partnum=8  (mmcblk/nvme use 'p' separator)
if [[ "$root_src" =~ ^(/dev/(mmcblk|nvme)[0-9]+)p([0-9]+)$ ]]; then
  disk="${BASH_REMATCH[1]}"; partnum="${BASH_REMATCH[3]}"
elif [[ "$root_src" =~ ^(/dev/[a-z]+)([0-9]+)$ ]]; then
  disk="${BASH_REMATCH[1]}"; partnum="${BASH_REMATCH[2]}"
else
  warn "couldn't parse disk/partition from '$root_src'; skipping partition grow, trying fs grow only."
  disk=""; partnum=""
fi

# 1) Grow the partition to fill free space after it, if growpart exists and there's room.
if [[ -n "$disk" ]]; then
  if command -v growpart >/dev/null 2>&1; then
    log "attempting to grow partition $partnum on $disk (if free space follows it)…"
    # growpart returns 1 and prints NOCHANGE when the partition is already maxed — that's fine.
    if run growpart "$disk" "$partnum"; then
      ok "partition grown"
    else
      log "partition already fills the disk (or no free space) — continuing"
    fi
  else
    warn "growpart not installed (package: cloud-guest-utils). Skipping partition resize."
    warn "If the PARTITION itself is smaller than the card, install it and re-run:"
    warn "  sudo apt-get install -y cloud-guest-utils"
  fi
fi

# 2) Grow the ext4 filesystem to fill its partition (online).
log "growing $root_fs on $root_src to fill its partition…"
run resize2fs "$root_src"

echo
log "result:"
df -h /
ok "expand-rootfs complete."
