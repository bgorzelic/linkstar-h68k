---
name: Hardware / firmware report
about: Share specs, a driver fix, or firmware info from your own H68K
title: "[hw] "
labels: hardware
---

**Help us make the docs accurate.** Paste real output — screenshots or command
results beat descriptions.

## Board

- Board label / silkscreen (e.g. "LinkStar H68K", revision):
- RAM / eMMC size (if known):
- Where purchased / approx. date:

## OS

- Image + version (e.g. `ubuntu20.04-v0.0.1`, OpenWRT R22.11.18):
- `cat /etc/os-release` (PRETTY_NAME):
- `uname -a`:

## Useful command output (optional but appreciated)

```bash
# device model
cat /proc/device-tree/model
# storage layout
lsblk -e7 -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
# network interfaces
ip -br link
```

## What are you reporting?

Correction / new spec / driver fix / dead link / other — details:
