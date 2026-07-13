# Upgrading Ubuntu in place (20.04 → 22.04 → 24.04)

You can upgrade the Ubuntu **userland** to a newer LTS while the board keeps booting its
**vendor 4.19 kernel** (which lives in `boot.img`, not apt). This usually works — glibc
and systemd are fine on a 4.19 kernel — but it's the riskiest thing you can do to a
running rootfs, so do it deliberately.

> [!WARNING]
> **Back up first.** Because the H68K boots from microSD, the simplest rollback is a full
> SD image. If an upgrade breaks the rootfs, re-flash and you're back. See
> [storage.md](storage.md#backing-up-before-risky-changes). The factory eMMC image is
> untouched regardless — pull the SD to fall back to it.

## Pre-flight

```bash
df -h /                                   # need several GB free (each step downloads ~1.5 GB)
dpkg -l | grep -c '^ii  linux-image'      # MUST be 0 — the kernel is in boot.img, so apt won't touch it
[ -f /var/run/reboot-required ] && echo "reboot first!"   # do-release-upgrade refuses if a reboot is pending
date -u                                   # NO RTC — a drifted clock makes apt reject repo metadata; fix it first
```

Then:

```bash
# mask the auto-updaters (they hold the dpkg lock and fight the upgrade)
sudo systemctl mask unattended-upgrades apt-daily.service apt-daily-upgrade.service \
                    apt-daily.timer apt-daily-upgrade.timer
# fully update the CURRENT release first
sudo apt update && sudo apt -y full-upgrade && sudo reboot   # clears the reboot-required flag
# target LTS releases only
sudo sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades
```

## Upgrade — one LTS at a time

Run it inside **tmux** so a dropped SSH session doesn't kill the upgrade:

```bash
sudo apt install -y tmux
tmux new -s upgrade
sudo do-release-upgrade -f DistUpgradeViewNonInteractive   # non-interactive; keeps vendor configs
```

Go **20.04 → 22.04**, reboot, verify, **then** 22.04 → 24.04. Don't jump two releases at once.
Reattach after an SSH drop with `tmux attach -t upgrade`.

## Gotchas we actually hit

- **Reboot-required blocks it.** An earlier `full-upgrade` sets `/var/run/reboot-required`;
  `do-release-upgrade` won't start until you reboot.
- **The IP can change.** After the reboot the box may come back on a **new DHCP lease** —
  find it again with [`../scripts/discover.sh`](../scripts/discover.sh) or by its MAC.
- **It's slow.** 30–60 minutes per step on the RK3568.
- **Config prompts.** The non-interactive view keeps existing configs; interactively,
  choose "keep the local version" for anything you (or `harden.sh`) edited.

## After each step

```bash
lsb_release -a          # confirm the new release
uname -r                # still 4.19.x vendor kernel — expected
ip -br addr ; sudo -v   # networking + sudo still good
```

Re-run [`fix-networking.sh`](../scripts/fix-networking.sh) / [`harden.sh`](../scripts/harden.sh)
if the upgrade re-enabled a service, then reboot and confirm a clean boot.

## Why the kernel is safe

The vendor BSP kernel is in the **`boot` partition** (`boot.img`), not an apt
`linux-image` package — so a userland upgrade never replaces it. The tradeoff: you end up
on a modern userland with an older (4.19) kernel. That's fine for the vast majority of
software; a few very new packages may expect newer kernel features. If you want a modern
kernel *and* userland together, the cleaner route is a community
[Armbian image](alternative-os.md).

## Rollback

Re-flash the SD with your pre-upgrade backup image (or the vendor image via the
[flash guide](flash-ubuntu-sd-from-mac.md)). Nothing about the upgrade touches eMMC.
