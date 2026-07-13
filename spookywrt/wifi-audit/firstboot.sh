#!/bin/sh
# SpookyWrt wifi-audit — first-boot consent + audit gate (uci-defaults).
# Appended after the base first-boot when building `--profile wifi-audit`.
#
# This image ships packet-injection drivers + audit tools. This gate provides
# CONSENT, ATTESTATION, REGDOM enforcement, and a LOGGING trail — plus it relocates
# the offensive binaries off the default $PATH so they aren't reachable by accident.
#
# HONESTY NOTE: OpenWRT is single-user (root). This is NOT an unbypassable jail — a
# determined root user can still exec a relocated binary by full path. What it DOES
# guarantee: the tools aren't on $PATH by default, use requires recorded consent + a
# regulatory domain, and every gated invocation is logged. Treat it as informed-consent
# + audit, not as a technical access control.

AUDIT_DIR=/opt/spooky-tools/bin
# Offensive binaries relocated off $PATH (injection/capture/crack). Passive tools
# (iw, iwinfo, tcpdump) stay on $PATH — they're generally useful and low-risk.
OFFENSIVE="aircrack-ng aireplay-ng airodump-ng airmon-ng airbase-ng besside-ng \
hcxdumptool hcxpcapngtool reaver wash mdk4"

# ---- audit config defaults (disabled until consent) ----
touch /etc/config/spookywrt
uci -q get spookywrt.audit >/dev/null 2>&1 || uci -q set spookywrt.audit=audit
uci -q set spookywrt.audit.enabled='0'
uci -q set spookywrt.audit.scope=''
uci -q set spookywrt.audit.consent_ts=''
uci -q set spookywrt.audit.regdom=''
uci -q commit spookywrt
mkdir -p /etc/spookywrt && chmod 700 /etc/spookywrt   # H-3: not world-readable

# ---- BOOT SAFETY: services-off by default (the variant hung on first boot) ----
# The best-of-flavor packages install boot-time daemons that block/stall a FRESH image
# waiting on config or connectivity — verified: the wifi-audit variant hung on first boot
# until these were disabled (flagship on the same card booted fine). They're INSTALLED but
# NOT auto-started; enable deliberately once configured (e.g. `/etc/init.d/mwan3 enable`).
# watchcat is the most dangerous (a misconfigured watchdog can reboot-loop the box).
for svc in mwan3 travelmate dawn collectd luci_statistics nlbwmon ddns https-dns-proxy watchcat; do
  [ -x "/etc/init.d/$svc" ] && /etc/init.d/$svc disable 2>/dev/null
done

# ---- relocate offensive tools off $PATH (real friction) ----
mkdir -p "$AUDIT_DIR" && chmod 755 "$AUDIT_DIR"
for t in $OFFENSIVE; do
  [ -x "/usr/bin/$t" ] && mv "/usr/bin/$t" "$AUDIT_DIR/$t"
done

# ---- login banner ----
cat > /etc/banner <<'BANNER'
  SpookyWrt · Wi-Fi Audit Edition — AUTHORIZED USE ONLY
  Packet-injection + audit tools are present, moved off $PATH, and DISABLED.
  Enable (records scope + regdom, all use logged):   spooky-audit-consent
  Then run tools through:                            spooky-audit <tool> [args]
  This is a consent + audit layer, not a jail — use only on networks you own
  or hold written authorization to test.
BANNER

# ---- the audit wrapper: allowlisted, regdom-verified, logged ----
cat > /usr/bin/spooky-audit <<WRAP
#!/bin/sh
# spooky-audit — consent/regdom-gated launcher for offensive wireless tooling.
set -u
AUDIT_DIR="$AUDIT_DIR"
WRAP
cat >> /usr/bin/spooky-audit <<'WRAP'
enabled=$(uci -q get spookywrt.audit.enabled)
regdom=$(uci -q get spookywrt.audit.regdom)
scope=$(uci -q get spookywrt.audit.scope)
[ "$enabled" = "1" ] || { echo "spooky-audit: DISABLED — run 'spooky-audit-consent' first." >&2; exit 1; }
[ $# -eq 0 ] && { echo "usage: spooky-audit <tool> [args...]" >&2; exit 2; }   # W1: no bare $1 under set -u
# C-3: allowlist — never exec arbitrary commands
tool="$1"; shift
case "$tool" in
  aircrack-ng|aireplay-ng|airodump-ng|airmon-ng|airbase-ng|besside-ng|hcxdumptool|hcxpcapngtool|reaver|wash|mdk4|horst) ;;
  *) echo "spooky-audit: '$tool' is not an allowlisted audit tool." >&2; exit 5 ;;
esac
[ -n "$regdom" ] || { echo "spooky-audit: no regdom recorded (re-run spooky-audit-consent)." >&2; exit 3; }
# M-1: enforce + VERIFY the regulatory domain (don't swallow failure)
iw reg set "$regdom" 2>/dev/null
iw reg get 2>/dev/null | grep -q "country $regdom" || { echo "spooky-audit: kernel did not accept regdom '$regdom'." >&2; exit 5; }
# rfkill preflight
if command -v rfkill >/dev/null 2>&1 && rfkill list 2>/dev/null | grep -qi 'blocked: yes'; then
  echo "spooky-audit: a radio is rfkill-blocked — unblock before auditing." >&2; exit 4
fi
# M-3: sanitize scope (strip tab/newline) before it reaches the logs
scope_safe=$(printf '%s' "$scope" | tr -d '\t\n\r')
logger -t spooky-audit "run tool=$tool by=$(id -un) scope=$scope_safe"
( umask 077; printf '%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$(id -un)" "$tool" "$scope_safe" >> /etc/spookywrt/audit.log )
# resolve from the relocated dir (tools are off $PATH)
bin="$AUDIT_DIR/$tool"; [ -x "$bin" ] || bin="$tool"
exec "$bin" "$@"
WRAP
chmod 0755 /usr/bin/spooky-audit   # readable/execable; enforcement is by consent state, not file mode

# ---- consent recorder (root-only; explicit re-consent) ----
cat > /usr/bin/spooky-audit-consent <<'CONSENT'
#!/bin/sh
set -u
# M-2: don't silently overwrite a recorded scope
if [ "$(uci -q get spookywrt.audit.enabled)" = "1" ] && [ "${1:-}" != "--re-consent" ]; then
  echo "audit already enabled for scope: $(uci -q get spookywrt.audit.scope)"
  echo "to change scope, re-run with:  spooky-audit-consent --re-consent"; exit 0
fi
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
# M-4/W2: JSON-escape backslash then double-quote in the recorded values
esc(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
( umask 077
  printf '{"enabled":true,"scope":"%s","regdom":"%s","consent_ts":%s,"by":"%s"}\n' \
    "$(esc "$scope")" "$(esc "$reg")" "$ts" "$(esc "$(id -un)")" > /etc/spookywrt/audit-consent.json )
echo "audit tooling ENABLED for scope: $scope (regdom $reg). Use: spooky-audit <tool>"
CONSENT
chmod 0700 /usr/bin/spooky-audit-consent   # M-2: root-only
