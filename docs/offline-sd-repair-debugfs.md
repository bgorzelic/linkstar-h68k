# Offline SD diagnosis & repair from a Mac/Linux with `debugfs`

<sub>[Home](../README.md) › [Docs](README.md) › Offline SD repair</sub>

When an H68K upgrade leaves the box unbootable (or booting to emergency mode) and you can't get a
console on it, you can **read and surgically edit its ext4 rootfs from another machine** — without a
Linux box, without mounting (macOS can't mount ext4), and without imaging the whole 100+ GB partition.
This saved the 24.04 upgrade. Technique = `debugfs` from `e2fsprogs`.

## Why this works

- macOS can't mount ext4, and Docker Desktop can't pass the physical SD device into its Linux VM, and
  the rootfs partition is too big to `dd` to an image.
- **`debugfs` reads/writes an unmounted ext4 filesystem directly on the raw device** — no mount needed.
- Install: `brew install e2fsprogs` → `debugfs` at `/opt/homebrew/opt/e2fsprogs/sbin/debugfs`.

## Find the rootfs partition

Insert the card; `diskutil list`. The H68K layout puts **rootfs as the last, largest partition**
(`disk6s8` in our case). Use the **raw** node for speed: `/dev/rdisk6s8`.

## Diagnose (read-only — debugfs opens read-only by default)

```bash
DBG=/opt/homebrew/opt/e2fsprogs/sbin/debugfs; DEV=/dev/rdisk6s8
sudo $DBG -R "show_super_stats -h" $DEV | grep -i "state"      # 'clean' = fs itself is fine
sudo $DBG -R "cat /usr/lib/os-release" $DEV | grep PRETTY      # what version it reached
sudo $DBG -R "cat /var/lib/dpkg/status" $DEV | grep -c "install ok unpacked"  # unconfigured pkgs
sudo $DBG -R "cat /var/log/dist-upgrade/main.log" $DEV | tail  # why an upgrade aborted
sudo $DBG -R "cat /var/log/kern.log" $DEV | grep -iE "eth|end|Link is|carrier"  # NIC name + link state
# check a package's config state:
sudo $DBG -R "cat /var/lib/dpkg/status" $DEV | awk '/^Package: netplan.io$/{f=1} f&&/^Status:/{print;exit}'
```

This alone tells you: did it reach the target release, how many packages are unconfigured, *which*
package aborted it, whether the NIC has link, and what it's named.

## Repair option A — inject a one-shot self-repair service (hands-off)

Write a systemd oneshot that finishes the upgrade on next boot, then self-deletes and reboots. Requires
the box to reach `multi-user.target` (it won't fire from emergency mode). `debugfs` supports `write`
(copy a local file in) and `symlink`:

```bash
cat > /tmp/dbg-cmds <<EOF
write /tmp/finish-upgrade.sh          /etc/finish-upgrade.sh
write /tmp/finish-upgrade.service     /etc/systemd/system/finish-upgrade.service
symlink /etc/systemd/system/multi-user.target.wants/finish-upgrade.service /etc/systemd/system/finish-upgrade.service
quit
EOF
sudo $DBG -w -f /tmp/dbg-cmds $DEV      # -w = write mode
# verify it landed:
sudo $DBG -R "cat /etc/systemd/system/finish-upgrade.service" $DEV
```

The script should `dpkg --purge --force-all firefox`, `dpkg --configure -a`, re-assert networking,
remove itself, and reboot. See `scripts/finish-upgrade.sh` in this repo.
> `debugfs` prints a harmless `ext2fs_close: Invalid argument` on quit against a raw macOS device —
> the writes still commit. **Always verify by reading the files back.**

## Repair option B — fix networking config offline (name-independent)

If the box boots but has no network (24.04 renamed the NIC), drop in a networkd rule that DHCPs *any*
wired port regardless of name:

```bash
cat > /tmp/05-dhcp-all.network <<'EOF'
[Match]
Name=en* eth* end*
[Network]
DHCP=ipv4
[Link]
RequiredForOnline=no
EOF
printf 'write /tmp/05-dhcp-all.network /etc/systemd/network/05-dhcp-all.network\nquit\n' \
  | sudo $DBG -w -f /dev/stdin $DEV
```

## Hard limits (be honest)

- You **cannot run `dpkg`/`apt`** offline this way — that needs the target's ARM Linux userland with
  the rootfs as root (Docker-on-Mac can't reach the device; the partition's too big to image). So the
  actual package configuration must run **on the device** (console) or via the injected self-repair.
- The auto-repair only fires if boot reaches `multi-user.target`. If it drops to **emergency mode**,
  you must run the fix at the HDMI console.
- **Flaky USB SD readers will drop the card mid-operation** — which can corrupt ext4 on a write. If a
  reader keeps disconnecting, stop writing to it and use the on-device console instead.

## The safest recovery is still re-flash

microSD boots first, so if offline repair is more trouble than it's worth: re-flash the card and
re-apply your changes. Nothing here is ever a brick.
