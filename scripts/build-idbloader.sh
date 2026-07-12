#!/usr/bin/env bash
#
# build-idbloader.sh — rebuild a bootable sector-64 loader for SD/eMMC boot.
#
# The vendor MiniLoaderAll.bin is the "LDR "-wrapped DOWNLOAD-mode loader used by
# maskrom/RKDevTool. Writing it directly to sector 64 gives a BLACK SCREEN. The
# bootROM wants an "RKNS" rksd image there. This unpacks MiniLoaderAll.bin to get
# this unit's exact DDR init + miniloader, then repacks them with mkimage -T rksd.
#
# Requires:
#   - rkdeveloptool (set RKDEVELOPTOOL=/path, or on PATH)   — unpacks MiniLoaderAll
#   - mkimage with Rockchip support (from the rkbin repo)   — repacks as rksd
#     On macOS the rkbin mkimage is x86-64, so this runs it via
#     `docker run --platform linux/amd64`. Set MKIMAGE=/path to override.
#
# Usage: build-idbloader.sh <MiniLoaderAll.bin> <out/idbloader.img>
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

[ $# -eq 2 ] || die "usage: $(basename "$0") <MiniLoaderAll.bin> <out/idbloader.img>"
LOADER="$1"; OUTIMG="$2"
[ -f "$LOADER" ] || die "no such file: $LOADER"

RKDEVELOPTOOL="${RKDEVELOPTOOL:-rkdeveloptool}"
command -v "$RKDEVELOPTOOL" >/dev/null 2>&1 || die "rkdeveloptool not found (set RKDEVELOPTOOL=/path)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp "$LOADER" "$work/MiniLoaderAll.bin"

log "unpacking MiniLoaderAll.bin (DDR init + miniloader)"
( cd "$work" && "$RKDEVELOPTOOL" unpack MiniLoaderAll.bin >/dev/null )
[ -f "$work/FlashData" ] && [ -f "$work/FlashBoot" ] \
  || die "unpack did not produce FlashData/FlashBoot — wrong rkdeveloptool?"

# mkimage: prefer a native binary, else use the rkbin one under docker on macOS.
run_mkimage() {
  if [ -n "${MKIMAGE:-}" ]; then
    "$MKIMAGE" "$@"
  elif [ "$(host_os)" = linux ] && command -v mkimage >/dev/null 2>&1; then
    mkimage "$@"
  else
    require_cmd docker
    [ -n "${RKBIN:-}" ] || die "set RKBIN=/path/to/rkbin (has tools/mkimage) or MKIMAGE=/path"
    docker run --rm --platform linux/amd64 -v "$RKBIN:/rkbin" -v "$work:/work" \
      -w /work ubuntu:22.04 /rkbin/tools/mkimage "$@"
  fi
}

log "repacking as RKNS rksd idbloader"
run_mkimage -n rk3568 -T rksd -d "$work/FlashData" "$work/idbloader.img" >/dev/null
cat "$work/FlashBoot" >>"$work/idbloader.img"

magic="$(head -c 4 "$work/idbloader.img" | od -An -tx1 | tr -d ' ')"
[ "$magic" = "524b4e53" ] || die "idbloader magic is $magic, expected 524b4e53 (RKNS)"

mkdir -p "$(dirname "$OUTIMG")"
cp "$work/idbloader.img" "$OUTIMG"
ok "wrote $OUTIMG ($(wc -c <"$OUTIMG") bytes, magic RKNS) — write this to SD sector 64"
