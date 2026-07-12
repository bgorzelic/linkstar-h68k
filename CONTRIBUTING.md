# Contributing

Thanks for helping make the LinkStar H68K actually documented. This project lives
or dies on **accuracy**, so the bar is simple:

## The one rule: cite or label

- **Facts get a source.** A wiki link, a forum thread, a datasheet, or "verified
  on my own unit (paste the command + output)." Hardware specs especially.
- **Guesses get labeled.** If you're not sure, write `> [!WARNING] Unverified:` and
  say so. A flagged unknown is useful; a confident wrong answer is not.
- Docs distinguish **[OFFICIAL]** (Seeed/Rockchip), **[COMMUNITY]**, and
  **[VERIFIED-ON-HARDWARE]** claims. Keep that convention.

## What we love

- Corrections to wrong specs or dead links.
- Fixes/workarounds for the known driver issues (Wi-Fi, 2.5 G NICs, LED).
- New hardware revisions or sibling boards (H66K, H68K-D, etc.).
- Tested improvements to the scripts.

## Scripts

- Bash, `#!/usr/bin/env bash`, `set -euo pipefail`, quoted variables, `[[ ]]` tests.
- Must pass `shellcheck` cleanly and `bash -n` (a CI workflow checks both).
- Keep them **idempotent** and offer a `--dry-run` where they change a device.
- No secrets, ever. Take keys/passwords as arguments or prompts, not literals.

## Firmware

- **Do not commit image files** (`*.img`, `*.zip`, `*.bin`). They're blocked by
  `.gitignore`. Add an entry to `firmware/README.md` + `firmware/SHA256SUMS` instead.
- New mirrors are welcome; always keep the original Seeed source attributed.

## Pull requests

1. Branch (`fix/…`, `docs/…`, `feat/…`).
2. Make the change; run `shellcheck scripts/**/*.sh` if you touched scripts.
3. Open a PR describing what you changed and how you verified it.

Small PRs merge fast. Thank you!
