# Audit findings

Read-only review of the repository at `dd0e816`. Each entry is `file:line`
plus one sentence.

- `AGENTS.md:146` — Names `.github/workflows/bot-pr-automerge-sweep.yml` as the
  merger of bot PRs, but that workflow was deleted from this repo in #430 and the
  surviving equivalent is `pr-automerge.yml` in `JacobPEvans/.github`.
- `AGENTS.md:134` — Says `repo-conventions-sweep.yml` runs weekly "in this repo",
  but it was removed in #403 and now exists only in `JacobPEvans/.github`.
- `.github/workflows/conventions-check.yml:10` — Header still credits
  `repo-conventions-sweep.yml` "in this repo" with covering the no-PR-traffic
  blind spot, a file that is no longer here.
- `AGENTS.md:132` — Claims `conventions-check.yml` and `markdownlint.yml` "only
  run where a repo calls it", contradicting `README.md:179` and
  `.github/workflows/conventions-check.yml:4`, which say the rulesets inject them
  into every repo's PRs (neither workflow is even `workflow_call`-able).
- `.github/workflows/markdownlint.yml:3` — Header attributes the injecting
  ruleset to `dryvist/terraform-github` while
  `.github/workflows/conventions-check.yml:4` attributes the same mechanism to
  `dryvist/tofu-github`, so one provenance comment is stale.
- `.github/workflows/markdownlint.yml:60` — The
  `github.event_name != 'pull_request'` full-tree lint step is unreachable dead
  code because the workflow's only trigger is `pull_request`.
- `README.md:115` — The copy-paste release caller example uses
  `JacobPEvans/.github/.github/workflows/_release-please.yml@v1` while
  `AGENTS.md:40` names `_release.yml@v1` as the org standard, so the two
  canonical docs disagree on which workflow to wire.
- `.markdownlint-cli2.yaml:7` — Comment says Biome handles JS/TS/JSON/CSS at
  `lineWidth 100 (see biome.jsonc)` but `biome.jsonc:31` sets 120 (the 100 is
  prettier's `--print-width` in `nix/dev-hygiene.nix:64`).
- `nix/dev-hygiene.nix:64` — The Nix path formats JS/TS/JSON with prettier at
  width 100 while the canonical Biome standard is 120, so the two sanctioned
  toolchains disagree on the same files.
- `SECURITY.md:83` — "Auditable Workflow Boundaries" claims dryvist repos
  reference *this* repo's reusable workflows by commit SHA, but those workflows
  left this repo in #430 and `README.md:151` now mandates the floating `@v1` tag.
- `SECURITY.md:28` — Says all third-party actions, "trusted orgs included", are
  SHA-pinned with no tag allowance (`SECURITY.md:48`), contradicting
  `zizmor.yml:44`, which grants `actions/*: ref-pin`.
- `.github/labels.yml:14` — Says the type/priority/size requirements are
  "enforced via issue templates", but `.github/ISSUE_TEMPLATE/` ships only
  `config.yml` with no templates, so nothing enforces them.
- `AGENTS.md:59` — "Every dryvist repo runs release-please" is false for this
  repo itself: its caller was deleted in #403 and `VERSION` plus
  `.release-please-manifest.json` in #430, leaving `CHANGELOG.md` frozen at
  1.19.3 (2026-10-17).
- `.github/workflows/conventions-check.yml:42` — This copy has already drifted
  from the identically named workflow in `JacobPEvans/.github`, which
  additionally runs a "Reject Renovate schedule overrides" step, so the two
  copies silently diverge for whatever each one governs.
- `.github/scripts/docs-publisher-provenance.js:3` — The control-plane denylist
  omits `CLAUDE.md`, `CHANGELOG.md` and the `renovate-*.json` presets, so a bot
  PR touching them in a docs-projection repo is misclassified as generated
  output and rejected unless the publisher App opened it.

VERDICT: Documentation rot from the #403/#430 workflow retirement plus policy
contradictions between `SECURITY.md`, `AGENTS.md` and the workflow headers; no
exploitable code defect found, but the security pinning policy and required-workflow
claims should be reconciled before this hub is trusted as canonical.
