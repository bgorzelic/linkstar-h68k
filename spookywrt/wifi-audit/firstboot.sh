#!/bin/sh
# SpookyWrt wifi-audit — first-boot consent gate (uci-defaults).
# Appended after the base first-boot when building `--profile wifi-audit`.
#
# This image ships packet-injection drivers + audit tools. They stay FAIL-CLOSED behind
# a consent gate: nothing offensive runs until the operator records authorization AND a
# regulatory domain. Implements the swarm safety spec (proposals/wifi-audit-variant.md §4).

# ---- audit config defaults (off until consent) ----
touch /etc/config/spookywrt
uci -q get spookywrt.audit >/dev/null 2>&1 || uci -q set spookywrt.audit=audit
uci -q set spookywrt.audit.enabled='0'       # 1 only after spooky-audit-consent
uci -q set spookywrt.audit.scope=''          # authorized scope (logged)
uci -q set spookywrt.audit.consent_ts=''
uci -q set spookywrt.audit.regdom=''         # ISO country — REQUIRED before injection
uci -q commit spookywrt
mkdir -p /etc/spookywrt

# ---- login banner (Audit Edition, with the legal notice) ----
cat > /etc/banner <<'BANNER'
  SpookyWrt · Wi-Fi Audit Edition — AUTHORIZED USE ONLY
  Packet-injection drivers + wireless audit tools are present but DISABLED.
  Enable only for networks you own or hold written authorization to test:
      spooky-audit-consent      # records scope + regdom, unlocks tooling
  Offensive tools are fail-closed behind:  spooky-audit <tool> [args]
BANNER

# ---- the fail-closed wrapper: audit tools are only reachable through this ----
cat > /usr/bin/spooky-audit <<'WRAP'
#!/bin/sh
# spooky-audit — gate for offensive wireless tooling. Fails closed.
set -u
enabled=$(uci -q get spookywrt.audit.enabled)
regdom=$(uci -q get spookywrt.audit.regdom)
scope=$(uci -q get spookywrt.audit.scope)
if [ "$enabled" != "1" ]; then
  echo "spooky-audit: DISABLED. Run 'spooky-audit-consent' first (authorized use only)." >&2
  exit 1
fi
[ -z "$1" ] && { echo "usage: spooky-audit <tool> [args...]   (aircrack-ng hcxdumptool reaver horst iw ...)"; exit 2; }
# Injection needs a regulatory domain set, or the radio silently no-IRs / TXes out of spec.
if [ -z "$regdom" ]; then
  echo "spooky-audit: no regdom set. Run: uci set spookywrt.audit.regdom=<ISO>; uci commit; iw reg set <ISO>" >&2
  exit 3
fi
iw reg get 2>/dev/null | grep -q "country $regdom" || iw reg set "$regdom" 2>/dev/null
# rfkill preflight — refuse if wireless is soft/hard blocked
if command -v rfkill >/dev/null 2>&1 && rfkill list 2>/dev/null | grep -qi 'blocked: yes'; then
  echo "spooky-audit: a radio is rfkill-blocked — unblock before auditing." >&2; exit 4
fi
tool="$1"; shift
# tamper-evident audit trail: who/what/when/scope
logger -t spooky-audit "run tool=$tool scope=\"$scope\" by=$(id -un) args=\"$*\""
printf '%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$(id -un)" "$tool" "$scope" >> /etc/spookywrt/audit.log
exec "$tool" "$@"
WRAP
chmod 0750 /usr/bin/spooky-audit

# ---- consent recorder: prints the legal notice, captures scope + "I ACCEPT", unlocks ----
cat > /usr/bin/spooky-audit-consent <<'CONSENT'
#!/bin/sh
set -u
cat <<'NOTICE'

  SpookyWrt — Wi-Fi Audit Edition — Authorized Use Only
  This image contains packet-injection drivers and wireless audit tools
  (aircrack-ng, hcxdumptool, reaver). Using them against any network, device,
  or radio spectrum you do not own or hold EXPLICIT WRITTEN AUTHORIZATION to
  test is illegal in most jurisdictions (e.g. US CFAA 18 U.S.C. 1030, UK
  Computer Misuse Act 1990) and may violate radio regulations (FCC Part 15 /
  your local regulator).
  By continuing you attest: (1) you own or hold written authorization for the
  target scope; (2) you accept full legal responsibility; (3) SpookyJuice
  provides this with no warranty and no liability.

NOTICE
printf 'ISO regulatory domain (e.g. US, GB, DE): '; read -r reg
printf 'Authorized target scope (logged): '; read -r scope
printf 'Type exactly  I ACCEPT  to enable audit tooling: '; read -r ok
[ "$ok" = "I ACCEPT" ] || { echo "not accepted — tooling stays disabled."; exit 1; }
[ -n "$reg" ] || { echo "a regulatory domain is required."; exit 1; }
ts=$(date -u +%s)
uci -q set spookywrt.audit.enabled='1'
uci -q set spookywrt.audit.scope="$scope"
uci -q set spookywrt.audit.regdom="$reg"
uci -q set spookywrt.audit.consent_ts="$ts"
uci -q commit spookywrt
iw reg set "$reg" 2>/dev/null
umask 077
printf '{"enabled":true,"scope":"%s","regdom":"%s","consent_ts":%s,"by":"%s"}\n' \
  "$scope" "$reg" "$ts" "$(id -un)" > /etc/spookywrt/audit-consent.json
echo "audit tooling ENABLED for scope: $scope (regdom $reg). Use: spooky-audit <tool>"
CONSENT
chmod 0755 /usr/bin/spooky-audit-consent
