#!/bin/sh
# SpookyWrt onboarding — first-boot "SpookyWrt-Setup" AP (uci-defaults).
# Appended to the first-boot on every SpookyWrt build.
#
# An UNCONFIGURED box brings up an OPEN Wi-Fi AP named "SpookyWrt-Setup" so you can join
# from a phone/laptop with no ethernet cable, browse to http://192.168.1.1, and configure
# it (LuCI / the SpookyWrt dashboard / `spooky-setup`). Once you set your own Wi-Fi, the
# setup AP is torn down automatically.
#
# Why open: it's a transient, onboarding-only AP that self-disables after setup — the same
# pattern GL.iNet/eero use for headless first-connect. Set a WPA key immediately in the
# wizard; until then, complete setup promptly and nearby only.

SETUP_SSID="SpookyWrt-Setup"

# ---- onboarding state (active until the user completes setup) ----
touch /etc/config/spookywrt
uci -q get spookywrt.setup >/dev/null 2>&1 || uci -q set spookywrt.setup=setup
uci -q set spookywrt.setup.active='1'          # 0 once the user configures Wi-Fi
uci -q set spookywrt.setup.ssid="$SETUP_SSID"
uci -q commit spookywrt

# ---- deferred onboarding service: the mt7921 driver loads AFTER uci-defaults, so a
#      one-shot boot service waits for the PHY, then raises the open setup AP if still
#      unconfigured. Re-checks each boot; does nothing once setup.active=0. ----
cat > /etc/init.d/spooky-setup-ap <<SVC
#!/bin/sh /etc/rc.common
START=98
SETUP_SSID="$SETUP_SSID"
SVC
cat >> /etc/init.d/spooky-setup-ap <<'SVC'
boot() {
  [ "$(uci -q get spookywrt.setup.active)" = "1" ] || exit 0
  i=0; while [ ! -e /sys/class/ieee80211/phy0 ] && [ "$i" -lt 20 ]; do sleep 1; i=$((i+1)); done
  [ -e /sys/class/ieee80211/phy0 ] || exit 0
  [ -z "$(uci -q get wireless.radio0)" ] && wifi config
  # open onboarding AP on the default radio interface, bridged to LAN (reaches 192.168.1.1)
  uci -q set wireless.radio0.disabled='0'
  uci -q set wireless.radio0.country='US'
  uci -q set wireless.default_radio0.ssid="$SETUP_SSID"
  uci -q set wireless.default_radio0.encryption='none'
  uci -q set wireless.default_radio0.network='lan'
  uci -q commit wireless
  wifi reload
  logger -t spooky-setup-ap "onboarding AP '$SETUP_SSID' is up — join it and open http://192.168.1.1"
}
SVC
chmod +x /etc/init.d/spooky-setup-ap
/etc/init.d/spooky-setup-ap enable 2>/dev/null

# ---- teardown helper: the wizard / WebUI calls this after the user sets real Wi-Fi ----
cat > /usr/bin/spooky-setup-done <<'DONE'
#!/bin/sh
# Mark onboarding complete: the setup AP won't come back on next boot.
uci -q set spookywrt.setup.active='0'; uci -q commit spookywrt
/etc/init.d/spooky-setup-ap disable 2>/dev/null
echo "onboarding complete — SpookyWrt-Setup AP disabled."
DONE
chmod 0755 /usr/bin/spooky-setup-done

# reflect the onboarding hint in the console banner
[ -f /etc/banner ] && printf '\n  First time? Join Wi-Fi "%s" (open) and open http://192.168.1.1\n' "$SETUP_SSID" >> /etc/banner
