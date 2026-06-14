# Gemini Code Assist style guide — dryvist/.github

Review style guide for the Gemini Code Assist GitHub app (read from
`.gemini/styleguide.md`). Note: the free consumer app is scheduled to shut down
2026-07-17; this file is kept generic and harmless beyond that date. The owned,
durable reviewer is `.github/workflows/pr-review.yml`.

Review pull requests against the org-wide checklist — the single source of truth:

- [`configs/pr-review-checklist.md`](../configs/pr-review-checklist.md)
- [`AGENTS.md`](../AGENTS.md) — dryvist org policy

Prioritize, and keep feedback terse:

1. **Sensitive data** — no real internal domains, hostnames, IPs, credentials, or
   absolute user paths. Placeholders only (`example.com` / `example.local`,
   `192.168.0.*`, `2001:db8::*`).
2. **DRY** — flag duplicated blocks and asymmetric copies.
3. **Side-by-side docs** — behavior/config changes must update adjacent docs.
4. **No suppressed checks** — `eslint-disable`, `# noqa`, `--no-verify`,
   `@ts-ignore`, dismissed CodeQL.
5. **Hygiene** — Conventional Commits, plain-ASCII (no emoji), no hardcoded LLM
   model ids.
