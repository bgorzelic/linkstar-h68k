#!/usr/bin/env bash
#
# harden.sh — lock down a stock LinkStar H68K.
#
# The vendor Ubuntu image ships insecure-by-default. This script fixes the three
# problems confirmed on real hardware:
#   1. adbd listening UNAUTHENTICATED on 0.0.0.0:5555  (network ADB = root shell)
#   2. vsftpd cleartext FTP on :21
#   3. no firewall at all (iptables all-ACCEPT)
# …and optionally installs an SSH key and disables SSH password auth.
#
# Runs ON the device as root:
#   sudo ./harden.sh --pubkey-file /path/to/id_ed25519.pub
#   sudo ./harden.sh --dry-run                       # show what it would do
#   sudo ./harden.sh --skip-firewall --skip-ssh      # only disable adb + ftp
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: sudo harden.sh [options]
  --pubkey "<ssh-ed25519 AAAA...>"   SSH public key (literal string) to install
  --pubkey-file <path>               ...or read the public key from a file
  --user <name>                      account to install the key for (default: $SUDO_USER)
  --allow-port <n>                   extra inbound port to allow through ufw (repeatable)
  --skip-adb                         don't touch adbd
  --skip-ftp                         don't touch vsftpd
  --skip-firewall                    don't install/enable ufw
  --skip-ssh                         don't install key / change sshd
  --dry-run                          print actions without executing
  -h, --help                         this help

SAFETY: password auth is only disabled if a usable SSH key is present, to avoid
locking yourself out.
EOF
}

PUBKEY=""; PUBKEY_FILE=""; TARGET_USER="${SUDO_USER:-}"
SKIP_ADB=0; SKIP_FTP=0; SKIP_FW=0; SKIP_SSH=0
declare -a ALLOW_PORTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pubkey)       PUBKEY="${2:-}"; shift 2 ;;
    --pubkey-file)  PUBKEY_FILE="${2:-}"; shift 2 ;;
    --user)         TARGET_USER="${2:-}"; shift 2 ;;
    --allow-port)   ALLOW_PORTS+=("${2:-}"); shift 2 ;;
    --skip-adb)     SKIP_ADB=1; shift ;;
    --skip-ftp)     SKIP_FTP=1; shift ;;
    --skip-firewall) SKIP_FW=1; shift ;;
    --skip-ssh)     SKIP_SSH=1; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "unknown option: $1 (try --help)" ;;
  esac
done

require_root

# write_file <path> : write stdin to a file, honoring DRY_RUN
write_file() {
  local path="$1"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '%s[dry-run]%s write %s\n' "$C_YEL" "$C_RST" "$path"; cat >/dev/null
  else
    cat > "$path"
  fi
}

port_listening() { ss -tlnH "( sport = :$1 )" 2>/dev/null | grep -q .; }

# ---------------------------------------------------------------------------
# 1. adbd — unauthenticated network root shell on :5555
# ---------------------------------------------------------------------------
if [[ "$SKIP_ADB" == "0" ]]; then
  log "disabling adbd (network ADB on :5555)…"
  [[ -x /etc/init.d/adbd.sh ]] && run /etc/init.d/adbd.sh stop || true
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^adbd'; then
    run systemctl disable --now adbd 2>/dev/null || true
    run systemctl mask adbd 2>/dev/null || true
  fi
  # SysV fallback so it doesn't come back on boot
  command -v update-rc.d >/dev/null 2>&1 && run update-rc.d -f adbd.sh remove 2>/dev/null || true
  if [[ "$DRY_RUN" == "0" ]] && port_listening 5555; then
    warn "port 5555 is STILL listening — adbd may be started by another init hook; check /etc/init.d and rc.local"
  else
    ok "adbd disabled"
  fi
else
  log "skipping adb (per --skip-adb)"
fi

# ---------------------------------------------------------------------------
# 2. vsftpd — cleartext FTP on :21
# ---------------------------------------------------------------------------
if [[ "$SKIP_FTP" == "0" ]]; then
  log "disabling vsftpd (cleartext FTP on :21)…"
  if systemctl list-unit-files 2>/dev/null | grep -q '^vsftpd'; then
    run systemctl disable --now vsftpd 2>/dev/null || true
    ok "vsftpd disabled (use SFTP over SSH instead)"
  else
    log "vsftpd unit not present — nothing to do"
  fi
