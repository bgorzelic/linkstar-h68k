# USB serial console (debug boot hangs)

<sub>[Home](../README.md) › [Docs](README.md) › Serial console</sub>

When the H68K **won't boot** — black screen, hang, reboot loop, or a service stalling
early — the serial console is how you see *why*. It prints the entire boot log (U-Boot →
kernel → init → services) before the network or SSH ever come up, so it works even when
nothing else does. This is the tool that pinned the `wifi-audit` first-boot hang.

## What you need

- A **3.3 V USB-to-TTL UART adapter** (CP2102, CH340, or FTDI FT232 — **must be 3.3 V**, not
  5 V, or you can damage the SoC).
- Three jumper wires (GND, RX, TX).
- A serial terminal on your computer: `screen`, `minicom`, `picocom`, or PuTTY.

## Wiring — RK3568 debug UART (UART2)

The H68K exposes the RK3568 debug UART on a 3-pin header (**GND / TX / RX**). Connect the
adapter **crossed** — the board's TX goes to the adapter's RX and vice-versa — and share GND:

| Adapter | ↔ | H68K header |
|---------|---|-------------|
| GND | — | GND |
| RX  | ← | TX |
| TX  | → | RX |

> [!IMPORTANT]
> **Do not connect the adapter's VCC/3V3/5V pin.** The board is powered by its own supply;
> only GND, RX, TX. Crossing power rails can damage the board or the adapter.
> If you see nothing, swap RX↔TX (the most common mistake).

## Connect

The RK3568 debug console runs at **1500000 baud** (`ttyS2` in Linux, `console=ttyS2` in the
kernel cmdline), **8N1, no flow control**. Pick your OS below. In all three, the move is the
same: install the adapter driver → find the port → open it at 1500000 → power-cycle the board
and read the boot log.

### 🍎 macOS

```bash
# 1. Driver: CP2102 works on modern macOS with no driver. CH340 usually needs one:
brew install --cask wch-ch34x-usb-serial-driver   # only if a CH340 adapter isn't detected
# 2. A terminal program:
brew install picocom                               # (or use built-in `screen`)
# 3. Find the adapter's device node (name depends on the chip):
ls /dev/tty.usbserial-* /dev/tty.wchusbserial* /dev/tty.SLAB_USBtoUART 2>/dev/null
# 4. Connect at 1.5 Mbaud:
picocom -b 1500000 /dev/tty.usbserial-XXXX         # exit: Ctrl-A Ctrl-X
screen /dev/tty.usbserial-XXXX 1500000             # alt; exit: Ctrl-A then \
```

> macOS Sequoia may prompt to **Allow** the USB serial accessory the first time —
> approve it in System Settings → Privacy & Security.

### 🪟 Windows

1. **Driver:** install the adapter's driver if Windows doesn't auto-detect it —
   [CP210x (Silicon Labs)](https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers)
   or [CH340 (WCH)](https://www.wch-ic.com/downloads/CH341SER_EXE.html).
2. **Find the COM port:** Device Manager → *Ports (COM & LPT)* → note e.g. `COM5`.
3. **Terminal:** [PuTTY](https://www.putty.org/) or [Tera Term](https://teratermproject.github.io/).
   - PuTTY: *Session* → **Serial**, Serial line `COM5`, Speed **1500000** → *Open*.
   - Tera Term: *Setup ▸ Serial port* → Port `COM5`, Speed `1500000`, 8/N/1, flow control *none*.
4. Power-cycle the board and watch the log.

### 🐧 Linux

```bash
# 1. Driver: cp210x / ch341 are in-kernel — usually nothing to install. Confirm the port:
dmesg | grep -iE 'cp210x|ch341|ftdi|ttyUSB' | tail   # → e.g. "ttyUSB0"
ls /dev/ttyUSB* /dev/ttyACM*
# 2. Permissions: add yourself to the dialout group (once), then re-login:
sudo usermod -aG dialout "$USER"                     # or: sudo the terminal command
# 3. Terminal (any one):
picocom -b 1500000 /dev/ttyUSB0                       # exit: Ctrl-A Ctrl-X
minicom -D /dev/ttyUSB0 -b 1500000                    # exit: Ctrl-A X
screen /dev/ttyUSB0 1500000                           # exit: Ctrl-A then \
```

## Capture a boot log to a file

With the terminal attached, **power-cycle the board** and let the whole boot scroll. Save it
so you can search the tail for the stall:

| OS | Capture to a file |
|----|-------------------|
| **macOS / Linux** | `picocom -b 1500000 --logfile boot.log /dev/<port>` — or with screen: `Ctrl-A H` starts logging to `screenlog.0` |
| **Linux (no terminal app)** | `stty -F /dev/ttyUSB0 1500000 raw && cat /dev/ttyUSB0 \| tee boot.log` |
| **Windows (PuTTY)** | *Session ▸ Logging* → **All session output** → pick a file, *before* opening the connection |

Read the tail: the **last service or message before it goes quiet is the culprit**. On OpenWrt
you'll see `procd` starting each init script — a boot that hangs on a service line
(e.g. `mwan3`, `collectd`, `watchcat`) points straight at it. That's exactly how the
`wifi-audit` boot hang was pinned; the fix ships those services disabled by default.

## Common finds

| Symptom in the log | Likely cause | Fix |
|--------------------|--------------|-----|
| Hang after a specific `/etc/init.d/<svc>` line | a service stalling on config/connectivity | disable it by default (see [../spookywrt/wifi-audit/firstboot.sh](../spookywrt/wifi-audit/firstboot.sh) — the `wifi-audit` variant ships these services-off) |
| Reboot loop | `watchcat` watchdog misconfigured | disable `watchcat` until configured |
| Stops at `Starting kernel ...` | wrong/black-screen loader | rebuild the RKNS idbloader ([how-it-works.md](how-it-works.md)) |
| Nothing at all on the console | RX/TX swapped, wrong baud, or 5 V adapter | swap RX↔TX, confirm 1500000, use a 3.3 V adapter |

## Recovery is always a re-flash

The microSD boots before eMMC, so a hung image is never a brick: pull/re-flash the card.
The serial console tells you *what* to fix so the next image boots clean.

## See also

- [flashing-and-recovery.md](flashing-and-recovery.md) · [how-it-works.md](how-it-works.md)
- [known-issues.md](known-issues.md) — the boot-time `apt`/service traps on the Ubuntu track
