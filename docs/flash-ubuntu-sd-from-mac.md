# Flash Ubuntu to the LinkStar H68K from a Mac (no maskrom, no Windows)

<sub>[Home](../README.md) › [Docs](README.md) › Flash from a Mac</sub>

The vendor instructions require Windows + RKDevTool + entering maskrom mode to
write eMMC. **You don't need any of that.** The H68K boots from microSD with
priority, so you can lay the Ubuntu system onto an SD card from a Mac (or Linux)
and boot it directly. This is the recommended path; keep maskrom/eMMC as recovery.

> Why the obvious approach fails: the vendor `.img` is a Rockchip **RKFW**
> container (not a raw disk image — `dd`-ing it produces an unbootable card), and
> its bundled loader is the wrong format for on-disk boot (a **black screen** if
> written naively). The scripts here handle both. See
> [how-it-works.md](how-it-works.md) for the full explanation.

## You need

- A Mac (Apple Silicon or Intel) or a Linux box, with **Docker** installed
  (used to run the x86-64 Rockchip `mkimage` and `sgdisk`).
- A microSD card, **8 GB or larger**, and a reader.
- The vendor firmware (download + verify against [../firmware/README.md](../firmware/README.md)):
  - `ubuntu20.04-...-update(...).img` (the RKFW image)
  - `H68K-Boot-Loader_...bin` (or reuse the loader inside the RKFW)
- These tools, built once (see [how-it-works.md](how-it-works.md#building-the-tools)):
  - `rkdeveloptool` (native build)
  - the `rkbin` repo (for `mkimage`)

## Steps

```bash
# 1. Unpack the RKFW into partition images + parameter.txt
./scripts/unpack-rkfw.sh  ubuntu20.04-...-update.img  ./work/parts

# 2. Rebuild the sector-64 loader (the black-screen fix)
RKDEVELOPTOOL=./rkdeveloptool RKBIN=/path/to/rkbin \
  ./scripts/build-idbloader.sh  H68K-Boot-Loader_...bin  ./work/idbloader.img

# 3. Find your SD device
diskutil list          # macOS  -> e.g. /dev/disk6
# lsblk                # Linux  -> e.g. /dev/sdb

# 4. Write the card (DESTRUCTIVE — double-check the device!)
./scripts/build-sd-image.sh  ./work/parts  ./work/idbloader.img  /dev/disk6
```

Eject, put the card in the H68K's **TF/microSD slot**, and power on. HDMI should
show U-Boot then the LXQT desktop; the box also pulls DHCP on eth0/eth1.

## First boot

```bash
# The rootfs image is ~6.6 GB; grow it to fill the card:
sudo ./scripts/expand-rootfs.sh          # or: sudo resize2fs /dev/mmcblk1p8

# Networking: if you don't get an IP, the image ships conflicting network stacks.
sudo ./scripts/fix-networking.sh         # standardizes on systemd-networkd
```

> **First-boot apt trap:** `unattended-upgrades` runs on first boot and can hang
> on the Ubuntu ESM check while holding the dpkg lock, so manual `apt` fails with
> `Could not get lock`. Mask the auto-updaters before updating:
>
> ```bash
> sudo systemctl mask unattended-upgrades apt-daily.{service,timer} apt-daily-upgrade.{service,timer}
> ```
>
> then `sudo apt-get update && sudo apt-get -y full-upgrade`. The vendor kernel
> lives in `boot.img` (not an apt package), so a full upgrade won't touch it.

## Troubleshooting

| Symptom | Cause | Fix |
| --------- | ------- | ----- |
| Black screen, no boot | Wrong loader at sector 64 | Rebuild with `build-idbloader.sh` (magic must be `RKNS`); re-run step 2–4 |
| Boots but no IP | Three network stacks conflict | `fix-networking.sh` |
| Only ~6 GB free | rootfs not expanded | `expand-rootfs.sh` / `resize2fs` |
| `apt` "Could not get lock" | first-boot unattended-upgrades | mask auto-updaters (above) |
| Can't find it on the LAN | LAN is a **/22**; ping sweeps miss it | `nmap -Pn -p22` across the right CIDR |
