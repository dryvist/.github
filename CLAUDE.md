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
|---|---|---|
| Runtime | Node.js (current LTS) | `actions/setup-node@v4` in CI |
| Package manager | npm | Universal in CI; lockfile committed |
| Test runner | Vitest | Native ESM/TS; no `ts-jest` dance |
| Lint + format | Biome | Single config (`biome.jsonc`); see `biome.jsonc` in this repo |
| Type check | `tsc --noEmit` | TypeScript strict mode required in `tsconfig.json` |
| Release automation | release-please | Inherited from `JacobPEvans/.github` |
| Dependency updates | Renovate | Extends `JacobPEvans/.github:renovate-presets` |

The canonical `biome.jsonc` lives in this repo at the root. Repos copy it at
scaffold time; periodic sync is handled by Renovate's custom manager (or
manual update for now — see `renovate.json`).

## Inheritance from `JacobPEvans/.github`

We reuse JacobPEvans's reusable workflows directly. Don't fork or wrap them
unless we need behavior they don't provide.

| Need | Inherited from | Caller pattern |
|---|---|---|
| Release-please (with org-wide major-bump block) | `JacobPEvans/.github/.github/workflows/_release-please.yml@main` | See `release-please.yml` in any dryvist repo |
| Renovate presets | `github>JacobPEvans/.github:renovate-presets` | `extends` in `renovate.json` |
| Security policy structure | `JacobPEvans/.github/SECURITY.md` | Adapted/scoped to dryvist (this repo) |

**Inheritance chain:** `JacobPEvans/.github` → `dryvist/.github` → individual
dryvist repos. Re-inheritance works through the same mechanisms (workflow
`uses:` + Renovate `extends:`).

**Prereq for release-please:** the JacobPEvans reusable workflow needs the
GitHub App secrets `GH_ACTION_JACOBPEVANS_APP_ID` + `GH_APP_PRIVATE_KEY`
configured at the org level on `dryvist`. (Owner sets these manually; agent
should not attempt to install the App.)

## Scope of this repo

`dryvist/.github` is **org-wide infrastructure only**. It contains:

- AI assistant policy (this file)
- Org-wide tooling configs (`biome.jsonc`, `renovate.json`)
- Community health files GitHub auto-applies (`SECURITY.md`, `profile/README.md`)
- Caller workflow templates that wire up inherited reusable workflows

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

- Read [`JacobPEvans/.github`](https://github.com/JacobPEvans/.github) for the
  upstream patterns we inherit.
- Read this repo's `biome.jsonc` for current lint/format rules.
- Read [`dryvist/cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template)
  for Cribl-specific test/build scaffolding.
- For release-please specifics, the inherited workflow's docstring at
  `JacobPEvans/.github/.github/workflows/_release-please.yml` is authoritative.
