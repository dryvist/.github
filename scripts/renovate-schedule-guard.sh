#!/usr/bin/env bash
# Renovate schedule guard — fails when a consumer repo's Renovate config sets
# its own schedule. The update schedule comes only from the dryvist/.github
# preset, so schedule, timezone, automergeSchedule and "at any time" are
# rejected anywhere in the file. Comment lines (//) are ignored.
#
# Usage: renovate-schedule-guard.sh  (run from the consumer repo root)
#
# Exit codes:
#   0 — no Renovate config, or none of the keys
#   1 — at least one hit, reported as ::error:: annotations
set -euo pipefail

hits=0
for f in renovate.json renovate.json5 .github/renovate.json .github/renovate.json5 .renovaterc .renovaterc.json; do
  [[ -f "$f" ]] || continue
  while IFS=: read -r line _; do
    printf '::error file=%s,line=%s,title=Renovate schedule override::%s sets its own schedule\n' "$f" "$line" "$f"
    hits=1
  done < <(grep -nE -i '"?(schedule|timezone|automergeSchedule)"?[[:space:]]*:|at any time' "$f" \
    | grep -vE '^[0-9]+:[[:space:]]*//' || true)
done

if [[ "$hits" -ne 0 ]]; then
  echo "Remove schedule, timezone, automergeSchedule and 'at any time'; the dryvist/.github preset owns the update schedule."
  exit 1
fi
