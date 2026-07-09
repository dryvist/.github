#!/usr/bin/env bash
# ci-gate-detect-deps-only.sh — invoked by the `changes` job in _ci-gate.yml.
#
# Feeds the opt-in `nix_skip_deps_only` toggle: writes `is-deps-only=true` to
# $GITHUB_OUTPUT when the PR looks like a pure dependency bump, so callers can
# skip `nix-validate`/`nix-build` on it (still overridden by a flake.lock
# change — see `is-flake-lock-change` in the same job).
#
#   - Renovate: author prefix + chore(deps) title (dual check since Renovate
#     can also open non-dependency PRs).
#   - Dependabot: author check alone (it exclusively opens dependency PRs).
#
# AUTHOR/COMMIT_MSG are empty on non-pull_request events, which safely
# evaluates to is-deps-only=false (never skip).
#
# Required env:
#   AUTHOR      — github.event.pull_request.user.login
#   COMMIT_MSG  — github.event.pull_request.title
#   GITHUB_OUTPUT — GitHub Actions output file (set by the runner)

set -euo pipefail

: "${GITHUB_OUTPUT:?required}"

if [[ ("${AUTHOR:-}" == "jacobpevans-github-actions"* && "${COMMIT_MSG:-}" == chore\(deps\)*) || \
      "${AUTHOR:-}" == "dependabot[bot]" ]]; then
  echo "is-deps-only=true" >>"$GITHUB_OUTPUT"
else
  echo "is-deps-only=false" >>"$GITHUB_OUTPUT"
fi
