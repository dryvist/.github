# dryvist/.github

Org-wide standards and inheritance hub for the [dryvist](https://github.com/dryvist)
GitHub organization. Contains AI assistant policy, lint/format config,
dependency-management config, security policy, and the org profile page.

This repo holds **only** vendor-agnostic org infrastructure. Cribl-specific
test harnesses and reusable workflows live in
[`dryvist/cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template).

## Requirements

### Prerequisites & OS Requirements

- **dryvist Organization**: This repository provides org-level configurations and templates designed for the `dryvist` GitHub organization.
- **tofu-github Configuration**: The organization configuration, permissions,
  and secrets (such as the release-please App credentials) are managed and
  provisioned by the [dryvist/tofu-github](https://github.com/dryvist/tofu-github)
  repository.
- **OS Compatibility**: Fully compatible with macOS and Linux environments.

### Optional Enhancements

- **Nix & direnv**: Recommended for automatic developer environment activation using the provided Nix flakes.

## Installation

This repo is consumed by reference, not installed. Other dryvist repos
inherit configs and policies via the mechanisms below.

Example Renovate configuration to inherit these presets:

```json
{
  "extends": ["local>dryvist/.github"]
}
```

| Inheritance mechanism | Where it shows up |
| --- | --- |
| GitHub auto-applied org files (`SECURITY.md`, `profile/README.md`) | Visible on every dryvist repo's Security tab + at <https://github.com/dryvist> |
| Renovate `extends` | Each repo: `extends: ["config:recommended", "local>dryvist/.github"]` — this repo is the **master** (extends nothing external) |
| Biome config | Each repo carries a copy of `biome.jsonc` scaffolded from this repo; Renovate keeps it in sync |
| markdownlint config | Each repo carries a copy of `.markdownlint-cli2.yaml` from this repo; sync TBD (manual for now) |
| Pre-commit hooks (shared) | `precommit/` — Nix flake import or static YAML copy; see [`precommit/README.md`](precommit/README.md) |
| Default `.gitignore` | Each repo appends `configs/gitignore` into its `.gitignore` at scaffold; secrets + AI-local-state baseline; sync TBD (manual for now) |
| AI assistant policy | `CLAUDE.md` — read by Claude Code on every session |

## Usage

### Add the org standards to a new dryvist repo

For a new TS-based dryvist repo, copy the canonical configs from this repo:

```sh
# From the new repo's root (raw content via Accept header — no base64
# decoding, portable across macOS and Linux):
gh api repos/dryvist/.github/contents/biome.jsonc -H "Accept: application/vnd.github.raw" > biome.jsonc
gh api repos/dryvist/.github/contents/.markdownlint-cli2.yaml -H "Accept: application/vnd.github.raw" > .markdownlint-cli2.yaml
gh api repos/dryvist/.github/contents/renovate.json -H "Accept: application/vnd.github.raw" > renovate.json
# Default .gitignore baseline (secrets + AI local state) — append, then de-dupe:
gh api repos/dryvist/.github/contents/configs/gitignore -H "Accept: application/vnd.github.raw" >> .gitignore
```

If the repo is a Cribl pack, scaffold from
[`dryvist/cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template)
instead — the template already includes the canonical configs.

### Wire up release-please in a dryvist repo

Each repo needs `.release-please-manifest.json` + `release-please-config.json`
plus a thin caller workflow that delegates to the org-native reusable workflow:

```yaml
# .github/workflows/release-please.yml
name: Release Please
on:
  push:
    branches: [main]
permissions: {}
jobs:
  release-please:
    permissions:
      contents: write
      pull-requests: write
    uses: dryvist/.github/.github/workflows/_release-please.yml@main
    secrets:
      GH_ACTION_RELEASE_PLEASE_PRIVATE_KEY: ${{ secrets.GH_ACTION_RELEASE_PLEASE_PRIVATE_KEY }}
```

The reusable workflow blocks automated major bumps and eager-auto-merges the
release PR. Pass `with: { auto-merge: false }` to opt a repo out of auto-merge.

Org-level prereqs (one-time, owner-handled) for the dryvist release App:

- `GH_ACTION_RELEASE_PLEASE_APP_ID` — App ID (org **variable**, numeric)
- `GH_ACTION_RELEASE_PLEASE_PRIVATE_KEY` — App private key PEM (org **secret**)

### One-time GitHub App setup (owner-handled)

1. Locate the App owned by JacobPEvans (`https://github.com/settings/apps` or
   `https://github.com/organizations/JacobPEvans/settings/apps`).
2. Verify "Where can this GitHub App be installed?" is set to "Any account"
   (change + save if currently "Only on this account").
3. Visit the App's public install URL (`https://github.com/apps/<app-slug>/installations/new`)
   and install on the **dryvist** org with access to "All repositories".
4. Back in the App settings: copy the App ID; generate + download a private
   key `.pem` (cannot be re-downloaded).
5. Set the dryvist org secrets:

   ```sh
   gh secret set GH_APP_ID --org dryvist --visibility all
   gh secret set GH_APP_PRIVATE_KEY --org dryvist --visibility all < /path/to/private-key.pem
   ```

   Or via UI at <https://github.com/organizations/dryvist/settings/secrets/actions>.

## API

This repo exposes the following inheritance surfaces:

| Path | Purpose |
| --- | --- |
| `CLAUDE.md` | AI assistant policy (read by Claude Code) |
| `biome.jsonc` | Canonical Biome lint + format config (code) |
| `.markdownlint-cli2.yaml` | Canonical markdownlint-cli2 config (`.md` files) |
| `renovate.json` | Org-default Renovate entry point (master; extends only `config:recommended` + local presets) |
| `renovate-presets.json` | Master Renovate policy: auto-merge, trusted orgs, custom managers |
| `renovate-grouping.json` | Master Renovate ecosystem-grouping rules |
| `precommit/` | Shared pre-commit layer (canonical lint configs + static YAML templates); see [`precommit/README.md`](precommit/README.md) |
| `zizmor.yml` | Org-wide zizmor workflow-security policy (referenced by the pre-commit `zizmor` hook) |
| `.github/workflows/_*.yml` | Reusable CI workflows, consumed via `uses: dryvist/.github/.github/workflows/<file>@main` |
| `configs/` | Shared configs the reusable workflows fetch at runtime (e.g. `_markdown-lint`'s org-default fallback) |
| `configs/gitignore` | Org-default `.gitignore` baseline (secrets, credentials, TF state, AI-assistant local state); appended per repo at scaffold |
| `scripts/` | Shell helpers the reusable workflows sparse-checkout (`ci-gate-watchdog.sh`, `run-pip-audit.sh`) |
| `osv-scanner.toml` | Org-wide OSV ignore list inherited via `_osv-scan.yml` (a repo-local copy takes precedence) |
| `SECURITY.md` | Org-wide vulnerability reporting policy (auto-applied to every dryvist repo's Security tab) |
| `profile/README.md` | Org profile page at <https://github.com/dryvist> |

## Contributing

Changes here affect every dryvist repo. Tread carefully:

- Bump rules in `biome.jsonc` or `.markdownlint-cli2.yaml` cautiously — they cascade to every repo on next sync.
- Don't introduce vendor-specific (Cribl, etc.) content. That belongs in the relevant template repo.
- Conventional commits required (`feat:`, `fix:`, `chore:`, `docs:`).

To validate locally before pushing:

```sh
# Lint this repo's own code and markdown
npx -y @biomejs/biome check .
npx -y markdownlint-cli2 "**/*.md"
```

## License

[Apache-2.0](LICENSE).

## References

- [`JacobPEvans/.github`](https://github.com/JacobPEvans/.github) — to become a downstream consumer of this repo's presets (inversion pending)
- [`dryvist/cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template) — Cribl pack template
- [Biome configuration reference](https://biomejs.dev/reference/configuration/)
- [markdownlint-cli2 configuration](https://github.com/DavidAnson/markdownlint-cli2#configuration)
- [Renovate `extends` docs](https://docs.renovatebot.com/config-presets/)
- [release-please-action](https://github.com/googleapis/release-please-action)
