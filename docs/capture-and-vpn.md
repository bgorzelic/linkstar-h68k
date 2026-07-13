# SpookyWrt — Packet capture & VPN / mesh

<sub>[Home](../README.md) › [Docs](README.md) › Capture & VPN</sub>

All packages below are **build-verified** against the `rockchip/armv8` SNAPSHOT (2026-07-13).

---

## Dump TCP packets — three easy ways

### 1. Live to Wireshark on your Mac (no files, zero setup)

The pro move — stream the router's capture straight into Wireshark:

```bash
ssh root@192.168.1.1 "tcpdump -i br-lan -U -s0 -w - not port 22" | wireshark -k -i -
```

Swap `br-lan` for `eth0` (WAN) or `any`. `not port 22` keeps your SSH session out of the capture.
Needs only `tcpdump` on the box (in the flagship) + Wireshark on the Mac.

### 2. `spooky-capture` — one command, saves to a USB stick

`scripts/spooky-capture` (POSIX/ash, ship it in `/usr/bin`):

```text
spooky-capture                    # LAN bridge → best storage, ring-buffered
spooky-capture wan                # the WAN uplink
spooky-capture -f 'tcp port 443'  # BPF filter
spooky-capture -s 50 -n 4         # 50 MB files, keep 4 (200 MB ring)
```

It auto-targets a **plugged-in USB stick** (persistent — pull it and open in Wireshark) or falls back to
`/tmp` (RAM). Ring-buffered (`-C`/`-W`) so it never fills the disk. Prints the exact `scp` line to pull
the pcap. Storage packages are already in the flagship (`block-mount`, `kmod-usb-storage`, `kmod-fs-*`).

### 3. Remote grab, no USB

```bash
scp root@192.168.1.1:'/tmp/captures/*.pcap' .        # after a spooky-capture run
```

The terminal session's **on-device dashboard** is the natural home for a "capture 30 s → download" button —
`spooky-capture` is the backend; wiring the button is their WebUI lane.

**Package note:** `tcpdump` is in the flagship. `tcpdump-mini` (smaller) also builds. `tshark` is **not** in
the aarch64 snapshot — use `tcpdump` and analyze in Wireshark on the desktop.

---

## VPN & mesh

| Option | Package(s) | Best for |
|--------|-----------|----------|
| **Tailscale** | `tailscale` | zero-config mesh — reach the box (and your LAN) from anywhere, no port-forwarding |
| **WireGuard** | `wireguard-tools`, `kmod-wireguard`, `luci-proto-wireguard` *(in flagship)* | modern VPN providers (Mullvad, Proton, NordLynx, IVPN) + your own tunnels |
| **OpenVPN** | `openvpn-openssl` | older providers / `.ovpn` config files |
| **ZeroTier** | `zerotier` | alternative mesh (self-hostable controller) |
| **Policy routing** | **`pbr` + `luci-app-pbr`** | route *specific devices/domains/ports* through the VPN (split-tunnel) — the pro feature |

