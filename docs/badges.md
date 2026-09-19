# Canonical Repository Badges

This document defines the canonical repository badge standards for the
[dryvist](https://github.com/dryvist) organization.

Badges provide immediate visual telemetry on deployment health, release state,
licensing, and architecture links directly at the top of every repository's
`README.md`.

---

## Placement & Hierarchy

Badges are positioned immediately beneath the top `# <Repository Title>` heading
and directly preceding the initial prose paragraph.

```markdown
# Repository Name

[![CI Gate][badge-ci]][workflow-ci]
[![Post-Merge Tests][badge-pm]][workflow-pm]
[![Release Please][badge-rp]][workflow-rp]
[![Release][badge-release]][release-url]
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-2F7E78?style=flat-square)](LICENSE)
[![Built with Nix](https://img.shields.io/badge/built%20with-Nix-5277C3?style=flat-square&logo=nixos&logoColor=white)](flake.nix)
[![Renovate](https://img.shields.io/badge/renovate-enabled-2F7E78?style=flat-square&logo=renovatebot&logoColor=white)](https://github.com/dryvist/.github)
[![Docs](https://img.shields.io/badge/docs-jacobpevans.com-4FB3A9?style=flat-square)](https://docs.jacobpevans.com)

[badge-ci]: https://github.com/dryvist/<repo>/actions/workflows/ci-gate.yml/badge.svg?branch=main
[workflow-ci]: https://github.com/dryvist/<repo>/actions/workflows/ci-gate.yml?query=branch%3Amain
[badge-pm]: https://github.com/dryvist/<repo>/actions/workflows/post-merge-tests.yml/badge.svg?branch=main
[workflow-pm]: https://github.com/dryvist/<repo>/actions/workflows/post-merge-tests.yml?query=branch%3Amain
[badge-rp]: https://github.com/dryvist/<repo>/actions/workflows/release-please.yml/badge.svg?branch=main
[workflow-rp]: https://github.com/dryvist/<repo>/actions/workflows/release-please.yml?query=branch%3Amain
[badge-release]: https://img.shields.io/github/v/release/dryvist/<repo>?sort=semver&style=flat-square&color=2F7E78
[release-url]: https://github.com/dryvist/<repo>/releases

Opening purpose paragraph begins here...
```

> [!NOTE]
> This placement guarantees compliance with `validate-readme` Check 2
> (Purpose Paragraph), which requires that the first non-frontmatter, non-badge,
> non-heading paragraph contains descriptive prose.

---

## Badge Categories

### Tier 1: Core CI & Workflow Telemetry

Workflow badges use native GitHub Actions SVG badges scoped to `branch=main`:

- **CI Gate**: Present if `.github/workflows/ci-gate.yml` exists.
  Badge: `actions/workflows/ci-gate.yml/badge.svg?branch=main`
  Query: `actions/workflows/ci-gate.yml?query=branch%3Amain`
- **Post-Merge Tests**: Present if `.github/workflows/post-merge-tests.yml` exists.
  Badge: `actions/workflows/post-merge-tests.yml/badge.svg?branch=main`
  Query: `actions/workflows/post-merge-tests.yml?query=branch%3Amain`
- **Release Please**: Present if `.github/workflows/release-please.yml` exists.
  Badge: `actions/workflows/release-please.yml/badge.svg?branch=main`
  Query: `actions/workflows/release-please.yml?query=branch%3Amain`

#### Why `branch=main`?

In the dryvist organization, `main` represents the deployed production release train:

- In **trunk repositories** (`gitflow: false`), `main` is both default and deployed.
- In **git-flow repositories** (`gitflow: true`), `develop` is for development,
  while `main` is the deployed production state. Release-please triggers on `main`.
- Scoping to `main` surfaces production deployment health and avoids cluttering
  documentation with multiple branch matrices.

---

### Tier 2: Governance & Ecosystem

Governance and ecosystem badges use Shields.io with `style=flat-square` and the
dryvist brand palette (`#2F7E78` deep teal, `#4FB3A9` teal, `#5277C3` nix blue):

- **Release Version**: Semver version cut by release-please.
- **License**: Apache-2.0 linking to repository `LICENSE`.
- **Built with Nix**: Present if `flake.nix` exists; links to `flake.nix`.
- **Renovate**: Present if Renovate managed; links to `dryvist/.github`.
- **Docs Hub**: Links to `https://docs.jacobpevans.com` architecture map.

---

## D-R-Y Generation & Auditing

To eliminate manual copy-pasting and prevent drift, badges are managed using
`scripts/generate-badges.sh`:

```bash
# Preview badges for a repository:
./scripts/generate-badges.sh --repo <name>

# Write/update canonical badges in a repository's README.md:
./scripts/generate-badges.sh --repo <name> --write

# Verify a repository's README.md for drift:
./scripts/generate-badges.sh --repo <name> --check

# Check all repositories in the organization:
./scripts/generate-badges.sh --all --check
```
