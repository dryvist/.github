# dryvist org standards (AI assistant policy)

Canonical AI-assistant guidance for the **dryvist** GitHub org. Applies to
every repo under <https://github.com/dryvist>. Repo-level `AGENTS.md` files
may extend or specialize, but **MUST NOT** contradict the rules below.

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

## Inheritance from `JacobPEvans/.github`

We reuse JacobPEvans's reusable workflows directly. Don't fork or wrap them
unless we need behavior they don't provide.

| Need | Inherited from | Caller pattern |
| --- | --- | --- |
| Release-please (org-wide major-bump block) | `JacobPEvans/.github/.github/workflows/_release-please.yml@main` | `release-please.yml` in any dryvist repo |
| Renovate presets | `github>JacobPEvans/.github:renovate-presets` | `extends` in `renovate.json` |
| Security policy structure | `JacobPEvans/.github/SECURITY.md` | Adapted/scoped to dryvist (this repo) |

**Inheritance chain:** `JacobPEvans/.github` → `dryvist/.github` → individual
dryvist repos. Re-inheritance works through the same mechanisms (workflow
`uses:` + Renovate `extends:`).

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
