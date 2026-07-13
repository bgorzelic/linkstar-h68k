# Scripts

Idempotent Bash tooling for the LinkStar H68K. All scripts are `shellcheck`-clean,
use `set -euo pipefail`, and support `--dry-run` where they change a device.

## Flash a fresh Ubuntu SD (from your Mac/Linux — no maskrom, no Windows)

| Script | Runs on | Purpose |
| -------- | --------- | --------- |
| `unpack-rkfw.sh` | workstation | Extract partition images from the vendor RKFW `.img` (handles the 32-bit >4 GB offset overflow that breaks `afptool`). |
| `build-idbloader.sh` | workstation | Rebuild the sector-64 loader as an **`RKNS` rksd** image — the fix for the black-screen boot. |
| `build-sd-image.sh` | workstation | Write a bootable Ubuntu SD (GPT + loader + partitions at their exact offsets). **Destructive.** |

See **[`../docs/flash-ubuntu-sd-from-mac.md`](../docs/flash-ubuntu-sd-from-mac.md)** for the full walkthrough and **[`../docs/how-it-works.md`](../docs/how-it-works.md)** for the RK3568 internals.

## Set up, secure & maintain a running device

| Script | Runs on | Purpose |
| -------- | --------- | --------- |
| `discover.sh` | workstation | Find the H68K on the LAN (probes SSH with `-Pn`, auto-detects the subnet CIDR — it's often a /22). |
| `fix-networking.sh` | the device (root) or offline `ROOT=` | Resolve "no DHCP" by standardizing on systemd-networkd (masks the conflicting NetworkManager/ifupdown stacks). |
| `expand-rootfs.sh` | the device (root) | Grow the root filesystem to fill the card/eMMC (partition grow + online `resize2fs`). |
| `harden.sh` | the device (root) | Disable network ADB (:5555) & FTP (:21), install `ufw`, add an SSH key, disable password auth. |
| `first-setup.sh` | the device (root) | Hostname, timezone/NTP, updates, admin user. |
| `optimize-boot.sh` | the device (root) | De-bloat + security trim (adb/FTP off), ~14 s→9 s boot, with lifeline checks (`--headless`). |
| `finish-upgrade.sh` | the device (root) | One-shot self-repair for an interrupted 24.04 upgrade (purge firefox, `dpkg --configure -a`). |
| `lib/common.sh` | — | Shared logging / dry-run / helpers (sourced by all of the above). |

## Cut a release (reproducible)

| Script | Runs on | Purpose |
| -------- | --------- | --------- |
| `bootstrap-tools.sh` | workstation | Fetch + build the Rockchip toolchain (`rkdeveloptool`, `rkbin`) at pinned commits. |
| `build-release.sh` | workstation | One command: unpack → rebuild idbloader → (optional) flash → emit `SHA256SUMS` + manifest. |
| `make-release-image.sh` | workstation | Build a clean, sanitized, shrunk `.img.xz` release image from a prepared card/rootfs. |

Full runbook (versioning, publishing, adding OS tracks): **[`../docs/releasing.md`](../docs/releasing.md)**.

## Typical flow

```bash
# 1) On your workstation — find the device
./discover.sh

# 2) Copy the toolkit onto the device
scp -r ../scripts <user>@<device-ip>:~/

# 3) On the device — expand storage, then harden and set up
ssh <user>@<device-ip>
sudo ~/scripts/expand-rootfs.sh
sudo ~/scripts/harden.sh --pubkey-file ~/.ssh/authorized_keys   # or --pubkey "ssh-ed25519 AAAA..."
sudo ~/scripts/first-setup.sh --hostname h68k-01 --timezone America/New_York --update
```

## Safety notes

- **`harden.sh` won't lock you out**: it only disables SSH password auth once a
  usable key is in place. No key → it leaves passwords on and warns you.
- Everything supports **`--dry-run`** — run that first to preview changes.
- `harden.sh` validates `sshd -t` before reloading the SSH daemon.

See each script's `--help` for the full flag list.
