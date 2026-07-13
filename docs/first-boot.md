# First boot

<sub>[Home](../README.md) › [Docs](README.md) › First boot</sub>

What to expect the first time a LinkStar H68K boots the stock Ubuntu image, and how
to get it into a sane, secure state fast.

## Default credentials

| OS | User | Password |
|----|------|----------|
| Ubuntu 20.04 | `linkstar` | `linkstar` |
| Ubuntu 20.04 | `root` | `root` |
| OpenWRT | `root` | `password` |

These are **identical on every unit** — change them immediately (and prefer SSH keys;
see [hardening.md](hardening.md)).

## What the stock image does on first boot

- **rootfs auto-expands** to fill the card (can take a minute; verified 6.4 G → 114 G).
  If it doesn't, run [`../scripts/expand-rootfs.sh`](../scripts/expand-rootfs.sh).
- **`unattended-upgrades` runs** and can hang on the dpkg lock — the
  [apt-lock trap](known-issues.md#first-boot-apt-lock-trap).
- **Three network stacks race** → you may get no DHCP lease
  ([fix](known-issues.md#no-dhcp-out-of-the-box)).
- **Insecure defaults are live**: shared SSH host keys, network ADB on `:5555`,
  cleartext FTP on `:21`, no firewall.

## The fast path

**If you flashed a release image with the [first-boot overlay](../firstboot/README.md)**,
all of the above is handled automatically on first boot — nothing to do but log in and
change passwords.

**Otherwise**, apply the baseline yourself:

```bash
# regenerate the shared host keys
sudo rm /etc/ssh/ssh_host_* && sudo dpkg-reconfigure openssh-server

# then the toolkit
sudo scripts/fix-networking.sh
sudo scripts/expand-rootfs.sh
sudo scripts/harden.sh --pubkey-file ~/.ssh/authorized_keys
sudo scripts/first-setup.sh --hostname h68k-01 --timezone America/New_York --update
```

## Finding the device on your network

It blocks ping but answers SSH, so a normal sweep misses it — use
[`../scripts/discover.sh`](../scripts/discover.sh) (or `nmap -Pn -p22` across the right
CIDR; note the LAN is often a /22). See [networking notes](how-it-works.md).
