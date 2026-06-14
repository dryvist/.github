# GitHub Copilot instructions — dryvist/.github

Repository custom instructions for GitHub Copilot. Copilot reads this file
per-repo; it does not propagate org-wide and only takes effect for accounts with
an active Copilot seat. The authoritative, tool-agnostic rules live elsewhere and
are enforced in CI regardless of Copilot — this file just points Copilot at them.

## When reviewing or generating changes

Follow, in order of authority:

1. [`AGENTS.md`](../AGENTS.md) — dryvist org AI-assistant policy (TypeScript
   everywhere, tooling baseline, release-please, scope).
2. [`configs/pr-review-checklist.md`](../configs/pr-review-checklist.md) — the
   org-wide PR review checklist (what every PR is checked for).

## Non-negotiables (see the checklist for the full list)

- Never commit real sensitive values (internal domains, hostnames, IPs,
  credentials, absolute user paths). Use placeholders: `example.com` /
  `example.local`, `192.168.0.*`, `2001:db8::*`.
- No duplication (DRY); update side-by-side docs in the same change.
- Never suppress a lint/CodeQL check (`eslint-disable`, `# noqa`, `--no-verify`,
  `@ts-ignore`) — fix the code or fix the check.
- Conventional Commits, plain-ASCII subjects (no emoji).
- Don't hardcode LLM model ids — parametrize them.