else
  log "skipping ftp (per --skip-ftp)"
fi

# ---------------------------------------------------------------------------
# 3. Firewall — default-deny inbound, allow SSH (+ extras)
# ---------------------------------------------------------------------------
if [[ "$SKIP_FW" == "0" ]]; then
  log "configuring firewall (ufw)…"
  if ! command -v ufw >/dev/null 2>&1; then
    log "installing ufw…"
    run apt-get update -qq || warn "apt-get update failed (offline?) — ufw may not install"
    run apt-get install -y ufw || die "could not install ufw; re-run with --skip-firewall or fix apt"
  fi
  run ufw default deny incoming
  run ufw default allow outgoing
  run ufw allow 22/tcp
  for p in "${ALLOW_PORTS[@]}"; do
    [[ -n "$p" ]] && run ufw allow "${p}/tcp"
  done
  run ufw --force enable
  ok "firewall enabled (inbound: SSH${ALLOW_PORTS[*]:+ + ${ALLOW_PORTS[*]}})"
else
  log "skipping firewall (per --skip-firewall)"
fi

# ---------------------------------------------------------------------------
# 4. SSH — install key, then (only if a key exists) disable password auth
# ---------------------------------------------------------------------------
if [[ "$SKIP_SSH" == "0" ]]; then
  # Resolve the public key
  if [[ -z "$PUBKEY" && -n "$PUBKEY_FILE" ]]; then
    [[ -f "$PUBKEY_FILE" ]] || die "pubkey file not found: $PUBKEY_FILE"
    PUBKEY="$(cat "$PUBKEY_FILE")"
  fi

  key_installed=0
  if [[ -n "$PUBKEY" ]]; then
    [[ -n "$TARGET_USER" ]] || die "cannot install key: no --user given and \$SUDO_USER is empty"
    user_home="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    [[ -n "$user_home" ]] || die "user '$TARGET_USER' not found"
    log "installing SSH key for $TARGET_USER ($user_home/.ssh/authorized_keys)…"
    ak="$user_home/.ssh/authorized_keys"
    if [[ "$DRY_RUN" == "1" ]]; then
      printf '%s[dry-run]%s append key to %s\n' "$C_YEL" "$C_RST" "$ak"
      key_installed=1
    else
      install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$user_home/.ssh"
      touch "$ak"
      if grep -qF "$PUBKEY" "$ak"; then
        log "key already present — not duplicating"
      else
        printf '%s\n' "$PUBKEY" >> "$ak"
      fi
      chmod 600 "$ak"; chown "$TARGET_USER:$TARGET_USER" "$ak"
      key_installed=1
      ok "SSH key installed"
    fi
  else
    # No key passed — is there already one for the target user?
    if [[ -n "$TARGET_USER" ]]; then
      uh="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
      [[ -s "$uh/.ssh/authorized_keys" ]] && key_installed=1
    fi
  fi

  if [[ "$key_installed" == "1" ]]; then
    log "hardening sshd (disable password auth, key-only)…"
    grep -qE '^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config 2>/dev/null \
      || run bash -c 'printf "\nInclude /etc/ssh/sshd_config.d/*.conf\n" >> /etc/ssh/sshd_config'
    run mkdir -p /etc/ssh/sshd_config.d
    write_file /etc/ssh/sshd_config.d/99-linkstar-hardening.conf <<'EOF'
# Managed by linkstar-h68k/scripts/harden.sh
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
ChallengeResponseAuthentication no
EOF
    if run sshd -t; then
      run systemctl reload ssh 2>/dev/null || run systemctl reload sshd 2>/dev/null || true
      ok "sshd hardened — password login disabled (key required)"
    else
      warn "sshd -t failed; NOT reloading. Review /etc/ssh/sshd_config.d/99-linkstar-hardening.conf"
    fi
  else
    warn "no SSH key installed or present — leaving password auth ON to avoid lockout."
    warn "Re-run with --pubkey-file <your_key.pub> to enable key-only login."
  fi
else
  log "skipping ssh (per --skip-ssh)"
fi

echo
ok "harden.sh complete.${DRY_RUN:+ (dry-run — nothing was changed)}"
[[ "$SKIP_SSH" == "0" ]] && log "Reminder: rotate the account password if it was ever shared in plaintext."
