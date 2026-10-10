#!/usr/bin/env bash
# Flags changed files that no profile filter covers (docs and release-please
# metadata excepted).
#
# Reads dorny/paths-filter `list-files: json` output from the environment:
#   ALL        every changed file (the resolve step's `changed-all` key)
#   NIX, MARKDOWN, PYTHON, ANSIBLE, TERRAFORM, EXTRA
#              the files each convention filter matched
# Each variable is a JSON array; an empty or unset one counts as [].
#
# For every unmapped path it prints a GitHub warning, then writes
# full=true|false to $GITHUB_OUTPUT. It never exits non-zero for an unmapped
# path: an unmapped path runs the full profile, it never fails the gate.
set -euo pipefail

unmapped=$(jq -r -n \
  --argjson all "${ALL:-[]}" \
  --argjson nix "${NIX:-[]}" \
  --argjson markdown "${MARKDOWN:-[]}" \
  --argjson python "${PYTHON:-[]}" \
  --argjson ansible "${ANSIBLE:-[]}" \
  --argjson terraform "${TERRAFORM:-[]}" \
  --argjson extra "${EXTRA:-[]}" \
  '($nix + $markdown + $python + $ansible + $terraform + $extra) as $mapped
   | $all[] | select(endswith(".md") | not)
   | select(IN("VERSION", ".release-please-manifest.json", "release-please-config.json") | not)
   | . as $f
   | select(any($mapped[]; . == $f) | not)')

full=false
while IFS= read -r path; do
  if [[ -z "$path" ]]; then
    continue
  fi
  echo "::warning::unmapped path ${path}, running full profile"
  full=true
done <<< "$unmapped"

echo "full=${full}" >> "${GITHUB_OUTPUT:-/dev/stdout}"