> No LuCI apps for Tailscale/ZeroTier/OpenVPN exist in the snapshot (they're CLI/config-driven); the old
> `vpn-policy-routing` is gone — **`pbr` replaces it** and has a LuCI app.

### Tailscale (the easy one)

```bash
apk add tailscale            # or bake it in (see proposal)
/etc/init.d/tailscale enable && /etc/init.d/tailscale start
tailscale up --advertise-routes=192.168.1.0/24 --accept-routes
# → open the printed URL, authenticate. Now reach the box + LAN from any tailnet device.
```

Add `--advertise-exit-node` to use the H68K as an exit node. It just works behind NAT (no port-forward).

### A commercial VPN via WireGuard (NordLynx / Mullvad / Proton / IVPN)

Providers hand you a WireGuard config (Nord calls its WireGuard **NordLynx**). SpookyWrt ships the
whole WireGuard stack in the flagship, so no extra packages.

> [!TIP]
> **One command:** on the box, run `spooky vpn` → *NordLynx/WireGuard setup*. It prompts for the
> three values below and applies the correct config + firewall for you (and verifies the handshake).
> The manual steps below are the same thing, spelled out.

<!-- -->

> [!IMPORTANT]
> **The #1 gotcha — why a WireGuard tunnel "won't build":** in OpenWRT a peer must be its **own
> `config wireguard_<iface>` section**, *never* an inline `option peers`/`list peers` on the interface.
> A stray peer option makes netifd silently refuse to create the device — no interface, no handshake,
> IP unchanged. Structure it exactly as below.

**You need three values:** your **client private key**, and the server's **public key** + **endpoint IP**.

```sh
# NordLynx client private key — from a machine running the NordVPN app on nordlynx:
nordvpn set technology nordlynx && nordvpn connect
wg show nordlynx private-key          # → CLIENT_PRIVATE_KEY
# A server + its WireGuard public key + IP (Nord's public API):
curl -s "https://api.nordvpn.com/v1/servers/recommendations?limit=1&filters[servers_technologies][identifier]=wireguard_udp" \
 | jq -r '.[0] | .station, (.technologies[]|select(.identifier=="wireguard_udp")|.metadata[0].value)'
# → SERVER_IP  then  SERVER_PUBLIC_KEY
```

Apply the tunnel (interface + **separate peer section**) and a masqueraded VPN firewall zone:

```sh
uci set network.vpn=interface
uci set network.vpn.proto='wireguard'
uci set network.vpn.private_key='CLIENT_PRIVATE_KEY'
uci add_list network.vpn.addresses='10.5.0.2/32'

uci set network.vpnpeer=wireguard_vpn          # peer = its own section (the gotcha)
uci set network.vpnpeer.public_key='SERVER_PUBLIC_KEY'
uci set network.vpnpeer.endpoint_host='SERVER_IP'   # IP, not hostname
uci set network.vpnpeer.endpoint_port='51820'
uci add_list network.vpnpeer.allowed_ips='0.0.0.0/0'
uci set network.vpnpeer.route_allowed_ips='1'
uci set network.vpnpeer.persistent_keepalive='25'
uci commit network

uci add firewall zone
uci set firewall.@zone[-1].name='vpn'; uci set firewall.@zone[-1].masq='1'; uci set firewall.@zone[-1].mtu_fix='1'
uci set firewall.@zone[-1].input='REJECT'; uci set firewall.@zone[-1].output='ACCEPT'; uci set firewall.@zone[-1].forward='REJECT'
uci add_list firewall.@zone[-1].network='vpn'
uci add firewall forwarding; uci set firewall.@forwarding[-1].src='lan'; uci set firewall.@forwarding[-1].dest='vpn'
uci commit firewall
/etc/init.d/network restart && /etc/init.d/firewall restart
```

Verify — you want a recent handshake and your public IP to flip to the VPN server's:

```sh
wg show                       # look for "latest handshake" + rx/tx > 0
curl -s https://ipinfo.io/ip  # now the Nord server's IP, not your ISP's
```

No handshake? Re-check the peer is a `wireguard_vpn` **section** (not an option), `endpoint_host`
is the **IP** (not hostname), and `kmod-wireguard` is loaded. Then **route only what you want**
through it with `pbr` (below) — e.g. "the TV goes through Nord, everything else direct."

### Split-tunnel with PBR

```bash
apk add pbr luci-app-pbr
/etc/init.d/pbr enable
# LuCI ▸ Services ▸ Policy Based Routing → add rules by source IP / interface / domain → VPN interface
```

---

## Build.py additions (proposal)

See `proposals/capture-vpn-packages.md` — a `--profile`-friendly delta adding `tailscale`, `openvpn-openssl`,
`zerotier`, `pbr`, `luci-app-pbr`, `tcpdump-mini`, plus the `spooky-capture` helper into `/usr/bin`. All
build-verified; WireGuard is already in the flagship.
