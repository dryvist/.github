# Security Policy

## Reporting Vulnerabilities

To report a security vulnerability in any **dryvist** repository, use
[GitHub's private vulnerability reporting][private-vuln] on the affected
repository. Do not open a public issue for security vulnerabilities.

[private-vuln]: https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability

For critical vulnerabilities affecting multiple dryvist repositories, report
to this [.github repository](https://github.com/dryvist/.github/security/advisories/new).

## Dependency Trust

Automated dependency updates use Renovate via this repo's master presets
([`renovate-presets.json`](renovate-presets.json) + [`renovate-grouping.json`](renovate-grouping.json)).
The presets enforce a tiered freshness model. Canonical, fuller documentation:
[docs.jacobpevans.com/infrastructure/cicd/dependency-automation](https://docs.jacobpevans.com/infrastructure/cicd/dependency-automation).

| Tier | Scope | Cadence | Age | Auto-merge |
| --- | --- | --- | --- | --- |
| **First-party** | `dryvist/**`, `JacobPEvans/**`, `JacobPEvans-personal/**` | immediate | 0d | all update types incl. major |
| **Trusted** | curated ~50-org allowlist | twice-weekly (Mon/Thu) | 3d | minor/patch only; **major → review** |
| **Untrusted** | all other external deps | weekly (Mon) | 3d | AI-gated `risk:low` subset only |
| **Security / CVE** | any vulnerability alert | immediate | 0d | yes — overrides every tier |

- **First-party** — our own published packages. release-please cuts and auto-merges
  every release, so changes propagate to consumers at once (0-day auto-merge here).
- **Trusted** — the curated org allowlist in `renovate-presets.json` (actions, google,
  github, hashicorp, astral-sh, NixOS, …). A list entry auto-merges that org's
  **minor/patch**; it is **not** a claim its **majors** are API-compatible, so trusted
  majors open a review PR (`dep:review` label) and never auto-merge. `owner/**` matches
  GitHub Actions and Nix `github:` inputs; an org's npm/PyPI/Terraform packages are
  trusted only where a `matchSourceUrls` carve-out promotes them, else they route to the
  untrusted tier (safe).
- **Untrusted** — everything else. No blind merge: the `dryvist/ai-workflows` dependency
  reviewer auto-merges only the `risk:low` subset (OSV + GitHub Dependency Review clean,
  minor/patch); all else is labelled and escalated for a human.
- **Security / CVE** — vulnerability-driven bumps auto-merge immediately, bypassing the
  schedule and every tier above.

GitHub Actions from untrusted orgs are pinned to SHA digests, not tags; dryvist
self-references ride `@main` (see Version Pinning below).

## Version Pinning

| Source | Strategy |
| --- | --- |
| dryvist self-references | `@main` — never SHA or minor/patch pins |
| Trusted GitHub Actions | Semantic version tags (`@v6`) |
| External/untrusted GitHub Actions | SHA commit hash pins |
| npm packages | Lower-bound (`^x.y.z`) in `package.json`; lockfile committed |

### Scanner posture for `@main` self-references

`dryvist/*` reusable workflows are referenced at `@main` across every consumer.
Each scanner allows it by the most native means available — no reinvented
config files:

| Scanner | How `dryvist/*@main` is allowed |
| --- | --- |
| **Renovate** | `pinDigests: false` for `dryvist/**`, overriding the global `pinGitHubActionDigests`; `@main` is never SHA-pinned. |
| **zizmor** | `unpinned-uses` policy `dryvist/*: ref-pin` in `zizmor.yml`. |
| **CodeQL** | Code scanning default setup on public repos (free), managed as IaC in dryvist/tofu-github (per-repo, pending the provider resource). |
| **OSV-Scanner** | N/A — OSV reports dependency vulnerabilities, not ref-pinning, so `@main` is never flagged. |

Untrusted/external actions are unaffected and remain SHA-pinned. Code scanning is
enabled on **public repos only** — the 11 private repos are excluded to avoid
the paid GitHub Code Security per-committer charge. Flagging same-org `@main` is
a known CodeQL false positive ([codeql#18316]); those alerts are dismissed
natively in the code scanning UI rather than suppressed by a committed file.

[codeql#18316]: https://github.com/github/codeql/issues/18316

## Secret Management

- No production credentials are committed to git.
- Repo-level secrets configured via `gh secret set`.
- Org-level secrets (e.g., the GitHub App token for release-please) configured
  via `gh secret set --org dryvist`.

## Auditable Workflow Boundaries

This repo's own reusable workflows are referenced at `@main` by dryvist
repos intentionally — they are first-party and self-owned (this repo
extends nothing external). If you need to audit a specific workflow run,
the resolved SHA is logged in the GitHub Actions UI for that run.
