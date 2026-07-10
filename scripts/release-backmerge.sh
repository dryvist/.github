#!/usr/bin/env bash
# Back-merge the release commit main -> develop on git-flow repos.
#
# Called by the reusable _release-please.yml workflow after a release is cut,
# so develop's manifest and CHANGELOG track released versions instead of
# drifting behind main. No-op on trunk repos (default branch main), which have
# no develop branch to back-merge into.
#
# Env:
#   GH_TOKEN  App token with contents:write
#   GH_REPO   owner/repo (github.repository)
set -euo pipefail

# Trunk repos (default branch main) have no develop branch — the release commit
# is already on the default branch, so there is nothing to back-merge.
if [ "$(gh api "repos/${GH_REPO}" --jq .default_branch)" = "main" ]; then
  echo "Trunk repo — no develop back-merge needed."
  exit 0
fi

# Merge via the REST merges API rather than a local git push: the App-authored
# merge commit is GitHub-verified, satisfying develop's required_signatures rule
# that a CLI push of an unsigned merge commit would fail. The default "Merge ..."
# subject also satisfies develop's commit_message_pattern, which permits a
# leading "Merge ". 201 = merged, 204 = already up to date (no-op) — both
# succeed. 409 = merge conflict — gh api exits non-zero, failing the job so a
# human resolves it (we never auto-resolve a CHANGELOG conflict).
if gh api -X POST "repos/${GH_REPO}/merges" \
     -f base=develop -f head=main \
     -f commit_message="Merge main into develop (back-merge release)"; then
  echo "Back-merge main -> develop complete (or already up to date)."
else
  echo "::error::Back-merge main -> develop failed (likely a merge conflict). Open a PR from main into develop and resolve manually." >&2
  exit 1
fi
