# Upgrading the LinkStar H68K: Ubuntu 20.04 → 22.04 → 24.04 (the real guide)

<sub>[Home](../README.md) › [Docs](README.md) › Upgrading</sub>

We took a live H68K from the vendor **Ubuntu 20.04** all the way to **24.04.4 LTS**. It works, but
every step hit a real gotcha. This is the honest, battle-tested walkthrough — follow it and skip the
pain.

> **The kernel does NOT change.** The vendor **4.19 BSP kernel** lives in the `boot` partition
> (`boot.img`), not in an apt `linux-image` package. A userland release-upgrade upgrades everything
> *except* the kernel. You end up on modern userland (glibc 2.39 / systemd 255) on a 4.19 kernel —
> fine for almost everything, but it's why **Wi-Fi and the 2.5G NICs stay dead** (see
> [known-issues.md](known-issues.md)). For a modern kernel *and* userland,
> that's Armbian/mainline, not this path.

## Before you start

- **Back up / know your rollback.** microSD boots first, so your rollback is simply re-flashing the
  card (or pulling it to fall back to eMMC). Keep your pre-upgrade image.
- **Free space:** each LTS jump downloads ~1.5 GB; have several GB free.
- **Do it over a resilient session** — `tmux`, because releases take 30–60 min and reboot mid-way.

## The upgrade, step by step (with the traps)

### 0. Fully update the current release first, then reboot

```bash
sudo systemctl mask unattended-upgrades apt-daily.{service,timer} apt-daily-upgrade.{service,timer}
sudo apt update && sudo apt -y full-upgrade
sudo reboot   # REQUIRED — do-release-upgrade refuses if /var/run/reboot-required exists
```

> **Trap #1 — reboot-required blocks the upgrade.** After a `full-upgrade`, `do-release-upgrade`
> aborts with "you have not rebooted after updating a package which requires a reboot." Reboot first.

<!-- -->

> **Trap #2 — first-boot `unattended-upgrades` holds the dpkg lock and can hang** on the Ubuntu
> ESM/Pro check for 20+ minutes, blocking all apt. That's why we mask the auto-updaters above.

### 1. Run the release upgrade in tmux, one LTS at a time

```bash
sudo apt install -y tmux
tmux new -s up
sudo sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades
sudo do-release-upgrade -f DistUpgradeViewNonInteractive
```

Go **20.04 → 22.04**, reboot, verify, **then** 22.04 → 24.04. Never jump two releases.
Reattach after an SSH drop with `tmux attach -t up`. Progress logs live in `/var/log/dist-upgrade/`.

> **Trap #3 — the IP changes.** After the reboot the box comes back on a **new DHCP lease**. Find it
> by MAC (`arp -an | grep <mac>`) or with `scripts/discover.sh`.

### 2. The 24.04 step will likely ABORT on firefox — this is expected

The 22.04→24.04 upgrade re-pulls **firefox** as a desktop dep; its snap-transition fails
(`system does not fully support snapd: cannot mount squashfs`), dpkg returns error 1, and the whole
upgrade aborts **mid-configure**, leaving ~900 packages unconfigured. The box then won't boot cleanly
(drops toward emergency, or a degraded desktop).

> **Trap #4 — firefox snap breaks the 24.04 upgrade.** Fix = purge firefox, then finish configuring:

```bash
sudo dpkg --purge --force-all firefox firefox-locale-en
sudo dpkg --configure -a          # configures the ~900 already-downloaded packages; NO network needed
sudo apt-get -f -y install
sudo reboot
```

Run this at the console (HDMI) if SSH/networking is down — `dpkg --configure -a` needs no network.
If you can't reach a console, see [offline-sd-repair-debugfs.md](offline-sd-repair-debugfs.md) to
inject a one-shot self-repair from another machine.

### 3. After it reaches 24.04 — fix the things the upgrade broke

Even after a clean `dpkg --configure -a`, several things are broken on 24.04. Fix all of them:

**Trap #5 — interfaces get renamed `eth0/eth1` → `end0/end1`.** 24.04's predictable naming renames
the RK3568 GMAC ports. Your old netplan (referencing `eth0`) no longer matches → no DHCP. Fix with a
**name-independent** networkd rule (`fix-networking.sh` in this repo does this):

```ini
# /etc/systemd/network/05-dhcp-all.network
[Match]
Name=en* eth* end*
[Network]
DHCP=ipv4
[Link]
RequiredForOnline=no
```

**Trap #6 — `/etc/hosts` loses `localhost`.** dpkg postinsts fail with "unable to resolve host".

```bash
echo "127.0.0.1 localhost.localdomain localhost" | sudo tee -a /etc/hosts
```

**Trap #7 — DNS dead (`systemd-resolved` not installed).** `/etc/resolv.conf` is a dangling symlink.

```bash
sudo rm -f /etc/resolv.conf
printf "nameserver 192.168.4.1\nnameserver 1.1.1.1\n" | sudo tee /etc/resolv.conf
```

**Trap #8 — no RTC → clock is wildly off → apt rejects repos** ("Release file is not valid yet").
Set the time, then ensure NTP runs on every boot:

```bash
sudo date -u -s "<current UTC>"      # or: sudo ntpdate pool.ntp.org
sudo systemctl enable --now ntpsec   # 24.04 provides 'ntp' via ntpsec; timesyncd is masked here
```

### 4. Finish the updates

```bash
sudo apt update && sudo apt -y full-upgrade    # the noble-updates/security that lagged
sudo apt -y install iputils-ping                # 'ping' gets removed in the transition
sudo apt -y autoremove --purge && sudo apt clean
```

## Verify (end state we reached)

```text
Ubuntu 24.04.4 LTS · kernel 4.19.219 · dpkg audit CLEAN · 0 upgradable
end1 UP with DHCP · internet OK · networkd active · NetworkManager masked · ntpsec enabled
```

## Also fix while you're here

- **`/usr` perms security defect** — the vendor image ships `/usr` owned by a phantom uid 1000,
  group-writable. See [known-issues.md](known-issues.md#usr-ownership-defect).
- **Boot is slow / bloated** — see [boot-optimization.md](boot-optimization.md).
- **Want a web UI / NAS** — see [appliance-cockpit-nas-firewall.md](appliance-cockpit-nas-firewall.md).

## Reality check

This gets you a modern, secure **userland**, but it's a fragile, manual road and the kernel is still
4.19. For a clean modern router/NAS/AP, the **OpenWrt track** (v0.2.0) is the better answer — Wi-Fi and
2.5G work there. This upgrade doc exists because people *will* try it, and they deserve to succeed.
