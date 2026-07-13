#!/usr/bin/env bash
#
# ai.sh — the "ai" flavor: an edge-AI toolkit for the RK3568.
#
# Sets up: a Python ML stack (numpy, OpenCV), the Rockchip **RKNN** NPU runtime
# (the 0.8-TOPS NPU, best-effort — the lib must match your kernel/NPU driver), and
# **Ollama** for local LLMs (CPU inference on ARM — use small models).
#
# Run ON a booted Ubuntu unit with internet; --dry-run supported.
#   sudo flavors/ai.sh [--dry-run]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "$SCRIPT_DIR/../scripts/lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
require_root
require_cmd apt-get curl

log "AI flavor — Python ML stack"
export DEBIAN_FRONTEND=noninteractive
run apt-get update
run apt-get install -y python3-pip python3-numpy python3-opencv python3-dev git

log "RKNN NPU runtime (RK356x) — best effort"
RKNN_URL="https://github.com/airockchip/rknn-toolkit2/raw/master/rknpu2/runtime/Linux/librknn_api/aarch64/librknnrt.so"
if [ "$DRY_RUN" = "1" ]; then
  printf '%s[dry-run]%s would fetch librknnrt.so + pip install rknn-toolkit-lite2\n' "$C_YEL" "$C_RST" >&2
elif curl -fsSL "$RKNN_URL" -o /usr/lib/librknnrt.so; then
  ok "installed /usr/lib/librknnrt.so"
  pip3 install --break-system-packages rknn-toolkit-lite2 2>/dev/null \
    || warn "rknn-toolkit-lite2 wheel isn't on PyPI — get it from github.com/airockchip/rknn-toolkit2 (rknn-toolkit-lite2/packages)"
else
  warn "couldn't fetch librknnrt.so — grab the RK356x runtime from github.com/airockchip/rknn-toolkit2"
fi

log "Ollama — local LLMs (CPU)"
if [ "$DRY_RUN" = "1" ]; then
  printf '%s[dry-run]%s would install Ollama via its official script\n' "$C_YEL" "$C_RST" >&2
else
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  curl -fsSL https://ollama.com/install.sh -o "$tmp" && sh "$tmp" || warn "Ollama install failed"
fi

ok "AI flavor applied. Try:  ollama run tinyllama   ·   NPU demos: github.com/airockchip/rknn-toolkit2"
warn "The NPU accelerates RKNN-converted models; general LLMs run on CPU — pick small models (≤3B)."
