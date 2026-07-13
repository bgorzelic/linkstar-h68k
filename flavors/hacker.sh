#!/usr/bin/env bash
#
# hacker.sh — the "hacker" flavor: a portable security-testing toolkit.
#
# Turns the H68K into a pocket pentest box (Kali-style, on Ubuntu). Installs common
# network/security tooling via apt.
#
# ⚠️  For AUTHORIZED security testing, CTFs, and learning ONLY. You are responsible for
#     using these tools legally and only on systems you own or have permission to test.
#
# Run ON a booted Ubuntu unit with internet; --dry-run supported.
#   sudo flavors/hacker.sh [--dry-run]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "$SCRIPT_DIR/../scripts/lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
require_root
require_cmd apt-get

warn "AUTHORIZED security testing / CTF / education ONLY — use these tools legally."
log "hacker flavor — installing the security toolkit"
export DEBIAN_FRONTEND=noninteractive
run apt-get update

# Curated toolkit (all in Ubuntu main/universe). Grouped by purpose.
TOOLS=(
  nmap masscan tcpdump tshark            # recon / capture
  ncat socat netcat-openbsd              # sockets
  hydra john hashcat                     # credential testing
  aircrack-ng iw wireless-tools          # wireless (needs a supported USB adapter)
  nikto whatweb dirb gobuster sqlmap     # web
  dnsutils whois traceroute mtr-tiny net-tools  # network utils
  git python3-pip build-essential        # build/scripting
)
run apt-get install -y "${TOOLS[@]}" \
  || warn "some tools live in 'universe' — enable it (add-apt-repository universe) or install individually"

ok "hacker flavor applied. Installed: nmap, masscan, tshark, hydra, john, hashcat, aircrack-ng, sqlmap, gobuster, nikto…"
warn "Wi-Fi attacks need a USB adapter with a working driver — the internal MT7921 is dead on the vendor 4.19 kernel (see docs/known-issues.md)."
warn "This flavor widens the attack surface — keep it on a trusted network and behind harden.sh's firewall."
