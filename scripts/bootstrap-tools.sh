#!/usr/bin/env bash
#
# bootstrap-tools.sh — fetch & build the Rockchip tools the SD-boot pipeline needs,
# pinned for reproducibility. Installs into ./tools by default.
#
# Produces:
#   tools/rkdeveloptool/rkdeveloptool   unpacks MiniLoaderAll; eMMC flashing
#   tools/rkbin/                        provides mkimage for the RKNS idbloader
#
# Then run the pipeline with those tools:
#   export RKDEVELOPTOOL="$PWD/tools/rkdeveloptool/rkdeveloptool"
#   export RKBIN="$PWD/tools/rkbin"
#   scripts/build-release.sh <vendor.img> ./work [/dev/diskN]
#
# Prereqs (to BUILD rkdeveloptool):
#   macOS:  brew install automake autoconf libtool libusb pkg-config
#   Debian: sudo apt-get install -y build-essential autoconf automake libtool \
#           libusb-1.0-0-dev pkg-config
# On macOS, mkimage runs from rkbin via Docker (linux/amd64), so Docker is required there.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

TOOLS_DIR="${TOOLS_DIR:-$PWD/tools}"

# Pin these to exact commits for byte-for-byte reproducibility (override via env).
# Defaults track upstream master; PIN THEM before cutting an official release.
RKDEVELOPTOOL_REPO="${RKDEVELOPTOOL_REPO:-https://github.com/rockchip-linux/rkdeveloptool}"
RKDEVELOPTOOL_REF="${RKDEVELOPTOOL_REF:-master}"
RKBIN_REPO="${RKBIN_REPO:-https://github.com/rockchip-linux/rkbin}"
RKBIN_REF="${RKBIN_REF:-master}"

require_cmd git
mkdir -p "$TOOLS_DIR"

# clone_at <repo> <ref> <dest> — clone (or update) and check out an exact ref.
clone_at() {
  local repo="$1" ref="$2" dest="$3"
  if [ -d "$dest/.git" ]; then
    log "updating $(basename "$dest")"
    git -C "$dest" fetch --all --tags --quiet || warn "fetch failed for $dest"
  else
    log "cloning $(basename "$dest") ($repo)"
    git clone --quiet "$repo" "$dest"
  fi
  git -C "$dest" checkout --quiet "$ref" || die "could not check out '$ref' in $dest — pin a valid commit/branch/tag"
  log "  $(basename "$dest") @ $(git -C "$dest" rev-parse --short HEAD)"
}

clone_at "$RKBIN_REPO"          "$RKBIN_REF"          "$TOOLS_DIR/rkbin"
clone_at "$RKDEVELOPTOOL_REPO"  "$RKDEVELOPTOOL_REF"  "$TOOLS_DIR/rkdeveloptool"

# Build rkdeveloptool if not already built.
if [ -x "$TOOLS_DIR/rkdeveloptool/rkdeveloptool" ]; then
  ok "rkdeveloptool already built"
else
  log "building rkdeveloptool (needs autotools + libusb + pkg-config)…"
  # clang on macOS needs the extra flags for this codebase.
  (
    cd "$TOOLS_DIR/rkdeveloptool"
    autoreconf -i
    ./configure
    make CXXFLAGS="-g -O2 -Wno-vla-cxx-extension -Wno-error"
  ) || die "rkdeveloptool build failed — install the prereqs listed at the top of this script"
  ok "built $TOOLS_DIR/rkdeveloptool/rkdeveloptool"
fi

cat >&2 <<EOF

Tools ready under: $TOOLS_DIR
Next:
  export RKDEVELOPTOOL="$TOOLS_DIR/rkdeveloptool/rkdeveloptool"
  export RKBIN="$TOOLS_DIR/rkbin"
  scripts/build-release.sh <vendor.img> ./work [/dev/diskN]
EOF
