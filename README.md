# dryvist/.github

Org-wide standards and inheritance hub for the [dryvist](https://github.com/dryvist)
GitHub organization. Contains AI assistant policy, lint/format config,
dependency-management config, security policy, and the org profile page.

This repo holds **only** vendor-agnostic org infrastructure. Cribl-specific
test harnesses and reusable workflows live in
[`dryvist/cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template).

## Installation

This repo is consumed by reference, not installed. Other dryvist repos
inherit configs and policies via the mechanisms below.

| Inheritance mechanism | Where it shows up |
|---|---|
| GitHub auto-applied org files (`SECURITY.md`, `profile/README.md`) | Visible on every dryvist repo's Security tab + at <https://github.com/dryvist> |
| Renovate `extends` | `renovate.json` in each repo: `extends: github>JacobPEvans/.github:renovate-presets` (this repo's `renovate.json` is the example) |
| Biome config | Each repo carries a copy of `biome.jsonc` scaffolded from this repo; Renovate keeps it in sync |
| AI assistant policy | `CLAUDE.md` — read by Claude Code on every session |

## Usage

### Add the org standards to a new dryvist repo

For a new TS-based dryvist repo, copy the canonical configs from this repo:

```sh
# From the new repo's root:
gh api repos/dryvist/.github/contents/biome.jsonc --jq '.content' | base64 -d > biome.jsonc
gh api repos/dryvist/.github/contents/renovate.json --jq '.content' | base64 -d > renovate.json
```

If the repo is a Cribl pack, scaffold from
[`dryvist/cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template)
instead — the template already includes the canonical configs.

### Wire up release-please in a dryvist repo

Each repo needs `.release-please-manifest.json` + `release-please-config.json`
plus a thin caller workflow that delegates to the inherited reusable workflow:

```yaml
# .github/workflows/release-please.yml
name: release-please
on:
  push:
    branches: [main]
permissions:
  contents: write
  pull-requests: write
jobs:
  release-please:
    uses: JacobPEvans/.github/.github/workflows/_release-please.yml@main
    secrets:
      GH_ACTION_JACOBPEVANS_APP_ID: ${{ secrets.GH_ACTION_JACOBPEVANS_APP_ID }}
      GH_APP_PRIVATE_KEY: ${{ secrets.GH_APP_PRIVATE_KEY }}
```

Org-level secret prereqs (one-time, owner-handled):

- `GH_ACTION_JACOBPEVANS_APP_ID`
- `GH_APP_PRIVATE_KEY`

These are the same secrets the upstream JacobPEvans org uses. Set them at
`https://github.com/organizations/dryvist/settings/secrets/actions` after
installing the corresponding GitHub App on the dryvist org.

## API

This repo exposes the following inheritance surfaces:

| Path | Purpose |
|---|---|
| `CLAUDE.md` | AI assistant policy (read by Claude Code) |
| `biome.jsonc` | Canonical Biome lint + format config |
| `renovate.json` | Org-default Renovate extending JacobPEvans presets |
| `SECURITY.md` | Org-wide vulnerability reporting policy (auto-applied to every dryvist repo's Security tab) |
| `profile/README.md` | Org profile page at <https://github.com/dryvist> |

## Contributing

Changes here affect every dryvist repo. Tread carefully:

- Bump rules in `biome.jsonc` cautiously — they cascade to every repo on next sync.
- Don't introduce vendor-specific (Cribl, etc.) content. That belongs in the relevant template repo.
- Conventional commits required (`feat:`, `fix:`, `chore:`, `docs:`).

To validate locally before pushing:

```sh
# Lint this repo's own files (requires Biome installed locally)
npx -y @biomejs/biome check .
```

## License

[Apache-2.0](LICENSE).

## References

- [`JacobPEvans/.github`](https://github.com/JacobPEvans/.github) — upstream org we inherit from
- [`dryvist/cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template) — Cribl pack template
- [Biome configuration reference](https://biomejs.dev/reference/configuration/)
- [Renovate `extends` docs](https://docs.renovatebot.com/config-presets/)
- [release-please-action](https://github.com/googleapis/release-please-action)
