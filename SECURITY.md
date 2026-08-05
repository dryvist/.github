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
Minor/patch updates auto-merge publisher-agnostically; trust tiers gate only
majors and PR-creation cadence. Canonical, fuller documentation:
[docs.jacobpevans.com/infrastructure/cicd/dependency-automation](https://docs.jacobpevans.com/infrastructure/cicd/dependency-automation).

| Tier | Scope | PR-creation cadence | Majors |
| --- | --- | --- | --- |
| **First-party** | `dryvist/**`, `JacobPEvans/**`, `JacobPEvans-personal/**` | at any time | auto-merge immediately, incl. major |
| **Trusted** | curated ~50-org allowlist | twice-weekly (Mon/Thu) | never auto-merge; 3-day review PR (`dep:review`) |
| **Untrusted** | all other external deps | weekly (Mon) | never auto-merge; held 30 days for review |
| **Security / CVE** | any vulnerability alert | immediate (0-day PR) | minor/patch auto-merges fast; a security major still opens for review |

**Minor/patch updates auto-merge publisher-agnostically** — any package, any ecosystem,
any publisher — after a 3-day stabilization window and green CI. Trust tiers do not
gate minor/patch; they gate only majors and PR-creation cadence.

- **First-party** — our own published packages. release-please cuts and auto-merges
  every release, so changes propagate to consumers at once (0-day auto-merge, all
  update types including major).
- **Trusted** — the curated org allowlist in `renovate-presets.json` (actions, google,
  github, hashicorp, astral-sh, NixOS, …). Trust here shortens the major-default
  30-day hold to a 3-day review PR (`dep:review` label); it has no effect on
  minor/patch, which auto-merges the same way for every tier.
- **Untrusted** — everything else. Minor/patch still auto-merges through the same
  publisher-agnostic rule; the only differences are a weekly (vs twice-weekly)
  PR-creation cadence and the full 30-day hold before a major opens for review.
- **Majors never auto-merge except first-party** — a compatible-looking version is not
  a compatible API. First-party majors auto-merge immediately; trusted-org majors open
  a 3-day review PR; every other major is held 30 days.
- **Security / CVE** — `vulnerabilityAlerts` surfaces a 0-day PR immediately, bypassing
  the normal schedule. The auto-merge decision then falls to the same packageRules as
  any other update: a security minor/patch inherits the broad rule's fast auto-merge,
  while a security major still opens for review like any other major.
- **Supply-chain safety** for the broad auto-merge set is the deterministic
  `dependency-review` job (`actions/dependency-review-action`) inside the required
  Merge Gate on public repos. The `dryvist/ai-workflows` dependency reviewer is
  advisory only — it labels findings for human follow-up but does not gate or block
  auto-merge.

All third-party GitHub Actions — trusted orgs included — are pinned to SHA
digests, not tags; dryvist self-references ride `@main` (see Version Pinning
below).

## Security Posture (OpenSSF)

OpenSSF is an org standard, enforced two ways:

- **Scorecard** runs as the `OpenSSF Scorecard` job inside the required
  **Merge Gate** on every pull request ([`_scorecard.yml`](.github/workflows/_scorecard.yml)).
  Like `dependency-review` and `zizmor`, it is **not** path-filtered — a
  security-posture measurement must not be evadable by touching only untracked
  paths. It fails when the aggregate score drops below the gate's
  `scorecard_min_score` floor (default 7). Raise the floor as a repo improves;
  never lower it to get a PR through.
- **Best Practices Badge** — every repo enrolls at
  [bestpractices.dev](https://www.bestpractices.dev) and carries the badge in
  its `README.md`. Presence is checked by `conventions-check.yml` alongside the
  other repo conventions; enrollment itself is a manual owner action.

## Version Pinning

| Source | Strategy |
| --- | --- |
| dryvist self-references | `@main` — never SHA or minor/patch pins |
| All third-party GitHub Actions | SHA commit hash pins + released version tag as a trailing comment (`# v4.2.2`); Renovate bumps both together |
| npm packages | Lower-bound (`^x.y.z`) in `package.json`; lockfile committed |

Trust tiers govern *review cadence for majors* (above), never the pin style:
there is no semver-tag allowance for trusted actions. Non-`uses:` pins that
Renovate cannot infer from context carry an explicit
`# renovate: datasource=… depName=… versioning=…` tag.

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
