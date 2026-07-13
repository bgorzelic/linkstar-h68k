# H68K as an appliance: web management + NAS + firewall (Ubuntu track)

<sub>[Home](../README.md) › [Docs](README.md) › Appliance (NAS/web)</sub>

Turn the H68K into a web-managed NAS/server on the Ubuntu track. (For a full router/AP with Wi-Fi, use
the OpenWrt track — Wi-Fi is dead on this kernel.) All verified on 24.04.4.

## Web management — Cockpit

The easy "manage Linux from a browser" console: services, storage, logs, updates, users, and a full
terminal.

```bash
sudo apt install -y cockpit cockpit-storaged
sudo systemctl enable --now cockpit.socket
```

- Access: **`https://<ip>:9090`**, log in with your admin user. Self-signed cert → accept the warning.
- **Caveat:** Cockpit's *Networking* page expects NetworkManager; this build uses `systemd-networkd`,
  so interfaces show read-only there. Everything else (services, storage, logs, terminal, updates) is
  fully interactive. Trade-off of the leaner networkd setup.
- For SMB share management in the browser, add **`cockpit-file-sharing`** (45Drives 3rd-party repo).

## NAS — Samba share

```bash
sudo apt install -y samba
sudo mkdir -p /srv/nas/share && sudo chown "$USER":"$USER" /srv/nas/share && sudo chmod 2775 /srv/nas/share
sudo tee -a /etc/samba/smb.conf >/dev/null <<'EOF'

[nas]
   comment = H68K NAS Share
   path = /srv/nas/share
   browseable = yes
   read only = no
   valid users = bgorzelic
   create mask = 0664
   directory mask = 2775
EOF
sudo systemctl disable --now samba-ad-dc && sudo systemctl mask samba-ad-dc   # we're standalone, not a domain controller
(echo "PASS"; echo "PASS") | sudo smbpasswd -s -a bgorzelic && sudo smbpasswd -e bgorzelic  # Samba has its own password DB
sudo systemctl enable --now smbd nmbd
```

Access from any client: `\\<ip>\nas` (Windows) or `smb://<ip>/nas` (macOS).
> **Trap:** the `samba` package auto-enables `samba-ad-dc` (Active Directory DC) which conflicts with
> standalone `smbd`. Disable+mask it (above). And remember Samba passwords are separate from the
> system password — set with `smbpasswd`.

## Firewall — ufw (do it with a rollback net)

`ufw` is easy to lock yourself out of over SSH. Always allow SSH first and arm an auto-disable
rollback before enabling, then confirm on a fresh connection.

```bash
sudo apt install -y ufw
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp     comment SSH
sudo ufw allow 9090/tcp   comment Cockpit
sudo ufw allow 139,445/tcp comment Samba
sudo ufw allow 137,138/udp comment NetBIOS
sudo ufw allow 5353/udp   comment mDNS
# ROLLBACK NET: auto-disable in 180s unless we cancel it
sudo bash -c 'nohup sh -c "sleep 180; ufw --force disable" >/tmp/ufw-rb.log 2>&1 & echo $! >/tmp/ufw-rb.pid'
sudo ufw --force enable
# → open a NEW ssh session to confirm you're not locked out, THEN:
sudo kill "$(cat /tmp/ufw-rb.pid)"   # cancel rollback; ufw stays on
```

Result: only SSH / Cockpit / Samba / mDNS are reachable; everything else default-denied.

## End state

```text
Web:   https://<ip>:9090 (Cockpit)
NAS:   \\<ip>\nas  (Samba, ksmbd is a lighter alternative)
FW:    ufw active, default-deny, minimal surface
Base:  24.04.4, ~9s boot, ~470MB RAM
```

## The rollback-timer pattern (reuse everywhere)

"Apply a risky change → schedule an auto-revert in N seconds → confirm connectivity → cancel the
revert." We used it for `ufw` here and it's the exact pattern the OpenWrt UI should use for every
network-reconfiguring action so the UI can never brick your access. It is the single most valuable
safety idiom from this project.
