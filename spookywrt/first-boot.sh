#!/bin/sh
# SpookyWrt "perfect" first-boot provisioning — LinkStar H68K flagship
# Runs once on first boot as a uci-defaults script.

# ---- branded console banner ----
cat > /etc/banner <<'BANNER'
 ┌──────────────────────────────────────────────────────────┐
 │   ███████ ██████   ██████   ██████  ██   ██ ██    ██       │
 │   ██      ██   ██ ██    ██ ██    ██ ██  ██   ██  ██        │
 │   ███████ ██████  ██    ██ ██    ██ █████     ████         │
 │        ██ ██      ██    ██ ██    ██ ██  ██     ██          │
 │   ███████ ██       ██████   ██████  ██   ██    ██          │
 │            W R T   ·   L I N K S T A R   H 6 8 K           │
 └──────────────────────────────────────────────────────────┘
   SpookyWrt (OpenWrt) · RK3568 · dual 2.5G + dual 1G + Wi-Fi
   LuCI: http://192.168.1.1   ·   First time?  run:  spooky-setup
BANNER

# ---- dynamic login status (MOTD) ----
cat > /etc/profile.d/99-spooky-status.sh <<'MOTD'
#!/bin/sh
[ -n "$SPOOKY_SHOWN" ] && return; export SPOOKY_SHOWN=1
. /etc/openwrt_release 2>/dev/null
C='\033[35m'; G='\033[32m'; Y='\033[33m'; D='\033[90m'; R='\033[0m'
wan=$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{print $2}')
lan=$(ip -4 addr show br-lan 2>/dev/null | awk '/inet /{print $2}')
up=$(uptime 2>/dev/null | sed 's/.*up //;s/,.*load/ · load/')
load=$(cut -d' ' -f1-3 /proc/loadavg)
mem=$(free -m 2>/dev/null | awk '/Mem/{printf "%d/%d MB", $3, $2}')
wifi=$(iwinfo 2>/dev/null | awk '/ESSID/{gsub(/"/,"",$4); print $4; exit}')
clients=$(cat /tmp/dhcp.leases 2>/dev/null | wc -l | tr -d ' ')
printf "\n ${C}SpookyWrt${R} ${D}%s${R}\n" "${DISTRIB_DESCRIPTION:-OpenWrt}"
printf " ${D}────────────────────────────────────────────${R}\n"
printf "  ${G}WAN${R}  %s   ${G}LAN${R}  %s\n" "${wan:-down}" "${lan:-—}"
printf "  ${G}WiFi${R} %s   ${G}Clients${R} %s\n" "${wifi:-off}" "${clients:-0}"
printf "  ${G}Load${R} %s   ${G}Mem${R} %s\n" "$load" "$mem"
printf "  ${Y}LuCI${R} http://192.168.1.1   ${D}up %s${R}\n\n" "${up:-?}"
MOTD
chmod +x /etc/profile.d/99-spooky-status.sh

# ---- identity + UI ----
uci -q set system.@system[0].hostname='SpookyWrt'
uci -q set luci.main.mediaurlbase='/luci-static/material'

# ---- NTP (H68K has no RTC — must sync on every boot) ----
uci -q set system.ntp.enabled='1'
uci -q set system.ntp.enable_server='0'

# ---- network topology: eth0 = WAN, eth1+eth2+eth3 = LAN (Brian's spec) ----
# board.d default is the opposite (eth1=WAN, eth0/eth2/eth3=LAN); flip it here.
brdev=$(uci show network 2>/dev/null | sed -n "s/^network\.\([^.]*\)\.name='br-lan'.*/\1/p" | head -1)
if [ -n "$brdev" ]; then
  uci -q del_list network."$brdev".ports='eth0'   # eth0 leaves LAN → becomes WAN
  uci -q add_list network."$brdev".ports='eth1'   # eth1 joins LAN
fi
uci -q set network.wan.device='eth0'
uci -q set network.wan6.device='eth0'
uci -q set network.lan.ipaddr='192.168.1.1'

# ---- Wi-Fi AP (MT7921) — DEFERRED ----
# The mt7921 driver loads AFTER uci-defaults on first boot, so configuring the radio
# here races the driver and the AP comes up open ("OpenWrt"). Instead, install a
# one-shot boot service that waits for the radio, secures the AP, then self-removes.
cat > /etc/init.d/spooky-wifi-setup <<'WIFISVC'
#!/bin/sh /etc/rc.common
START=99
boot() {
  i=0
  while [ ! -e /sys/class/ieee80211/phy0 ] && [ "$i" -lt 20 ]; do sleep 1; i=$((i+1)); done
  [ -z "$(uci -q get wireless.radio0)" ] && wifi config
  if [ -n "$(uci -q get wireless.radio0)" ]; then
    uci -q set wireless.radio0.disabled='0'
    uci -q set wireless.radio0.country='US'
    uci -q set wireless.default_radio0.ssid='SpookyWrt-H68K'
    uci -q set wireless.default_radio0.encryption='psk2'
    # Per-device random PSK — never ship a static Wi-Fi password. Recorded root-only.
    key=$(tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 16)
    [ -z "$key" ] && key="spooky-$(tr -d - < /proc/sys/kernel/random/uuid | head -c 10)"
    uci -q set wireless.default_radio0.key="$key"
    printf 'SpookyWrt initial Wi-Fi\nSSID:     SpookyWrt-H68K\nPassword: %s\n' "$key" > /etc/spooky-initial-wifi.txt
    chmod 600 /etc/spooky-initial-wifi.txt
    uci -q commit wireless
    wifi reload
  fi
  /etc/init.d/spooky-wifi-setup disable 2>/dev/null
  rm -f /etc/init.d/spooky-wifi-setup
}
WIFISVC
chmod +x /etc/init.d/spooky-wifi-setup
/etc/init.d/spooky-wifi-setup enable 2>/dev/null

uci commit
exit 0
