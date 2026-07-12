#!/usr/bin/env bash
#
# discover.sh — find a LinkStar H68K (or any SSH host) on your LAN.
#
# The stock H68K image DROPS ICMP, so a normal `nmap -sn` ping sweep reports it as
# "down". We probe TCP/22 with -Pn (skip host discovery) instead, which finds it
# regardless. The subnet CIDR is auto-detected from your default route — note the
# H68K's own network is often a /22, not a /24, so a /24 scan can miss neighbors.
#
# Runs on your workstation (macOS or Linux). Requires nmap.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: discover.sh [-c CIDR] [-p PORT]
  -c CIDR   subnet to scan (default: auto-detected from the default route)
  -p PORT   TCP port that identifies the host (default: 22 / SSH)
  -h        show this help

Examples:
  ./discover.sh                     # auto-detect subnet, look for SSH
  ./discover.sh -c 192.168.4.0/22   # scan an explicit /22
  ./discover.sh -p 5555             # look for exposed ADB instead
EOF
}

PORT=22
CIDR=""
while getopts ":c:p:h" opt; do
  case "$opt" in
    c) CIDR="$OPTARG" ;;
    p) PORT="$OPTARG" ;;
    h) usage; exit 0 ;;
    :) die "option -$OPTARG requires an argument" ;;
    *) usage; exit 1 ;;
  esac
done

require_cmd nmap

detect_cidr() {
  if [[ "$(uname)" == "Darwin" ]]; then
    local iface ip mask
    iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
    [[ -n "$iface" ]] || return 1
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null)" || return 1
    mask="$(ipconfig getoption "$iface" subnet_mask 2>/dev/null)" || return 1
    [[ -n "$ip" && -n "$mask" ]] || return 1
    cidr_from_ip_mask "$ip" "$mask"
  else
    # Linux: `ip` already reports ip/prefix; nmap treats it as the network to scan.
    local iface
    iface="$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')"
    [[ -n "$iface" ]] || return 1
    ip -o -f inet addr show "$iface" | awk '{print $4; exit}'
  fi
}

if [[ -z "$CIDR" ]]; then
  CIDR="$(detect_cidr)" || die "could not auto-detect subnet; pass one with -c CIDR"
  log "auto-detected subnet: $CIDR"
fi

log "scanning $CIDR for hosts with TCP/$PORT open (this can take a minute on a /22)…"
# -Pn: don't ping first (the H68K blocks ICMP)   --open: only show hosts with the port open
nmap -Pn -p "$PORT" --open -T4 --max-retries 1 "$CIDR"

ok "done. To identify a host's OS via its SSH banner:  nmap -Pn -p 22 -sV <ip>"
