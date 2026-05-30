# dryvist org standards (AI assistant policy)

This file is the canonical AI-assistant guidance for the **dryvist** GitHub
org. It applies to every repo under <https://github.com/dryvist>. Repo-level
`CLAUDE.md` files may extend or specialize, but **MUST NOT** contradict the
rules below.

## Language policy: TypeScript everywhere

All code we write is **TypeScript** unless a runtime forces otherwise.
This includes:

- Test harnesses (Vitest)
- Custom GitHub Actions (`@actions/core` + TypeScript)
- CLIs and tools we author
- Scripts that ship as committed artifacts

Configs stay in their natural format: YAML for GitHub Actions workflows,
JSONC (`biome.jsonc`) where comments help, plain JSON where the consumer
demands it (e.g. `release-please-config.json`). Cribl pack content
(`default/`, `data/samples/`, `tests/fixtures/`) is JSON/YAML, not code.

**Rationale:** ecosystem alignment with our GitHub Actions, Cribl pack
expressions (which are JavaScript), and the broader 2026 dev ecosystem.
Python is not used for new dryvist work.

## Tooling baseline

| Concern | Tool | Notes |
| --- | --- | --- |
| Runtime | Node.js (current LTS) | `actions/setup-node@v4` in CI |
| Package manager | npm | Universal in CI; lockfile committed |
| Test runner | Vitest | Native ESM/TS; no `ts-jest` dance |
| Code lint/format | Biome | `biome.jsonc` in this repo; `lineWidth: 100` for JS/TS/JSON/CSS |
| Markdown lint | markdownlint-cli2 | `.markdownlint-cli2.yaml` in this repo; `MD013 line_length: 160` |
| Type check | `tsc --noEmit` | TypeScript strict mode in `tsconfig.json` |
| Release automation | release-please | Inherited from `JacobPEvans/.github` |
| Dependency updates | Renovate | Extends `JacobPEvans/.github:renovate-presets` |

The canonical `biome.jsonc` and `.markdownlint-cli2.yaml` live in this repo at
the root. Repos copy them at scaffold time; periodic sync is handled by
Renovate's custom manager (or manual update for now — see `renovate.json`).

## Workflow library ownership (migration in progress)

`dryvist/.github` is becoming the **source of truth** for the shared workflow
library. `JacobPEvans-personal/.github` is being reduced to a consumer —
inheritance flows dryvist → JacobPEvans-personal, never the reverse. Each
workflow migrates atomically: it lands here, all consumers flip their
`uses:` to point at this repo, then the source in
`JacobPEvans-personal/.github` is deleted.

When adding a new shared workflow (one that more than one repo will call),
write it here. Don't add it to `JacobPEvans-personal/.github`. Existing
`uses: JacobPEvans-personal/.github/.github/workflows/_*.yml@main` references
should be flipped to `uses: dryvist/.github/.github/workflows/<name>.yml@main`
the next time they're touched, even if their workflow isn't formally
migrated yet.

Sourced from this repo (`dryvist/.github`) — Required Workflows attached
via `terraform-github`; no per-repo caller needed:

- `file-size` — workflow at `.github/workflows/file-size.yml`, logic in
  `.github/scripts/file-size-check.sh`, defaults in
  `.github/file-size-defaults.yml`.
- `markdownlint` — workflow at `.github/workflows/markdownlint.yml`,
  config in `.markdownlint-cli2.yaml` at the repo root.

Still inherited from `JacobPEvans-personal/.github` (pending migration
into this repo):

- Release-please — `_release-please.yml@main`. Per-repo caller
  `release-please.yml` forwards `GH_APP_ID` / `GH_APP_PRIVATE_KEY`
  secrets (see Prereq below).
- Renovate presets — extends
  `github>JacobPEvans-personal/.github:renovate-presets` in
  `renovate.json`.
- Security policy structure — `SECURITY.md` template, scoped and
  adapted in this repo.

Older docs and PR templates may still use the redirect-friendly
`JacobPEvans/<repo>` form. Don't mass-rewrite those — see `~/CLAUDE.local.md`
for the redirect rules.

**Prereq for release-please:** the inherited workflow needs a GitHub App
token at runtime. dryvist exposes two generic org-level secrets — caller
workflows in each dryvist repo forward them to the inherited workflow at the
boundary (the inherited workflow's `secrets:` block is JACOBPEVANS-named for
historical reasons; dryvist consumers see only the generic names):

| dryvist org secret | Forwards to inherited secret |
| --- | --- |
| `GH_APP_ID` | `GH_ACTION_JACOBPEVANS_APP_ID` |
| `GH_APP_PRIVATE_KEY` | `GH_APP_PRIVATE_KEY` |

(Owner sets these manually after installing the App on the dryvist org;
agent should not attempt to install the App. See `README.md` for setup
steps.)

## Scope of this repo

`dryvist/.github` is **org-wide infrastructure only**. It contains:

- AI assistant policy (this file)
- Org-wide tooling configs (`biome.jsonc`, `renovate.json`)
- Community health files GitHub auto-applies (`SECURITY.md`, `profile/README.md`)
- The shared workflow library (`.github/workflows/*.yml`) — Required
  Workflows referenced by org rulesets in `terraform-github`, plus
  reusables that any dryvist repo can opt into with `uses:`
- Bash/POSIX implementations of workflow steps (`.github/scripts/*.sh`) —
  extracted from workflow YAML per the no-scripts rule; ship as
  committed artifacts with `+x` in the index
- Workflow defaults (`.github/<name>-defaults.yml`) — no magic numbers in
  workflow YAML or scripts; thresholds and lists live in these dedicated
  files, consumed via `yq`

It does **NOT** contain anything vendor- or product-specific. Cribl pack
infrastructure lives in [`dryvist/cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template).
Future vendor packs (if any) get their own template repo — never `.github`.

## Workflow expectations

For every change in dryvist:

1. Refresh the repo and create a worktree before making changes (per the
   user's global workflow guidance).
2. Edits go through PRs — no direct commits to `main`.
3. CI must be green before merge. Use `gh pr checks --watch` to confirm.
4. Don't tag versions yourself; the user controls release timing.
5. Conventional commits (`fix:`, `feat:`, `chore:`, etc.) — release-please
   uses these to compute bumps.

## When in doubt

- Read [`JacobPEvans-personal/.github`](https://github.com/JacobPEvans-personal/.github)
  for patterns still inherited from there (mostly release-please and Renovate
  presets, pending migration into this repo).
- Read this repo's `biome.jsonc` for current lint/format rules.
- Read [`dryvist/cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template)
  for Cribl-specific test/build scaffolding.
- For release-please specifics, the (still-)inherited workflow's docstring at
  `JacobPEvans-personal/.github/.github/workflows/_release-please.yml` is
  authoritative until that workflow migrates here.
