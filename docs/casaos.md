# CasaOS home-server flavor

<sub>[Home](../README.md) › [Docs](README.md) › CasaOS</sub>

[CasaOS](https://casaos.io/) turns the H68K into a **personal cloud / home server** — a
clean web dashboard with a Docker-based app store (Nextcloud, Jellyfin, Home Assistant,
the *arr stack, etc.), file management, and storage pooling. It's the `casaos`
[flavor](../flavors/README.md) of the Ubuntu track.

## Get it

Either way ends with CasaOS running on the box:

- **Build the flavor** — boot the Ubuntu base, then:

  ```bash
  sudo flavors/casaos.sh          # try --dry-run first; installs Docker + CasaOS
  ```

  Then snapshot the SD into a release image (see [flavors/README](../flavors/README.md)).
- **Flash the `ubuntu-casaos-24.04` release image** directly, once it's published.

## First boot

1. Find the device: [`../scripts/discover.sh`](../scripts/discover.sh) (or check your router's lease table).
2. Open **`http://<device-ip>/`** in a browser.
3. Create the admin account on the first visit — that's it.

## Firewall

`harden.sh` denies inbound by default, so keep the dashboard reachable and still lock the
box down:

```bash
sudo scripts/harden.sh --pubkey-file ~/.ssh/authorized_keys --allow-port 80
```

Open an extra `--allow-port` for each app you expose (e.g. `8096` for Jellyfin).

## Storage & networking

- Point CasaOS at **external USB storage** or a large microSD for app data; expand the
  rootfs first ([storage.md](storage.md)).
- As a NAS/media box, CasaOS benefits from the **2.5 GbE** ports — but those need a
  mainline kernel (the vendor 4.19 kernel has the driver bug). On the stock image you may
  be limited to the 1 GbE ports; the [Armbian route](alternative-os.md) gets 2.5 G working.

## Uninstall / revert

CasaOS ships an uninstall script (`casaos-uninstall`), or just re-flash a non-CasaOS
image — the factory eMMC is untouched.

## Links

- CasaOS: <https://casaos.io/> · <https://github.com/IceWhaleTech/CasaOS>
- The flavor script: [`../flavors/casaos.sh`](../flavors/casaos.sh)
