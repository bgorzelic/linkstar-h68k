# Boot optimization & de-bloating (Ubuntu track)

<sub>[Home](../README.md) › [Docs](README.md) › Boot optimization</sub>

The vendor image is a full LXQT desktop carrying a lot of weight a router/NAS never needs. We took a
live 24.04.4 unit from **14.2 s → 9.1 s boot**, closed two network security holes, and dropped to
~470 MB RAM — all reversible, verified across a reboot.

## Measure first

```bash
systemd-analyze                 # total boot time
systemd-analyze blame | head -20   # slowest units
systemd-analyze critical-chain     # what actually gates boot
systemctl --failed                 # broken units (fix these first)
```

## What we disabled (safe on a headless/appliance box)

All reversible (`disable`, not remove). None affect networking or SSH.

```bash
for u in fwupd.service fwupd-refresh.timer apport.service gnome-remote-desktop.service \
         ModemManager.service switcheroo-control.service whoopsie.service kerneloops.service \
         cups.service cups-browsed.service cups.socket cups.path bluetooth.service packagekit.service; do
  sudo systemctl disable --now "$u" 2>/dev/null
done
sudo systemctl disable --now snapd.service snapd.socket && sudo systemctl mask snapd.service snapd.socket
```

## Security holes closed (also on by default in the vendor image)

```bash
sudo systemctl disable --now adbd     # Android Debug Bridge — unauthenticated root shell on :5555
sudo update-rc.d -f adbd remove 2>/dev/null
sudo systemctl disable --now vsftpd   # cleartext FTP on :21
```

After this the **only** network-listening service is SSH (`ss -tlnp` to confirm) — a minimal surface.

## What we kept

`systemd-networkd`, `ssh`, `ntpsec` (clock — mandatory, no RTC), `avahi-daemon` (mDNS), and the LXQT
desktop (for HDMI ease-of-access). Drop the desktop too (`systemctl set-default multi-user.target` +
disable the display manager) if going fully headless — bigger win, but you lose the local GUI (you'd
use SSH or the HDMI text console).

## Verify without breaking (always)

After changes, **reboot and confirm the lifeline** before trusting it:

```bash
systemctl is-active ssh systemd-networkd ntpsec    # all active
ip -br addr                                         # has an IP
systemctl --failed                                  # 0 failed
systemd-analyze                                      # new, faster time
```

Because SSH is your only remote lifeline, re-check it on a **fresh** connection after every batch. The
microSD-first boot is your ultimate safety: a bad change is a re-flash away.

## Result (verified)

```text
boot 14.16s → 9.08s · 0 failed units · attack surface = SSH only · 453MB RAM · 20 running services
survived a clean reboot; networking + clock auto-configured
```

`scripts/optimize-boot.sh` in this repo does the safe trim idempotently with lifeline checks.
