# Proposal: `spooky-agent` — lightweight Claude Code for the router (one brain, two faces)

Staged: **`scripts/spooky-agent`** (python3, stdlib only) + **`scripts/spooky-agent.conf.example`**.
A router-native agent: system prompt + 8 read-only tools + an OpenAI-compatible LLM (OpenRouter) with
tool-calling. Both frontends call the SAME core so CLI and WebUI share behavior.

## Two faces, one core

- **CLI**: run `spooky-agent` (REPL). Wire it into the `spooky` control shell as `spooky chat` → `exec spooky-agent`.
- **WebUI**: call `spooky-agent ask "<question>"` — it prints the final answer to stdout (one-shot). The
  dashboard chat panel shells out to that (or, later, we add a `--json`/socket mode + ubus wrapper for
  streaming). Same tools, same guardrails.

## Backend

OpenAI-compatible `/chat/completions` with `tools`. Config `/etc/spooky-agent.conf` (api_key/model/base_url).
Default OpenRouter + `anthropic/claude-3.5-sonnet` (literally lightweight Claude Code). Works with any
OpenAI-compatible endpoint — incl. pointing at the SpookyJuice `intelligence` brain later.

## Tools (v1 = READ-ONLY, safe)

router_status · wifi_status · list_clients · uci_show(section) · logread_grep(pattern) · ping_test(host)
· vpn_status · run_diag. Parameterized tools are input-validated + run WITHOUT a shell (no injection).

## Next (v2 — write-actions behind guardrails)

Add gated write tools (uci_set/commit, service restart, spooky-vpn/capture actions) that require an
explicit confirm and run under the existing rollback-timer — mirror spooky-setup's safety. Add an
audit-log tool call. Keep the "cannot-do" truthfulness pattern from SpookyJuice's identity.

## Packaging

Needs `python3` on the box (~10 MB) — add to build.py (flagship or an `--profile ai`). Ship `spooky-agent`
to /usr/bin via first-boot; drop `spooky-agent.conf.example` → `/etc/`.
