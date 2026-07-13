# Proposal: capture + VPN/mesh packages for `spookywrt/build.py`

Build-verified against `rockchip/armv8` SNAPSHOT (2026-07-13). Apply as a delta; don't overwrite build.py.

## Package groups

```python
# --- VPN / mesh (all build-verified; no LuCI apps exist for tailscale/zerotier/openvpn in snapshot) ---
VPN = [
    "tailscale",                              # zero-config mesh — reach box+LAN from anywhere
    "openvpn-openssl",                        # classic VPN / .ovpn provider configs
    "zerotier",                               # alt mesh
    # WireGuard already in base: wireguard-tools, kmod-wireguard, luci-proto-wireguard
    "pbr", "luci-app-pbr",                    # policy-based routing / split-tunnel (replaces old vpn-policy-routing)
]

# --- packet capture ---
CAPTURE = ["tcpdump-mini"]   # tcpdump already in base; tshark NOT in snapshot
```

**NOT in snapshot — do not add (build fails):** `luci-app-tailscale`, `luci-app-openvpn`,
`luci-app-zerotier`, `luci-app-wireguard`, `vpn-policy-routing`/`luci-app-vpn-policy-routing`, `tshark`.

## Where they fit

- **Flagship**: `tailscale` + `pbr`/`luci-app-pbr` are reasonable always-on (Tailscale is off until
  `tailscale up`; pbr is off until configured). Adds ~15–20 MB — fits the 1024 MB rootfs.
- **Or a `--profile vpn`** variant if you'd rather keep the flagship lean (mirrors `wifi-audit`).
- `openvpn-openssl` + `zerotier` are heavier/niche → good candidates for the opt-in variant.

## Helper: `spooky-capture`

Ship `scripts/spooky-capture` (staged) into `/usr/bin/spooky-capture` via the first-boot overlay (same
mechanism as `spooky-setup`). Dead-simple `tcpdump` wrapper: auto-targets a USB stick (persistent) or
`/tmp` (RAM), ring-buffered so it never fills the disk, prints the `scp` retrieval line. POSIX/ash,
shellcheck-clean. The on-device dashboard can call it for a "capture N seconds → download" button
(WebUI lane).

## First-boot enablement (optional, safe)

```sh
# tailscale + pbr installed but OFF by default (opt-in — no surprise tunnels)
/etc/init.d/tailscale enable    # daemon runs; no login until `tailscale up`
# pbr stays disabled until the user adds rules
```
