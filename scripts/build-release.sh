#!/usr/bin/env bash
#
# build-release.sh — reproducibly turn a vendor RKFW image into flashable artifacts.
#
# One command chains the whole pipeline: unpack the RKFW → rebuild the RKNS
# idbloader → (optionally) write a bootable SD — then emits SHA256SUMS and a
# release manifest so the output is verifiable and the process is recorded.
# Same inputs + same pinned tools ⇒ same artifacts. This is the entry point for
# cutting a release (see docs/releasing.md).
#
# Usage:
#   build-release.sh <vendor.img> <out-dir> [<device>]
#     <vendor.img>  RKFW vendor image (verify against firmware/SHA256SUMS first)
#     <out-dir>     where partition images + idbloader + manifest are written
#     <device>      optional /dev/diskN (macOS) or /dev/sdX (Linux) to flash;
#                   omit to build verifiable artifacts only.
#
# Tools (see bootstrap-tools.sh): RKDEVELOPTOOL, plus MKIMAGE or RKBIN (+docker).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[ $# -ge 2 ] || die "usage: $(basename "$0") <vendor.img> <out-dir> [<device>]"
IMG="$1"; OUT="$2"; TARGET="${3:-}"
[ -f "$IMG" ] || die "no such vendor image: $IMG"
require_cmd python3 dd shasum
mkdir -p "$OUT"

img_sha="$(shasum -a 256 "$IMG" | awk '{print $1}')"
log "release build"
log "  vendor image : $IMG"
log "  image sha256 : $img_sha"

# 1. unpack RKFW → partition images
"$SCRIPT_DIR/unpack-rkfw.sh" "$IMG" "$OUT/parts"

# 2. rebuild the RKNS idbloader from the unpacked MiniLoaderAll
loader="$OUT/parts/MiniLoaderAll.bin"
[ -f "$loader" ] || die "MiniLoaderAll.bin not found in $OUT/parts — cannot build idbloader"
"$SCRIPT_DIR/build-idbloader.sh" "$loader" "$OUT/idbloader.img"

# 3. optionally flash a card
if [ -n "$TARGET" ]; then
  warn "flashing to $TARGET"
  "$SCRIPT_DIR/build-sd-image.sh" "$OUT/parts" "$OUT/idbloader.img" "$TARGET"
else
  log "no device given — artifacts only (pass /dev/diskN to also flash a card)"
fi

# 4. checksums + a deterministic manifest (no timestamps → reproducible)
( cd "$OUT" && shasum -a 256 idbloader.img parts/* 2>/dev/null | sort -k2 > SHA256SUMS )
idb_sha="$(shasum -a 256 "$OUT/idbloader.img" | awk '{print $1}')"
{
  echo "# LinkStar H68K release build manifest"
  echo "vendor_image_sha256: $img_sha"
  echo "idbloader_sha256:    $idb_sha"
  echo "rkdeveloptool:       ${RKDEVELOPTOOL:-rkdeveloptool}"
  echo "rkbin:               ${RKBIN:-<system mkimage>}"
  echo "partitions:"
  ( cd "$OUT/parts" && ls -1 | sed 's/^/  - /' )
} > "$OUT/release-manifest.txt"

ok "artifacts in $OUT/  (idbloader.img, parts/, SHA256SUMS, release-manifest.txt)"
log "verify anytime with:  ( cd '$OUT' && shasum -a 256 -c SHA256SUMS )"
