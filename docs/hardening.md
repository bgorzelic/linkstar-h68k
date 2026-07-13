# Hardening

<sub>[Home](../README.md) › [Docs](README.md) › Hardening</sub>

The stock LinkStar H68K image is **insecure by default**. This is the companion to
[`../scripts/harden.sh`](../scripts/harden.sh) — what's wrong, what the script fixes,
and how to verify.

## What's wrong out of the box

| Exposure | Detail |
|----------|--------|
| **Network ADB** | `adbd` on `0.0.0.0:5555` — an unauthenticated root shell to anyone on the LAN |
| **Cleartext FTP** | `vsftpd` on `:21` |
| **No firewall** | `iptables` all-ACCEPT |
| **Shared SSH host keys** | baked into the image — identical across all units (MITM risk) |
| **Default passwords** | `linkstar`/`linkstar`, `root`/`root` — same on every unit |
| **SSH password auth on** | brute-forceable |

Full detail + the network-stack and apt-lock issues: [known-issues.md](known-issues.md).

## What `harden.sh` does

```bash
sudo scripts/harden.sh --pubkey-file ~/.ssh/authorized_keys
```

- Disables `adbd` and `vsftpd`.
- Installs `ufw` with default-deny inbound, allowing only SSH (add `--allow-port N`).
- Installs your SSH public key, then sets `PasswordAuthentication no` — **but only
  once a key is present**, so it can't lock you out. No key → it warns and leaves
  passwords on.
- Validates `sshd -t` before reloading the daemon.

Preview everything first with `--dry-run`; skip steps with `--skip-adb`, `--skip-ftp`,
`--skip-firewall`, `--skip-ssh`.

## Also do (not covered by harden.sh)

```bash
# regenerate the shared host keys
sudo rm /etc/ssh/ssh_host_* && sudo dpkg-reconfigure openssh-server
# change the default passwords
passwd ; sudo passwd root
```

The [first-boot overlay](../firstboot/README.md) does the host-key regen + adb/FTP/firewall
automatically on a flashed image (it leaves password auth on for you to key-secure).

## Verify

```bash
# from a workstation — these should now fail / show filtered
nmap -Pn -p 5555,21 <device-ip>          # 5555 & 21 closed/filtered
ssh -o PubkeyAuthentication=no <you>@<device-ip>   # should be refused once key-only
sudo ufw status verbose                  # on the device: deny incoming, allow 22
```
