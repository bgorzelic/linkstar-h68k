# SpookyWrt — VPN provider setup

<sub>[Home](../README.md) › [Docs](README.md) › VPN providers</sub>

One importer, `spooky-vpn` (POSIX/ash), handles **any** provider: WireGuard configs (most modern
providers) or OpenVPN configs (the rest), sets up a firewall `vpn` zone (masq + MTU fix), and a
one-command **kill-switch**. Pair with `pbr` for split-tunnel (per-device routing). WireGuard is in the
flagship; `openvpn-openssl` builds; both verified.

```text
spooky-vpn wg   provider.conf              # import WireGuard   → spooky-vpn up
spooky-vpn ovpn provider.ovpn user pass    # import OpenVPN     → spooky-vpn up
spooky-vpn kill on|off                     # leak-proof kill-switch
spooky-vpn status                          # tunnel + public IP
```

You never hand credentials to anyone but your own router. The importer writes `/etc/openvpn/vpn.auth`
(chmod 600) or the WireGuard private key into uci — local only.

## The popular providers

| Provider | Protocol | Where the config comes from |
|----------|----------|------------------------------|
| **Mullvad** | WireGuard | account → [mullvad.net/account/wireguard-config](https://mullvad.net/en/account/wireguard-config) → pick a server → download `.conf` → `spooky-vpn wg` |
| **ProtonVPN** | WireGuard | dashboard → Downloads → WireGuard config → `.conf` → `spooky-vpn wg` |
| **IVPN** | WireGuard | account → WireGuard → generate → `.conf` → `spooky-vpn wg` |
| **Surfshark** | WireGuard | manual setup → WireGuard → download credentials/`.conf` → `spooky-vpn wg` |
| **Windscribe** | WireGuard | config generator → WireGuard → `.conf` → `spooky-vpn wg` |
| **NordVPN** | OpenVPN | recommended-server `.ovpn` + **service credentials** (dashboard → manual setup) → `spooky-vpn ovpn` |
| **Private Internet Access** | OpenVPN | [download .ovpn bundle](https://www.privateinternetaccess.com/openvpn/openvpn.zip) + account user/pass → `spooky-vpn ovpn` |
| **ExpressVPN** | OpenVPN | dashboard → Manual config → OpenVPN → `.ovpn` + activation username/password → `spooky-vpn ovpn` |

> **WireGuard beats OpenVPN** on a router (faster, lower CPU, in-kernel). If a provider offers both,
> prefer WireGuard. Mullvad and Proton are the most router-friendly.

## Example — Mullvad in 3 steps

```bash
# on your Mac: download the .conf from mullvad.net, then
scp mullvad-us-nyc.conf root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'spooky-vpn wg /tmp/mullvad-us-nyc.conf && spooky-vpn up && spooky-vpn kill on'
```

## Example — Nord (already scaffolded on this box)

```bash
ssh root@192.168.1.1 'vi /etc/openvpn/nord.auth'   # add service user/pass
ssh root@192.168.1.1 'spooky-vpn up'
```

## Split-tunnel (only some devices via VPN)

```bash
apk add pbr luci-app-pbr && /etc/init.d/pbr enable
# LuCI ▸ Services ▸ Policy Based Routing → rule: source = <device IP> → interface = vpn
```

Everything else stays on your normal WAN. This is the GL.iNet-style "route the streaming box through
Nord, nothing else" setup.

## Kill-switch

`spooky-vpn kill on` drops all LAN→WAN traffic, so if the tunnel dies nothing leaks to your ISP. Turn it
off with `spooky-vpn kill off`. (With split-tunnel/pbr you usually leave it off and route selectively.)
