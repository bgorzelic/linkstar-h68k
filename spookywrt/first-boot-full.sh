#!/bin/sh
# SpookyWrt flagship first-boot: wizard + branding + Wi-Fi(deferred) + NTP + eth0-WAN
cat > /usr/bin/spooky-setup <<'SPOOKYSETUP_EOF'
#!/bin/sh
# spooky-setup — SpookyWrt onboarding / provisioning wizard
# Two tracks: Express (a few questions, sane defaults) or Advanced (full control).
# Every network-affecting change is applied under a rollback timer so you can't lock
# yourself out. POSIX/ash — runs on OpenWrt over SSH or the serial console.
set -u

C='\033[35m'; Y='\033[33m'; G='\033[32m'; B='\033[36m'; D='\033[90m'; RB='\033[1m'; R='\033[0m'
ROLLBACK=90
CFG=/etc/config

hr(){ printf "${D} ────────────────────────────────────────────────────────────${R}\n"; }
title(){ clear 2>/dev/null; printf "\n${C}${RB}  SpookyWrt${R} ${D}· onboarding${R}\n"; hr; }
ask(){ # ask "prompt" "default" -> echoes answer
  local p="$1" d="${2:-}" a=""
  if [ -n "$d" ]; then printf "  %s ${D}[%s]${R}: " "$p" "$d" >&2; else printf "  %s: " "$p" >&2; fi
  read -r a; [ -z "$a" ] && a="$d"; printf '%s' "$a"
}
yesno(){ local p="$1" d="${2:-y}" a; a=$(ask "$p ${D}(y/n)${R}" "$d"); case "$a" in y*|Y*) return 0;; *) return 1;; esac; }
pause(){ printf "\n  ${D}press ENTER…${R}"; read -r _; }
secret(){ # secret "prompt" -> echoes value (hidden, confirmed)
  local p="$1" a b
  while :; do
    printf "  %s: " "$p" >&2; stty -echo 2>/dev/null; read -r a; stty echo 2>/dev/null; printf "\n" >&2
    printf "  confirm: " >&2;  stty -echo 2>/dev/null; read -r b; stty echo 2>/dev/null; printf "\n" >&2
    [ "$a" = "$b" ] && { printf '%s' "$a"; return 0; }
    printf "  ${Y}didn't match — try again${R}\n" >&2
  done
}

