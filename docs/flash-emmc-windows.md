# Flashing to eMMC over USB (Windows & Linux/macOS)

The [SD-from-a-Mac path](flash-ubuntu-sd-from-mac.md) is the easy way to *run* an OS.
But sometimes you want to write the board's **internal eMMC** — a permanent install
that boots with no card inserted, a factory restore, or putting OpenWRT/Android on
internal storage. That's done over **USB in maskrom mode**. This is the thorough guide.

> [!IMPORTANT]
> **Loader formats differ by target.** eMMC flashing uses `MiniLoaderAll.bin` /
> `H68K-Boot-Loader_*.bin` in its native **`LDR `** format (the maskrom download
> loader). That is the *opposite* of the SD path, where sector 64 needs the rebuilt
> **`RKNS`** idbloader. Using the wrong one is the classic black-screen bug.

## eMMC vs microSD — which do you want?

| | microSD | eMMC (this guide) |
|---|---------|-------------------|
| Difficulty | easy (Mac/Linux, no maskrom) | moderate (USB + maskrom) |
| Reversible | pull the card | reflash to undo |
| Boots without a card | no | **yes** |
| Best for | trying an OS, dual-booting via card | permanent install, factory restore |

## What you'll need

- A **USB-C cable** between the H68K's **USB-C port** and your computer (data-capable —
  not a charge-only cable, and **not** a Type-A port on the board).
- Images (download + verify — see [`../firmware/README.md`](../firmware/README.md)):
  - `H68K-Boot-Loader_*.bin` — the bootloader / DDR init the tool loads first.
  - Your target system image: Ubuntu, OpenWRT, or Android `.img`.
  - `LinkStar-H68K-EraseFlash.img` — optional, to fully wipe a bad eMMC first.
- Tooling:
  - **Windows** (documented vendor path): **RKDevTool v2.84** + **Rockchip
    DriverAssistant v5.1.1** (both in the `Flash-to-eMMC-tool` bundle on SourceForge).
  - **Linux/macOS**: `rkdeveloptool` (build notes in
    [how-it-works.md](how-it-works.md#building-the-tools)).

## Step 0 — Enter maskrom mode

<p align="center">
  <img src="../assets/photos/h68k-power.jpg" alt="LinkStar H68K power button and recessed update keyhole" width="49%">
</p>

Maskrom is the RK3568 bootROM's USB recovery mode. To enter it:

1. Power the board **off**.
2. Find the recessed **"Update keyhole"** button; press and hold it with a SIM-eject pin.
3. **While still holding**, connect the **USB-C** cable to your computer.
4. Release after ~2 seconds. The flashing tool should report **"Found One MASKROM Device."**

<sub>Photo © Seeed Studio, CC BY-SA 4.0 — [credits](../assets/photos/CREDITS.md).</sub>

## Windows — RKDevTool (documented vendor path)

1. **Install the driver.** Run `DriverInstall.exe` from Rockchip DriverAssistant →
   *Install Driver*. (If Windows blocks it, allow the unsigned Rockchip USB driver.)
2. **Launch `RKDevTool.exe`.** Put the board in maskrom (Step 0); the status line at the
   bottom should read *Found One MASKROM Device*.
3. **(Optional) wipe first.** If the eMMC is in a bad state, load
   `LinkStar-H68K-EraseFlash.img` and click **EraseFlash**, then re-enter maskrom.
4. **Choose a flashing mode:**
   - **Upgrade Firmware tab** (simplest) — click *Firmware*, select a single combined
     `.img`, then **Upgrade**.
   - **Download Image tab** (partition-by-partition) — tick the rows, set
     **Loader/Boot** = `H68K-Boot-Loader_*.bin` and **System** = your target `.img` at
     its address, then **Run**.
5. Wait for **"Download image OK / Done."**
6. Unplug and power on. First boot may take a minute.

## Linux / macOS — rkdeveloptool

> [!NOTE]
> Seeed only documents the Windows GUI. The commands below are the **standard RK3568
> maskrom pattern** (community-verified, not H68K-specific docs) — treat exact args as
> unverified and confirm against your image.

```bash
# Build the tool once (see how-it-works.md), then with the board in maskrom:
rkdeveloptool ld                          # should list a Maskrom device
rkdeveloptool db  H68K-Boot-Loader_*.bin  # download the bootloader into SRAM
rkdeveloptool ef                          # (optional) erase the whole flash
rkdeveloptool wl 0 <system>.img           # write the system image at sector 0
rkdeveloptool rd                          # reboot
```

For a partitioned image you write each part at its offset (`wl <sector> <part.img>`)
using the offsets from the image's `parameter.txt` (see
[how-it-works.md](how-it-works.md)).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Tool never shows "MASKROM Device" | wrong port or cable | Use the **USB-C** port + a data cable; hold the keyhole while plugging in; try another USB port/hub-less |
| "Found One LOADER Device" instead | board booted normally, not maskrom | Power off and redo Step 0 |
| Driver won't install (Windows) | unsigned Rockchip driver blocked | Allow it in Device Manager, or disable driver-signature enforcement temporarily |
| "Download / Test Device Fail" | bad loader or half-flashed eMMC | Run **EraseFlash** first, then reflash |
| Black screen after flashing | wrong loader format written to boot | For **eMMC** use the `LDR`-format `MiniLoaderAll`/bootloader — *not* the SD `RKNS` idbloader |
| Boots but no network | three-stack race | [`fix-networking.sh`](../scripts/fix-networking.sh) |

## Switching OS or restoring factory (eMMC)

- **Put OpenWRT / Android / Ubuntu on eMMC** — flash the corresponding image as the
  *System* in Step 4 (or `wl` on Linux). Each is a full replacement of internal storage.
- **Factory restore** — `EraseFlash`, then flash the vendor image you want back.
- **Undo an eMMC experiment** — there's no "pull the card"; you reflash. Keep a copy of
  the vendor images (checksummed) so you can always get back to a known-good state.

## See also

- [flash-ubuntu-sd-from-mac.md](flash-ubuntu-sd-from-mac.md) — the no-maskrom SD path.
- [flashing-and-recovery.md](flashing-and-recovery.md) — all paths at a glance.
- [how-it-works.md](how-it-works.md) — the boot chain, RKFW internals, and building tools.
