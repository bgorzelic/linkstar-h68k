#!/usr/bin/env bash
#
# unpack-rkfw.sh — extract partitions from a Rockchip RKFW vendor image.
#
# The LinkStar H68K vendor Ubuntu ".img" is an RKFW container, NOT a raw disk
# image, so `dd`-ing it to a card produces an unbootable result. This unpacks
# it into the individual partition images + parameter.txt that build-sd-image.sh
# needs. Handles the 32-bit size-field overflow present in >4 GB RKAF payloads
# by reconstructing true 64-bit offsets (afptool cannot — its CRC check fails).
#
# Pure python3 + dd; runs on macOS and Linux with no compiled tools.
#
# Usage: unpack-rkfw.sh <vendor.img> <out-dir>
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

[ $# -eq 2 ] || die "usage: $(basename "$0") <vendor-rkfw.img> <out-dir>"
IMG="$1"; OUT="$2"
[ -f "$IMG" ] || die "no such file: $IMG"
require_cmd python3
mkdir -p "$OUT"

log "parsing RKFW header and extracting partitions from $(basename "$IMG")"
IMG="$IMG" OUT="$OUT" python3 - <<'PY'
import os, struct, sys

img = os.environ["IMG"]; out = os.environ["OUT"]
with open(img, "rb") as f:
    hdr = f.read(128)
if hdr[:4] != b"RKFW":
    sys.exit(f"not an RKFW image (magic={hdr[:4]!r}); nothing to unpack")

image_offset = struct.unpack_from("<I", hdr, 0x21)[0]  # RKAF payload start
with open(img, "rb") as f:
    f.seek(image_offset)
    if f.read(4) != b"RKAF":
        sys.exit("RKAF magic not found at image_offset; unexpected layout")
    # RKAF header: magic(4) length(4) model(0x22) id(0x1e) manufacturer(0x38)
    #              unknown(4) version(4) num_parts(4) parts[16] ...
    f.seek(image_offset)
    rk = f.read(4096)

num_parts = struct.unpack_from("<I", rk, 136)[0]
base, PART = 140, 112
raw = []
for i in range(num_parts):
    o = base + i * PART
    name  = rk[o:o+32].split(b"\0")[0].decode("latin1")
    fname = rk[o+32:o+92].split(b"\0")[0].decode("latin1")
    _nand, pos, _naddr, _pad, size = struct.unpack_from("<IIIII", rk, o+92)
    raw.append([name, fname, pos, size])

# Reconstruct 64-bit offsets: RKAF stores pos/size as uint32, so partitions past
# 4 GB wrap. Partitions are packed sequentially, so chain them: each real start
# is the previous real end; bump by 2**32 until monotonic, same for sizes.
WRAP = 1 << 32
parts, cursor = [], 0
for name, fname, pos, size in raw:
    if fname in ("RESERVED", "SELF") or size == 0:
        continue
    real_pos = pos
    while real_pos < cursor:              # unwrap start
        real_pos += WRAP
    real_size = size
    # unwrap size: extend until it reaches at least the next partition / EOF sanity
    while real_pos + real_size < cursor:
        real_size += WRAP
    parts.append((name, fname, image_offset + real_pos, real_size))
    cursor = real_pos + real_size

CHUNK = 8 << 20
with open(img, "rb") as src:
    for name, fname, abs_off, size in parts:
        base_name = os.path.basename(fname)
        dst = os.path.join(out, base_name)
        src.seek(abs_off)
        remaining = size
        with open(dst, "wb") as d:
            while remaining > 0:
                buf = src.read(min(CHUNK, remaining))
                if not buf:
                    break
                d.write(buf); remaining -= len(buf)
        got = os.path.getsize(dst)
        flag = "ok" if got == size else f"SHORT (got {got})"
        print(f"  {name:<12} -> {base_name:<22} {size:>14,} bytes  {flag}")

# parameter.txt carries the eMMC/SD partition layout; afptool strips 8-byte head
# + 4-byte tail. Emit a cleaned copy too.
pfile = os.path.join(out, "parameter.txt")
if os.path.exists(pfile):
    data = open(pfile, "rb").read()
    if data[:4] == b"PARM":
        open(pfile, "wb").write(data[8:-4])
print("done")
PY

ok "partitions written to $OUT/"
warn "next: build-idbloader.sh (rebuild sector-64 loader), then build-sd-image.sh"
