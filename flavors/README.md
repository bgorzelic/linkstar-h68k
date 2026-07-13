# Flavors & the release matrix

A **release** is a combination of a **track** (which OS) and, for the Ubuntu track, a
**flavor** (which variant). That gives you the set of images you'd actually want to ship:

| Release | Track | Built how | Notes |
|---------|-------|-----------|-------|
| **ubuntu-desktop** | Ubuntu | base image (LXQt) → [`desktop.sh`](desktop.sh) | the stock experience |
| **ubuntu-server** | Ubuntu | base → [`server.sh`](server.sh) (strips desktop) | headless, smaller |
| **ubuntu-casaos** | Ubuntu | base → [`casaos.sh`](casaos.sh) (CasaOS + Docker) | home-server web UI — see [casaos](../docs/casaos.md) |
| **openwrt** | OpenWRT | vendor / community raw image | router / firewall — see [alternative-os](../docs/alternative-os.md) |
| **android** | Android | vendor RKFW → eMMC | media / TV box — see [flash-emmc-windows](../docs/flash-emmc-windows.md) |

**Flavors** apply only to the Ubuntu track (`desktop`, `server`, `casaos`). **OpenWRT** and
**Android** are separate tracks — different base images we document and mirror, not build
from the Ubuntu rootfs.

## How a flavored Ubuntu release is built

Flavors customize a **booted** rootfs (apt on the device — an offline chroot isn't
practical cross-arch), then you snapshot the card:

```bash
# 1. Boot a base Ubuntu unit (from the SD you built with the pipeline)
# 2. Apply the flavor on the device
sudo flavors/server.sh                    # or desktop.sh · try --dry-run first
sudo scripts/harden.sh --pubkey-file ~/.ssh/authorized_keys
sudo scripts/first-setup.sh --update
# 3. Snapshot the SD into a release image (from your workstation)
sudo dd if=/dev/rdiskN bs=4m | xz -T0 > linkstar-h68k-ubuntu-24.04-server.img.xz
```

Verify it boots on a real unit before tagging the release. See
[../docs/releasing.md](../docs/releasing.md) for tags and publishing.

## Tag scheme

`<track>[-<flavor>]-<osversion>/v<x.y>`, e.g.:

- `ubuntu-desktop-24.04/v0.2.0`
- `ubuntu-server-24.04/v0.2.0`
- `ubuntu-casaos-24.04/v0.2.0`
- `openwrt/v0.2.0`
- `android/v0.2.0`

## Adding a flavor

Drop a `flavors/<name>.sh` that:

- sources `../scripts/lib/common.sh`, calls `require_root`, and supports `--dry-run`;
- makes **idempotent** changes (safe to re-run);
- is `shellcheck`-clean (CI checks it).

Then add a row to the matrix above. Ideas: `nas` (Samba/NFS + disk tooling),
`docker` (Docker + compose), `kiosk` (single-app desktop).
