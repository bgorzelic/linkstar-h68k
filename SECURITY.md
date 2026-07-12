# Security Policy

This project ships **scripts and documentation** for the LinkStar H68K, and it
documents the insecure defaults in the *vendor* image (see
[docs/known-issues.md](docs/known-issues.md)).

## Reporting a vulnerability in this project

If you find a security issue in our **scripts** (`harden.sh`, the first-boot overlay,
the `build-*` tools) or a dangerous error in the docs:

- Prefer a **private report** — GitHub → *Security* → *Advisories* → *Report a
  vulnerability*; or
- Open a regular issue if it's low-risk or already public.

Please include what you ran, the output, and the impact. We aim to respond promptly.

## Vulnerabilities in the vendor firmware

Issues in the Seeed/Rockchip firmware itself are theirs to fix — report those to
Seeed Studio. We document the known ones (unauthenticated network ADB, cleartext FTP,
image-shared SSH host keys, default passwords) and how to remediate them in
[docs/known-issues.md](docs/known-issues.md) and [docs/hardening.md](docs/hardening.md).

## Supported versions

This is a community project; fixes land on `main`. Use the latest.

## Hardening reminder

The stock image is **insecure by default**. Before putting a unit on an untrusted
network, run `scripts/harden.sh`, change the default passwords, and regenerate the
SSH host keys (the [first-boot overlay](firstboot/README.md) automates the last two).
