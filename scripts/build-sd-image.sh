#!/usr/bin/env bash
#
# build-sd-image.sh — write a bootable Ubuntu SD for the LinkStar H68K.
#
# Lays the vendor eMMC partition layout (from parameter.txt) onto an SD card so
# the board boots Ubuntu from microSD with NO maskrom and NO Windows. Writes:
# GPT (primary+backup, exact rootfs PARTUUID), the RKNS idbloader at sector 64,
# U-Boot, and every partition image at its parameter.txt offset.
#
# Inputs come from unpack-rkfw.sh (parts dir) and build-idbloader.sh (idbloader).
#
# Requires: dd, sgdisk (native on Linux; via docker on macOS). DESTRUCTIVE.
#
# Usage: build-sd-image.sh <parts-dir> <idbloader.img> <device>
#   device: /dev/diskN on macOS (uses /dev/rdiskN), /dev/sdX on Linux.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

[ $# -eq 3 ] || die "usage: $(basename "$0") <parts-dir> <idbloader.img> <device>"
PARTS="$1"; IDB="$2"; DEV="$3"
[ -d "$PARTS" ] || die "no such parts dir: $PARTS"
[ -f "$IDB" ]   || die "no such idbloader: $IDB"
require_cmd dd

# Fixed layout from the H68K Ubuntu parameter.txt (name start_sector image).
# Empty image => GPT entry only (e.g. backup). rootfs grows to fill the card.
ROOTFS_GUID="614e0000-0000-4b53-8000-1d28000054a9"
# name start end/0 image
LAYOUT="
uboot     16384    24575    uboot.img
misc      24576    32767    misc.img
boot      32768    98303    boot.img
recovery  98304    163839   recovery.img
backup    163840   229375   -
oem       229376   491519   oem.img
userdata  491520   2588671  userdata.img
rootfs    2588672  0        rootfs.img
"

os="$(host_os)"
if [ "$os" = macos ]; then
  rawdev="${DEV/\/dev\/disk//dev/rdisk}"
  secs="$(diskutil info "$DEV" | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1/512}')"
  unmount() { diskutil unmountDisk "$DEV"; }
else
  rawdev="$DEV"
  secs="$(blockdev --getsz "$DEV")"
  unmount() { true; }
fi
[ -n "$secs" ] && [ "$secs" -gt 0 ] 2>/dev/null || die "could not determine size of $DEV"
log "target $DEV ($rawdev), $secs sectors"

warn "This ERASES $DEV completely."
confirm "Proceed writing Ubuntu to $DEV?" || die "aborted"
unmount

# --- build GPT (primary + backup) sized to this device -----------------------
gptwork="$(mktemp -d)"; trap 'rm -rf "$gptwork"' EXIT
build_gpt() {
  # writes gpt_primary.bin + gpt_backup.bin into $gptwork
  local sg="$1"  # a function name that runs sgdisk against $gptwork/sparse.img
  : >"$gptwork/sparse.img"
  # sparse file of the device size so the backup GPT lands at the true end
  dd if=/dev/zero of="$gptwork/sparse.img" bs=1 count=0 seek=$((secs * 512)) 2>/dev/null
  $sg -Z >/dev/null 2>&1 || true
  local n=1 args=() name start end img
  while read -r name start end img; do
    [ -n "$name" ] || continue
    if [ "$end" = 0 ]; then
      args+=(-n "$n:$start:0")
    else
      args+=(-n "$n:$start:$end")
    fi
    args+=(-c "$n:$name")
    [ "$name" = rootfs ] && args+=(-u "$n:$ROOTFS_GUID")
    n=$((n + 1))
  done <<<"$LAYOUT"
  $sg -a 1 "${args[@]}" >/dev/null
  dd if="$gptwork/sparse.img" of="$gptwork/gpt_primary.bin" bs=512 count=34 status=none
  dd if="$gptwork/sparse.img" of="$gptwork/gpt_backup.bin"  bs=512 skip=$((secs - 33)) count=33 status=none
}
if command -v sgdisk >/dev/null 2>&1; then
  sg() { sgdisk "$@" "$gptwork/sparse.img"; }
else
  require_cmd docker
  sg() { docker run --rm -v "$gptwork:/w" ubuntu:22.04 sh -c 'command -v sgdisk >/dev/null || (apt-get update -qq && apt-get install -y -qq gdisk >/dev/null); sgdisk "$@" /w/sparse.img' _ "$@"; }
fi
log "building GPT"
build_gpt sg

# --- write everything --------------------------------------------------------
w() { sudo dd if="$1" of="$rawdev" bs="$2" seek="$3" conv=notrunc status=none; }
log "writing GPT (primary + backup)"
w "$gptwork/gpt_primary.bin" 512 0
w "$gptwork/gpt_backup.bin"  512 "$((secs - 33))"
log "writing idbloader @ sector 64"
w "$IDB" 512 64
while read -r name start _end img; do
  [ -n "$name" ] && [ "$img" != "-" ] || continue
  [ -f "$PARTS/$img" ] || { warn "skip $name: $PARTS/$img missing"; continue; }
  # 1 MiB-aligned starts use bs=1m for speed; else fall back to 512
  if [ $((start % 2048)) -eq 0 ]; then
    log "writing $name ($img) @ $((start / 2048)) MiB"
    w "$PARTS/$img" 1m "$((start / 2048))"
  else
    log "writing $name ($img) @ sector $start"
    w "$PARTS/$img" 512 "$start"
  fi
done <<<"$LAYOUT"
sync
ok "done. Eject, insert into the H68K TF slot, power on. Then run expand-rootfs after first boot."
