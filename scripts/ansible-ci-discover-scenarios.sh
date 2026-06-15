#!/usr/bin/env bash
# ansible-ci-discover-scenarios.sh — invoked by `molecule-discover` in
# _ansible-ci.yml. Emits `scenarios=<json-array>` to GITHUB_OUTPUT: the molecule
# scenario names found under any molecule/<scenario>/molecule.yml in the repo.
# An empty result yields [] (the molecule matrix job is then skipped), so a repo
# with no molecule scenarios needs no special-casing.
#
# Required env:
#   GITHUB_OUTPUT — the step-output file
set -euo pipefail
: "${GITHUB_OUTPUT:?required}"

list=$(find . -path '*/molecule/*/molecule.yml' \
  -exec sh -c 'basename "$(dirname "$1")"' _ {} \; | sort -u | jq -R . | jq -s -c .)
[ -z "$list" ] && list='[]'
echo "scenarios=$list" >> "$GITHUB_OUTPUT"
echo "Discovered molecule scenarios: $list"
