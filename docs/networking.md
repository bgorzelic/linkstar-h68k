# Networking

<sub>[Home](../README.md) › [Docs](README.md) › Networking</sub>

The H68K is a four-port box, and its networking has a few sharp edges worth knowing —
the mixed NIC chipsets, a subnet-discovery quirk, and the vendor image's DHCP mess.

## The four ports (two chipset families)

| Interface | Ports | Chipset | Speed |
|-----------|-------|---------|-------|
| `eth0` / `eth1` | 1 G ×2 | Realtek **RTL8211F** (PHY off the RK3568 GMAC) | 1 GbE |
| `eth2` / `eth3` | 2.5 G ×2 | Realtek **RTL8125B** (PCIe MAC+PHY) | 2.5 GbE |
| `wlan0` | M.2 | MediaTek **MT7921** (optional) | Wi-Fi 6 |

The 2.5 G ports and Wi-Fi are the ones with **vendor driver bugs** — they work under a
mainline kernel (see [known-issues.md](known-issues.md) and the
[Armbian route](alternative-os.md)). Full hardware detail: [hardware.md](hardware.md).

## Finding the device on your LAN

Two gotchas make the H68K hard to find with a naive scan:

1. **It blocks ping.** A normal `nmap -sn` ping sweep reports it as "down." Probe a port
   instead: `nmap -Pn -p22`.
2. **The LAN is often a /22, not a /24.** Scanning only `192.168.x.0/24` misses it if it
   landed in a neighbouring block.

`discover.sh` handles both — it auto-detects the real CIDR and probes SSH:

```bash
scripts/discover.sh                 # auto-detect subnet, look for SSH
scripts/discover.sh -c 192.168.4.0/22
```

### When it changes DHCP lease

After a reboot the box may come back on a **different IP** (new DHCP lease). Don't panic
— find it by its MAC:

```bash
scripts/discover.sh                 # re-scan; or:
arp -an | grep -i "<the device MAC>"
```

## "No DHCP" out of the box

The vendor image enables **three network stacks at once** (netplan/systemd-networkd,
NetworkManager, ifupdown); they race and the box often ends up with no address. Fix it
by standardizing on systemd-networkd:

```bash
sudo scripts/fix-networking.sh      # masks NetworkManager, DHCP on eth0–eth3
```

Details + diagram: [known-issues.md](known-issues.md#no-dhcp-out-of-the-box).

## Static IP (netplan)

Once on a single networkd stack, a static address is straightforward — e.g.
`/etc/netplan/config.yaml`:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses: [192.168.4.10/22]
      routes:
        - to: default
          via: 192.168.4.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
```

Then `sudo netplan apply`. (`eth0` is a 1 G port — reliable on the vendor kernel.)

## Router / OpenWRT port mapping

Under the OpenWRT image the default roles are `eth0` = **WAN**, the remaining ports =
**LAN**, with the LuCI admin UI at `192.168.100.1`. See
[alternative-os.md](alternative-os.md).

## On Ubuntu 24.04

- **Interface names** stay `eth0`–`eth3` on this board (the `rk_gmac-dwmac` driver names
  them; verified they are *not* renamed to `enP*`). Even so, `fix-networking.sh` installs a
  **name-independent** DHCP fallback so a rename couldn't break networking.
- **Boot with the cable already connected** to a 1 G port → your router, so the link is up
  during early boot and DHCP completes. Verify with `ip -br addr show eth0` — **not** `iw`,
  which only shows Wi-Fi.
- **DNS**: the image ships no `systemd-resolved`, so you can end up with an IP but no name
  resolution. `fix-networking.sh` repairs it — details in [known-issues.md](known-issues.md).

## Throughput notes

- The 2.5 G ports reach ~2.35 Gbps and the 1 G ports ~940 Mbps **once the drivers work**
  — i.e. on a mainline kernel. On the stock 4.19 vendor image the 2.5 G pair may not link
  at all.
- For real 2.5 G you need 2.5 G on the other end too (switch/NIC) and Cat5e+ cabling.
