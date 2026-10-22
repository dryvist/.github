# Security Policy

## Reporting Vulnerabilities

To report a security vulnerability in any **dryvist** repository, use
[GitHub's private vulnerability reporting][private-vuln] on the affected
repository. Do not open a public issue for security vulnerabilities.

[private-vuln]: https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability

For critical vulnerabilities affecting multiple dryvist repositories, report
to this [.github repository](https://github.com/dryvist/.github/security/advisories/new).

## Dependency Trust

Automated dependency updates use Renovate. The policy is defined once, in the master
[`JacobPEvans/.github`](https://github.com/JacobPEvans/.github/blob/main/SECURITY.md#dependency-trust),
and this repo's `renovate-presets.json`, `renovate-grouping.json` and `renovate-nix.json`
pass through to it.

Auto-merged updates are gated by the deterministic `dependency-review` job
(`actions/dependency-review-action`) inside the required Merge Gate on public repos.
The `dryvist/ai-workflows` dependency reviewer is advisory only: it labels findings for
human follow-up but does not gate or block auto-merge. Canonical, fuller documentation:
[docs.jacobpevans.com/infrastructure/cicd/dependency-automation](https://docs.jacobpevans.com/infrastructure/cicd/dependency-automation).

All third-party GitHub Actions — trusted orgs included — and all dryvist
reusable workflows are pinned to SHA digests, not tags (see Version Pinning
below).

## Version Pinning

| Source | Strategy |
| --- | --- |
| dryvist reusable workflows (`uses:`) | Commit SHA pin + released version tag as a trailing comment (`# vX.Y.Z`); Renovate bumps both together |
| dryvist Nix, Ansible and OpenTofu git refs | Floating major tag (`?ref=vN`); the lock file holds the exact revision |
| All third-party GitHub Actions | SHA commit hash pins + released version tag as a trailing comment (`# v4.2.2`); Renovate bumps both together |
| npm packages | Lower-bound (`^x.y.z`) in `package.json`; lockfile committed |

Updates to dryvist references merge automatically after required checks pass, under the
policy in Dependency Trust.
Floating major tags (`vN`) move on release, after the Canary check passes.
On a pull request that changes only Markdown outside `.github/` and
`tests/canary/`, the Canary check passes with a notice and runs no stacks.
They serve the Nix, Ansible and OpenTofu git refs only.

Trust tiers govern *review cadence for majors* (above), never the pin style:
there is no semver-tag allowance for trusted actions. Non-`uses:` pins that
Renovate cannot infer from context carry an explicit
`# renovate: datasource=… depName=… versioning=…` tag.

### Scanner posture for dryvist SHA pins

`dryvist/*` reusable workflows are referenced by commit SHA. Each scanner
handles that pin by the most native means available — no reinvented config
files:

| Scanner | How `dryvist/*` SHA pins are handled |
| --- | --- |
| **Renovate** | Updates the SHA and the `# vX.Y.Z` comment together; patch updates auto-merge, minor and major updates do not. |
| **zizmor** | `unpinned-uses` policy `dryvist/*: ref-pin` in `zizmor.yml`. |
| **CodeQL** | Code scanning default setup on public repos (free), managed as IaC in dryvist/tofu-github (per-repo, pending the provider resource). |
| **OSV-Scanner** | N/A — OSV reports dependency vulnerabilities, not ref-pinning. |

Untrusted/external actions are unaffected and remain SHA-pinned. Code scanning is
enabled on **public repos only** — the 11 private repos are excluded to avoid
the paid GitHub Code Security per-committer charge. Flagging same-org branch
references is a known CodeQL false positive ([codeql#18316]); those alerts are
dismissed natively in the code scanning UI rather than suppressed by a committed
file.

[codeql#18316]: https://github.com/github/codeql/issues/18316

## Secret Management

- No production credentials are committed to git.
- Repo-level secrets configured via `gh secret set`.
- Org-level secrets (e.g., the GitHub App token for release-please) configured
  via `gh secret set --org dryvist`.

## Auditable Workflow Boundaries

Dryvist repos reference this repo's reusable workflows by commit SHA. The SHA in
a caller's `uses:` line names the exact workflow version that runs. If you need
to audit a specific workflow run, the resolved SHA is logged in the GitHub
Actions UI for that run.
