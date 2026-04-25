# dryvist/.github

Org-level community defaults and reusable GitHub Actions workflows for the dryvist organization.

## Installation

This repository is not installed — it is referenced from other repositories' workflows. To use a workflow from this repo in your pack repo:

1. Ensure your pack repo follows the layout from [`dryvist/cc-edge-pack-template`](https://github.com/dryvist/cc-edge-pack-template) (has `default/`, `data/samples/`, `tests/`, `package.json`).
2. Add a thin caller workflow to your pack repo (see Usage below).
3. No tokens or secrets need to be set — the reusable workflow uses public Docker images and the calling repo's read-only checkout token.

Cross-org calls work as long as this repo (`dryvist/.github`) is **public** or marked **internal** with org-default visibility, and the caller repo's actions settings permit calling reusable workflows from non-organisation repos.

## Usage

### `cribl-pack-test.yml` — validates and tests a Cribl pack

Adopts the [criblpacks](https://github.com/criblpacks) test pattern (Python + Docker + Cribl management API) and extends it with auto-discovered fixture-based pipeline assertions and structural validation drawn from the [VisiCore/vct-cribl-pack-validator](https://github.com/VisiCore/vct-cribl-pack-validator) ruleset.

Add this to your pack repo at `.github/workflows/test.yml`:

```yaml
name: Test
on:
  pull_request:
    paths:
      - 'default/**'
      - 'data/samples/**'
      - 'tests/**'
      - 'package.json'
  push:
    branches: [main]

jobs:
  test:
    uses: dryvist/.github/.github/workflows/cribl-pack-test.yml@main
    with:
      pack_type: edge   # or 'stream'
```

Inputs:

| Input | Required | Default | Description |
|---|---|---|---|
| `pack_type` | yes | — | `edge` or `stream` |
| `cribl_version` | no | `latest` | `cribl/cribl` Docker tag |
| `python_version` | no | `3.12` | Python interpreter |

Jobs run by this workflow:

1. **validate** — Structural checks: required files, routes-reference-pipelines, `package.json` shape, yamllint, vct-cribl-pack-validator rule extraction.
2. **test** — Spins up `cribl/cribl` as a service container, installs the pack via the management API, runs `pytest tests/` against the live instance.

## Contributing

Workflow changes must keep the contract stable for downstream packs. Specifically: do not rename inputs, do not change required input semantics, and bump major versions of any workflow if making breaking changes.

To validate a change locally before pushing:

```bash
# Lint the workflow
yamllint .github/workflows/

# Test against a real pack
cd ~/git/cc-edge-claude-code-io/main
gh workflow run test.yml --ref my-test-branch
```

## API

This repository exposes one public reusable workflow:

- `dryvist/.github/.github/workflows/cribl-pack-test.yml@<ref>` — see Usage above for inputs.

## License

Apache-2.0 (matches the org default).

## References

- [criblpacks/cribl-palo-alto-networks](https://github.com/criblpacks/cribl-palo-alto-networks) — original test pattern this workflow adopts
- [VisiCore/vct-cribl-pack-validator](https://github.com/VisiCore/vct-cribl-pack-validator) — Claude Code skill for deeper structural validation (developer pre-PR step)
- [Cribl management API](https://docs.cribl.io/api-reference/)
- [GitHub reusable workflows](https://docs.github.com/en/actions/sharing-automations/reusing-workflows)
