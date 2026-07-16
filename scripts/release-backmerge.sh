#!/usr/bin/env bash
# Back-merge the release commit main -> develop on git-flow repos.
#
# Called by the reusable _release-please.yml workflow after a release is cut,
# so develop's manifest and CHANGELOG track released versions instead of
# drifting behind main. No-op on trunk repos (default branch main), which have
# no develop branch to back-merge into.
#
# Why a PR and not a direct merge: develop is protected by a `pull_request`
# rule and a required "Merge Gate" status check, so a direct POST /repos/{}/merges
# is rejected `HTTP 409 Repository rule violations found` on every release (the
# old error text blamed a "merge conflict" — it was really the ruleset). We open
# a real PR and enable auto-merge, so it lands the same way a human PR does.
#
# Env:
#   GH_TOKEN  App token with contents:write + pull-requests:write
#   GH_REPO   owner/repo (github.repository)
set -euo pipefail

# Trunk repos (default branch main) have no develop branch — the release commit
# is already on the default branch, so there is nothing to back-merge.
if [ "$(gh api "repos/${GH_REPO}" --jq .default_branch)" = "main" ]; then
  echo "Trunk repo — no develop back-merge needed."
  exit 0
fi

# Already caught up? `compare/base...head` reports head relative to base;
# "identical"/"behind" means develop already contains main's tip → clean no-op.
status=$(gh api "repos/${GH_REPO}/compare/develop...main" --jq .status)
if [ "$status" = "identical" ] || [ "$status" = "behind" ]; then
  echo "develop already up to date with main ($status) — nothing to back-merge."
  exit 0
fi

# CRITICAL: never open the PR with head=main. On repos with auto-delete-head,
# merging a head=main PR deletes the main branch (tofu-proxmox #640 incident).
# Cut a throwaway branch from main's tip and use THAT as the head — the temp
# branch is what auto-delete removes on merge; main is only the source commit.
main_sha=$(gh api "repos/${GH_REPO}/git/ref/heads/main" --jq .object.sha)
temp_branch="backmerge/main-${main_sha:0:12}"

# Idempotent: a leftover temp ref from an earlier failed run is fine to reuse
# (422 = already exists). Same for its open PR, resolved just below.
gh api -X POST "repos/${GH_REPO}/git/refs" \
  -f ref="refs/heads/${temp_branch}" -f sha="$main_sha" >/dev/null 2>&1 || true

pr_number=$(gh pr list --head "$temp_branch" --base develop --state open \
  --json number --jq '.[0].number // empty')
if [ -z "$pr_number" ]; then
  pr_number=$(gh pr create --base develop --head "$temp_branch" \
    --title "chore: back-merge released main into develop" \
    --body "Automated back-merge so develop tracks the released manifest and CHANGELOG. Auto-merges once the Merge Gate passes." \
    | grep -oE '[0-9]+$')
fi

# Fail loudly on a real conflict instead of enabling an auto-merge that would
# silently never land. Mergeability is computed async, so poll until it is known.
# ponytail: if still unknown after ~30s (rare), fall through to auto-merge —
# auto-merge holds a conflicting PR open rather than mis-merging it.
mergeable=null
for _ in 1 2 3 4 5 6; do
  mergeable=$(gh api "repos/${GH_REPO}/pulls/${pr_number}" --jq '.mergeable // "null"')
  [ "$mergeable" != "null" ] && break
  sleep 5
done
if [ "$mergeable" = "false" ]; then
  echo "::error::Back-merge PR #${pr_number} (main -> develop) has conflicts in ${GH_REPO}. Resolve it manually." >&2
  exit 1
fi

# Enable auto-merge as a merge commit (develop allows it, and the default
# "Merge pull request ..." subject satisfies develop's commit_message_pattern).
# Disable+re-enable clears a stale auto-merge queue; the retry loop rides out
# transient GraphQL errors — same shape as the release-PR auto-merge step.
gh pr merge "$pr_number" --disable-auto 2>/dev/null || true
for _ in 1 2 3; do gh pr merge "$pr_number" --auto --merge && exit 0; sleep 15; done
echo "::error::Failed to enable auto-merge on back-merge PR #${pr_number} in ${GH_REPO}." >&2
exit 1
