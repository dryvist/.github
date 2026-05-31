#!/usr/bin/env bash
# Central release-please hub.
#
# Cuts releases for every org repo that carries a release-please config, from
# this one place — no per-repo workflow files. For each repo the org App is
# installed on, this runs the release-please CLI remotely via --repo-url.
#
# Opt in:  add release-please-config.json + .release-please-manifest.json to a
#          repo's default branch.
# Opt out: remove them.
#
# Environment:
#   GH_TOKEN — org App installation token (contents + pull-requests write).
#              Also used by `gh` to enumerate the installation's repositories.
set -euo pipefail

# Repos the App is installed on (authoritative for an installation token),
# excluding archived repos.
mapfile -t repos < <(
  gh api --paginate /installation/repositories \
    --jq '.repositories[] | select(.archived == false) | .full_name'
)

echo "Discovered ${#repos[@]} non-archived repo(s) in the installation."

for repo in "${repos[@]}"; do
  # Opt-in marker: a release config on the default branch.
  if ! gh api "repos/${repo}/contents/release-please-config.json" >/dev/null 2>&1; then
    continue
  fi

  echo "::group::release-please ${repo}"
  npx --yes release-please@17.6.1 release-pr \
    --token="${GH_TOKEN}" \
    --repo-url="${repo}" \
    --config-file=release-please-config.json \
    --manifest-file=.release-please-manifest.json \
    || echo "::warning::release-pr failed for ${repo}"

  npx --yes release-please@17.6.1 github-release \
    --token="${GH_TOKEN}" \
    --repo-url="${repo}" \
    --config-file=release-please-config.json \
    --manifest-file=.release-please-manifest.json \
    || echo "::warning::github-release failed for ${repo}"
  echo "::endgroup::"
done
