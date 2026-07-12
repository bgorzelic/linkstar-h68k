# First-boot overlay

A systemd oneshot that applies the **secure-by-default baseline** the first time a
freshly flashed image boots, then disables itself. This is how a release image ships
"fixed" without us pre-modifying the vendor rootfs offline.

## What it does (once, on first boot)

1. **Regenerates SSH host keys** — the vendor image bakes in keys shared by every
   unit; this gives each device unique keys.
2. **Masks the auto-updaters** — avoids the first-boot `unattended-upgrades` dpkg-lock
   hang (see [../docs/known-issues.md](../docs/known-issues.md)).
3. **Expands the rootfs**, **fixes networking** (single systemd-networkd stack), and
   **hardens** (disables network ADB + FTP, installs `ufw`).

It intentionally leaves **SSH password auth ON** — a generic image has no user key
yet. Run `harden.sh --pubkey-file …` yourself afterward for key-only login.

## Files

| File | Purpose |
|------|---------|
| `run.sh` | the first-boot logic (logs to `/var/log/linkstar-firstboot.log`) |
| `linkstar-firstboot.service` | oneshot unit; runs `run.sh`, then the script disables it |
| `install.sh` | installs the overlay + toolkit into a rootfs and enables the unit |

## Use it

**Bake into a release image (offline)** — mount the image's rootfs, then:

```bash
sudo ROOT=/mnt/rootfs firstboot/install.sh
```

**Apply to a running device (online):**

```bash
sudo firstboot/install.sh      # runs on next reboot
# or run the baseline immediately:
sudo /opt/linkstar-h68k/firstboot/run.sh
```

> [!NOTE]
> This overlay is validated by `shellcheck` and structure, but a full image-bake +
> boot cycle should be verified on real hardware before an image release. See
> [../docs/releasing.md](../docs/releasing.md).
