#!/usr/bin/env bash
# Shared helpers for the linkstar-h68k toolkit. Source, don't execute.
# shellcheck shell=bash
#
# Merged from the workstation tooling (discover/harden/first-setup/expand-rootfs)
# and the SD-boot toolchain (unpack-rkfw/build-idbloader/build-sd-image/fix-networking).

# Colors, disabled when stderr isn't a terminal. Logs go to stderr so stdout
# stays clean for piped data (partition tables, scan output, etc.).
if [ -t 2 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'; C_BLU=$'\033[0;36m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

log()  { printf '%s[*]%s %s\n' "$C_BLU" "$C_RST" "$*" >&2; }
ok()   { printf '%s[+]%s %s\n' "$C_GRN" "$C_RST" "$*" >&2; }
warn() { printf '%s[!]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[x]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
die()  { err "$*"; exit 1; }

# DRY_RUN=1 => run() prints the command instead of executing it.
DRY_RUN="${DRY_RUN:-0}"
run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s[dry-run]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2
  else
    "$@"
  fi
}

# require_cmd <cmd> [<cmd> ...] — fail fast on any missing dependency.
require_cmd() {
  local miss=0 c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || { warn "missing required command: $c"; miss=1; }
  done
  [ "$miss" -eq 0 ] || die "install the missing command(s) above and retry"
}

# require_root — abort unless running as root (device-side scripts).
require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    die "this must run as root on the device (use: sudo $0 ...)"
  fi
}

# confirm <prompt> — 0 on an explicit yes. ASSUME_YES=1 auto-confirms (automation).
confirm() {
  [ "${ASSUME_YES:-0}" = "1" ] && return 0
  local reply
  printf '%s[?]%s %s [y/N] ' "$C_YEL" "$C_RST" "$*" >&2
  read -r reply
  [ "$reply" = "y" ] || [ "$reply" = "Y" ]
}

# host_os — prints "macos", "linux", or "unknown".
host_os() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)  echo linux ;;
    *)      echo unknown ;;
  esac
}

# cidr_from_ip_mask <ip> <dotted_mask> -> "network/prefix"
# e.g. cidr_from_ip_mask 192.168.4.38 255.255.252.0 -> 192.168.4.0/22
cidr_from_ip_mask() {
  local ip="$1" mask="$2" IFS=.
  # shellcheck disable=SC2086
  set -- $ip;   local i1=$1 i2=$2 i3=$3 i4=$4
  # shellcheck disable=SC2086
  set -- $mask; local m1=$1 m2=$2 m3=$3 m4=$4
  local prefix=0 oct
  for oct in "$m1" "$m2" "$m3" "$m4"; do
    while [ "$oct" -gt 0 ]; do prefix=$(( prefix + (oct & 1) )); oct=$(( oct >> 1 )); done
  done
  printf '%d.%d.%d.%d/%d\n' "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))" "$prefix"
}
