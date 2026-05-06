# dryvist

Cribl pack development under [dryvist](https://github.com/dryvist) — open
infrastructure for AI-coding-tool observability.

## Active repositories

| Repo | Purpose |
|---|---|
| [`cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template) | Template for new Cribl Edge / Stream packs |
| [`cc-edge-claude-code-io`](https://github.com/dryvist/cc-edge-claude-code-io) | Claude Code session-logs + OpenTelemetry pack |
| [`.github`](https://github.com/dryvist/.github) | Org-wide standards: AI policy, Biome config, security policy, renovate inheritance |

## Installation

To start a new dryvist Cribl pack, scaffold from the template:

```sh
gh repo create dryvist/cc-edge-<source>-io --public --template dryvist/cc-edge-pack-template
gh repo clone dryvist/cc-edge-<source>-io
cd cc-edge-<source>-io
npm install
```

To install one of our published packs into a Cribl deployment, download the
`.crbl` artifact from the repo's GitHub Releases and import via the Cribl UI
(Manage → Packs → Add Pack → Upload).

## Usage

Each pack repo carries its own development tooling — see the per-repo
README for `make` / `npm` targets specific to that pack.

Org-wide tooling and conventions live in
[`.github`](https://github.com/dryvist/.github):

- [`CLAUDE.md`](https://github.com/dryvist/.github/blob/main/CLAUDE.md) — AI assistant policy + inheritance chain
- [`biome.jsonc`](https://github.com/dryvist/.github/blob/main/biome.jsonc) — canonical Biome lint + format rules
- [`SECURITY.md`](https://github.com/dryvist/.github/blob/main/SECURITY.md) — vulnerability reporting + dependency trust tiers
- [`renovate.json`](https://github.com/dryvist/.github/blob/main/renovate.json) — extends `JacobPEvans/.github:renovate-presets`

## Standards

- **Language:** TypeScript everywhere we write code (test harnesses, custom GitHub Actions, tooling)
- **Lint + format:** [Biome](https://biomejs.dev) (canonical config in `.github/biome.jsonc`)
- **Test runner:** [Vitest](https://vitest.dev)
- **Releases:** [release-please](https://github.com/googleapis/release-please) inherited from [`JacobPEvans/.github`](https://github.com/JacobPEvans/.github)
- **Dependency updates:** Renovate inherited via `extends: github>JacobPEvans/.github:renovate-presets`

## Contributing

Issues and pull requests are welcome on any of the active repositories above.
For changes that affect multiple packs (e.g., updates to the test harness or
shared workflows), open the PR against
[`cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template)
or [`.github`](https://github.com/dryvist/.github) as appropriate, and we'll
sweep the change across consumer packs.

## License

All dryvist repositories are licensed under
[Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0) unless individual
repos state otherwise.