# ---- rollback-protected apply for network changes ----
apply_network(){
  cp -a "$CFG" /tmp/spooky-cfg-bak 2>/dev/null
  rm -f /tmp/spooky-ok
  ( sleep "$ROLLBACK"; [ -f /tmp/spooky-ok ] && exit 0
    cp -a /tmp/spooky-cfg-bak/* "$CFG"/ 2>/dev/null
    /etc/init.d/network restart 2>/dev/null; /etc/init.d/firewall reload 2>/dev/null
    logger -t spooky-setup "unconfirmed network change — rolled back" ) &
  local rp=$!
  uci commit
  /etc/init.d/network reload 2>/dev/null; /etc/init.d/firewall reload 2>/dev/null
  printf "\n  ${Y}Applied.${R} If the network still works, press ENTER within ${RB}%ss${R} to KEEP it.\n" "$ROLLBACK"
  printf "  ${D}(no input → automatic rollback to the previous config)${R}\n  > "
  read -r _; touch /tmp/spooky-ok; kill "$rp" 2>/dev/null
  printf "  ${G}Kept.${R}\n"
}
apply_soft(){ uci commit; printf "  ${G}Saved.${R}\n"; }

# ---- building blocks ----
set_password(){ local p; p=$(secret "New root password"); printf '%s\n%s\n' "$p" "$p" | passwd root >/dev/null 2>&1 && printf "  ${G}password set${R}\n"; }
set_hostname(){ local h; h=$(ask "Hostname" "$(uci -q get system.@system[0].hostname || echo SpookyWrt)"); uci -q set system.@system[0].hostname="$h"; uci -q set network.lan.hostname="$h" 2>/dev/null; }
set_tz(){
  printf "  ${D}1)UTC 2)Pacific 3)Mountain 4)Central 5)Eastern 6)London 7)custom${R}\n"
  local c z; c=$(ask "Timezone" "1")
  case "$c" in
    1) z="UTC;UTC";; 2) z="America/Los_Angeles;PST8PDT,M3.2.0,M11.1.0";;
    3) z="America/Denver;MST7MDT,M3.2.0,M11.1.0";; 4) z="America/Chicago;CST6CDT,M3.2.0,M11.1.0";;
    5) z="America/New_York;EST5EDT,M3.2.0,M11.1.0";; 6) z="Europe/London;GMT0BST,M3.5.0/1,M10.5.0";;
    *) z="$(ask 'Zone name (e.g. Asia/Tokyo)' 'UTC');UTC";;
  esac
  uci -q set system.@system[0].zonename="${z%;*}"; uci -q set system.@system[0].timezone="${z#*;}"
  uci -q set system.ntp.enabled='1'
}
set_wifi(){
  [ -z "$(uci -q get wireless.radio0)" ] && wifi config
  [ -z "$(uci -q get wireless.radio0)" ] && { printf "  ${Y}no Wi-Fi radio detected${R}\n"; return; }
  yesno "Enable Wi-Fi AP?" "y" || { uci -q set wireless.radio0.disabled='1'; return; }
  local s k; s=$(ask "Wi-Fi name (SSID)" "$(uci -q get wireless.default_radio0.ssid || echo SpookyWrt-H68K)")
  k=$(secret "Wi-Fi password (8+ chars)")
  uci -q set wireless.radio0.disabled='0'; uci -q set wireless.radio0.country='US'
  uci -q set wireless.default_radio0.ssid="$s"
  uci -q set wireless.default_radio0.encryption='psk2'; uci -q set wireless.default_radio0.key="$k"
}
set_lan_ip(){ local ip; ip=$(ask "Router LAN IP" "$(uci -q get network.lan.ipaddr || echo 192.168.1.1)"); uci -q set network.lan.ipaddr="$ip"; }

svc(){ # svc name enable|disable
  case "$2" in
    enable)  /etc/init.d/"$1" enable 2>/dev/null; /etc/init.d/"$1" start 2>/dev/null; printf "  ${G}+ %s${R}\n" "$1";;
    disable) /etc/init.d/"$1" stop 2>/dev/null; /etc/init.d/"$1" disable 2>/dev/null; printf "  ${D}- %s${R}\n" "$1";;
  esac
}
enable_honeypot(){
  # decoy helper — one forking socat listener that logs every touch
  cat > /usr/bin/spooky-decoy <<'EOF'
#!/bin/sh
exec /usr/bin/socat TCP-LISTEN:"$1",fork,reuseaddr SYSTEM:'echo "$(date +%FT%T) hit :'"$1"' from $SOCAT_PEERADDR" >> /tmp/honeypot.log'
EOF
  chmod +x /usr/bin/spooky-decoy
  # procd service: a capture + one decoy instance per port
  cat > /etc/init.d/spooky-honeypot <<'EOF'
#!/bin/sh /etc/rc.common
# SpookyWrt honeypot — decoy listeners that log every touch (own-network only)
START=95; USE_PROCD=1
start_service(){
  procd_open_instance cap
  procd_set_param command tcpdump -i any -n -w /tmp/honeypot.pcap -G 3600 -W 6 "tcp[tcpflags] & tcp-syn != 0"
  procd_set_param respawn; procd_close_instance
  for p in 23 2323 21 8080; do
    procd_open_instance "hp$p"
    procd_set_param command /usr/bin/spooky-decoy "$p"
    procd_set_param respawn; procd_close_instance
  done
}
EOF
  chmod +x /etc/init.d/spooky-honeypot
  : > /tmp/honeypot.log
  svc spooky-honeypot enable
  svc banip enable
  printf "  ${G}honeypot armed${R} ${D}— decoys on :21/:23/:2323/:8080 → /tmp/honeypot.log · banip on${R}\n"
}
apply_mode(){ # apply_mode <mode>  (service side only; AP/network handled separately)
  case "$1" in
    nas)      svc samba4 enable;;
    travel)   printf "  ${D}WireGuard ready — import a tunnel in LuCI ▸ Network ▸ Interfaces${R}\n";;
    hacker)   printf "  ${D}CLI toolkit ready: nmap arp-scan mtr tcpdump ethtool lldpd iperf3${R}\n";;
    honeypot) enable_honeypot;;
    ap)       printf "  ${Y}AP mode reconfigures networking${R} — use Advanced ▸ Network for the rollback-safe transform.\n";;
    *)        svc dnsmasq enable; svc firewall enable;;
  esac
}

status(){
  title
  local h w cli
  h=$(uci -q get system.@system[0].hostname); w=$(uci -q get wireless.default_radio0.ssid)
  cli=$(wc -l < /tmp/dhcp.leases 2>/dev/null | tr -d ' ')
  printf "  ${B}host${R}   %s\n" "${h:-?}"
  printf "  ${B}LAN${R}    %s\n" "$(uci -q get network.lan.ipaddr || echo ?)"
  printf "  ${B}WAN${R}    %s\n" "$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{print $2; exit}')"
  printf "  ${B}Wi-Fi${R}  %s  ${D}(%s)${R}\n" "${w:-off}" "$([ "$(uci -q get wireless.radio0.disabled)" = 1 ] && echo disabled || echo enabled)"
  printf "  ${B}DHCP${R}   %s leases\n" "${cli:-0}"
  printf "  ${B}svc${R}    samba:%s adguard:%s banip:%s honeypot:%s\n" \
    "$(pgrep -x smbd >/dev/null && echo on || echo off)" \
    "$(pgrep -x AdGuardHome >/dev/null && echo on || echo off)" \
    "$(pgrep -x banip >/dev/null && echo on || echo off || true)" \
    "$([ -x /etc/init.d/spooky-honeypot ] && echo armed || echo off)"
  hr; pause
}

# ================= EXPRESS =================
express(){
  title; printf "  ${RB}Express setup${R} ${D}— the essentials, sane defaults for the rest${R}\n\n"
  set_password
  set_hostname
  set_tz
  set_wifi
  printf "\n  ${D}Mode: 1)Router 2)Access-Point 3)NAS 4)Travel/VPN 5)Hacker 6)Honeypot${R}\n"
  local m mode; m=$(ask "Operating mode" "1")
  case "$m" in 2) mode=ap;; 3) mode=nas;; 4) mode=travel;; 5) mode=hacker;; 6) mode=honeypot;; *) mode=router;; esac
  yesno "Change the LAN IP from $(uci -q get network.lan.ipaddr || echo 192.168.1.1)?" "n" && set_lan_ip
  echo; hr
  printf "  ${RB}Review${R}  host=%s  tz=%s  wifi=%s  mode=%s  lan=%s\n" \
    "$(uci -q get system.@system[0].hostname)" "$(uci -q get system.@system[0].zonename)" \
    "$(uci -q get wireless.default_radio0.ssid)" "$mode" "$(uci -q get network.lan.ipaddr)"
  hr
  yesno "Apply now?" "y" || { printf "  ${Y}discarded${R}\n"; uci revert system; uci revert wireless; uci revert network; pause; return; }
  apply_mode "$mode"
  /etc/init.d/system reload 2>/dev/null; /etc/init.d/led reload 2>/dev/null
  wifi reload 2>/dev/null
  # networking last, under rollback
  if [ -n "$(uci -q changes network)" ]; then apply_network; else apply_soft; fi
  printf "\n  ${G}${RB}SpookyWrt is configured.${R}  LuCI: ${B}http://%s${R}\n" "$(uci -q get network.lan.ipaddr)"
  pause
}

# ================= ADVANCED =================
adv_system(){ title; printf "  ${RB}System${R}\n\n"; set_hostname; set_tz
  yesno "Change root password?" "n" && set_password
  apply_soft; /etc/init.d/system reload 2>/dev/null; pause; }
adv_wifi(){ title; printf "  ${RB}Wi-Fi${R}\n\n"; set_wifi
  local ch; ch=$(ask "Channel (auto or a number)" "$(uci -q get wireless.radio0.channel || echo auto)"); uci -q set wireless.radio0.channel="$ch"
  apply_soft; wifi reload 2>/dev/null; pause; }
adv_network(){ title; printf "  ${RB}Network${R} ${D}(rollback-protected)${R}\n\n"
  set_lan_ip
  local dr; dr=$(ask "DHCP pool start" "$(uci -q get dhcp.lan.start || echo 100)"); uci -q set dhcp.lan.start="$dr"
  local dl; dl=$(ask "DHCP pool size"  "$(uci -q get dhcp.lan.limit || echo 150)"); uci -q set dhcp.lan.limit="$dl"
  if yesno "Reassign the WAN port? ${D}(default: eth0)${R}" "n"; then
    local wp; wp=$(ask "WAN interface (eth0/eth1/eth2/eth3)" "eth0"); uci -q set network.wan.device="$wp"; uci -q set network.wan6.device="$wp"
  fi
  hr; yesno "Apply network changes?" "y" && apply_network || { uci revert network; uci revert dhcp; printf "  ${Y}reverted${R}\n"; }
  pause; }
adv_services(){ title; printf "  ${RB}Services / modes${R}\n\n"
  yesno "NAS — Samba file sharing?" "n" && svc samba4 enable || svc samba4 disable
  yesno "AdGuard Home — DNS ad-block?" "n" && { svc adguardhome enable; printf "  ${D}dashboard: http://%s:3000${R}\n" "$(uci -q get network.lan.ipaddr)"; } || svc adguardhome disable
  yesno "SQM — smart-queue / anti-bufferbloat?" "n" && svc sqm enable || svc sqm disable
  yesno "Honeypot — decoy listeners + banip?" "n" && enable_honeypot || { svc spooky-honeypot disable; svc banip disable; }
  pause; }
advanced(){
  while :; do
    title; printf "  ${RB}Advanced${R} ${D}— pick a section${R}\n\n"
    printf "   ${B}1${R} System   ${D}hostname · timezone · password${R}\n"
    printf "   ${B}2${R} Wi-Fi    ${D}SSID · key · channel${R}\n"
    printf "   ${B}3${R} Network  ${D}LAN IP · DHCP · WAN port  (rollback)${R}\n"
    printf "   ${B}4${R} Services ${D}NAS · AdGuard · SQM · Honeypot${R}\n"
    printf "   ${B}0${R} Back\n\n"
    case "$(ask 'Section' '0')" in 1) adv_system;; 2) adv_wifi;; 3) adv_network;; 4) adv_services;; *) return;; esac
  done
}

# ================= MAIN =================
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
while :; do
  title
  printf "  Configure this SpookyWrt box. Two ways in:\n\n"
  printf "   ${B}1${R} ${RB}Express${R}   ${D}a few questions, smart defaults — 60 seconds${R}\n"
  printf "   ${B}2${R} ${RB}Advanced${R}  ${D}full control, section by section${R}\n"
  printf "   ${B}3${R} Status    ${D}what's configured right now${R}\n"
  printf "   ${B}q${R} Quit\n\n"
  case "$(ask 'Choose' '1')" in
    1) express;; 2) advanced;; 3) status;; q|Q) clear 2>/dev/null; printf "${C}stay spooky.${R}\n"; exit 0;;
  esac
done
SPOOKYSETUP_EOF
chmod +x /usr/bin/spooky-setup

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
    uci -q set wireless.default_radio0.key='spooky-h68k-2026'
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
