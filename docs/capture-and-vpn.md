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

### A commercial VPN via WireGuard (Mullvad / Proton / NordLynx / IVPN)

Providers hand you a WireGuard config. Import it as a LuCI interface (`luci-proto-wireguard`, in flagship):
LuCI ▸ Network ▸ Interfaces ▸ Add ▸ protocol **WireGuard**, paste the key/peer/endpoint, set the WAN
firewall zone. Then **route only what you want** through it with `pbr` (e.g. "the TV goes through Mullvad,
everything else direct").

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
