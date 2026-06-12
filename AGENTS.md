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
| Release automation | release-please | Org-native — `.github/workflows/_release-please.yml` |
| Dependency updates | Renovate | Extends `JacobPEvans/.github:renovate-presets` |

The canonical `biome.jsonc` and `.markdownlint-cli2.yaml` live in this repo at
the root. Repos copy them at scaffold time; periodic sync is handled by
Renovate's custom manager (or manual update for now — see `renovate.json`).

## Release-please (org-native)

Release-please is **org-native** to this repo: every dryvist repo inherits the
reusable `.github/workflows/_release-please.yml@main` here (not a cross-account
JacobPEvans workflow). It eager-auto-merges **every** release PR (patch, minor,
or major) once checks pass — there is no automated major-bump block. A dryvist
repo's `release-please.yml` caller forwards a single secret:

| dryvist org secret | Reusable workflow secret |
| --- | --- |
| `GH_ACTION_RELEASE_PLEASE_PRIVATE_KEY` | `GH_ACTION_RELEASE_PLEASE_PRIVATE_KEY` |

Auth is the dryvist release App: app-id from the `GH_ACTION_RELEASE_PLEASE_APP_ID`
org variable, private key from the `GH_ACTION_RELEASE_PLEASE_PRIVATE_KEY` org
secret. The App must be installed on the org with Contents + Pull requests write.
(Owner sets these manually after installing the App; the agent should not attempt
to install it. See `README.md` for setup steps.)

### Canonical release config

The canonical `release-please-config.json` lives here at
`configs/release-please-config.json` (single source of truth, same model as
`biome.jsonc` / `.markdownlint-cli2.yaml`). Repos copy it; they only diverge when
they **must**, and such deltas are intentional, e.g.:

- `claude-code-plugins` adds `extra-files` to bump its many `plugin.json`
  versions.
- Pre-1.0 / beta repos (e.g. `nix-ai-server`) add `bump-minor-pre-major: true`
  so breaking changes stay in the `0.x` range instead of auto-jumping to `1.0`.

The reusable workflow also supports **config-free (non-manifest) mode** via its
inputs (`release-type` + blank `config-file`/`manifest-file`) for repos that need
no per-repo config at all; manifest mode (with the file above) is the default.
Do not hand-tweak a repo's `release-please-config.json` away from canonical
without a recorded reason.

## Inheritance from `JacobPEvans/.github`

We still reuse a few JacobPEvans community-health and config artifacts directly.
Don't fork or wrap them unless we need behavior they don't provide.

| Need | Inherited from | Caller pattern |
| --- | --- | --- |
| Renovate presets | `github>JacobPEvans/.github:renovate-presets` | `extends` in `renovate.json` |
| Security policy structure | `JacobPEvans/.github/SECURITY.md` | Adapted/scoped to dryvist (this repo) |

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
- For release-please specifics, the org-native workflow's docstring at
  `.github/workflows/_release-please.yml` in this repo is authoritative.
