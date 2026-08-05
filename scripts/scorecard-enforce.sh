#!/usr/bin/env bash
# Enforce OpenSSF Scorecard posture from a scorecard JSON result.
#
# Two halves, deliberately separated:
#
#   BLOCKING_CHECKS — named checks that must score 10. Only checks that are
#     deterministic AND caused by files in the diff belong here, because these
#     fail a merge and a reviewer has to be able to act on them.
#
#   MIN_SCORE — the aggregate floor, default 0 (report-only). The aggregate
#     mixes in repo-state checks that drift with time rather than with the
#     diff (Maintained decays on 90-day activity; Vulnerabilities moves when a
#     CVE lands in OSV; Code-Review reflects past PR history). Hard-failing on
#     it would block pull requests for reasons no diff caused.
#
# A missing aggregate score is always a failure — never treat an unparseable
# result as a pass.
#
# Env: RESULTS (path to scorecard JSON), BLOCKING_CHECKS (comma-separated),
#      MIN_SCORE (number).
set -euo pipefail

results="${RESULTS:-scorecard.json}"
blocking="${BLOCKING_CHECKS:-}"
min_score="${MIN_SCORE:-0}"

if [ ! -s "$results" ]; then
  echo "::error title=OpenSSF Scorecard::Result file '${results}' is missing or empty"
  exit 1
fi

score=$(jq -r '.score // empty' "$results")
if [ -z "$score" ]; then
  echo "::error title=OpenSSF Scorecard::No aggregate score in ${results}"
  cat "$results"
  exit 1
fi

echo "--- Scorecard checks (score, name) ---"
jq -r '.checks[] | "\(.score)\t\(.name)"' "$results" | sort -n
echo "--------------------------------------"

failed=0

# Enforcing half. Absent or -1 (not applicable to this repo) is skipped, not
# failed — repos legitimately differ in which checks apply.
IFS=','
for check in $blocking; do
  check="$(printf '%s' "$check" | tr -d '[:space:]')"
  [ -n "$check" ] || continue

  cs=$(jq -r --arg c "$check" '.checks[] | select(.name==$c) | .score' "$results")
  if [ -z "$cs" ]; then
    echo "skip: '${check}' not reported for this repo"
  elif [ "$cs" = "-1" ]; then
    echo "skip: '${check}' is N/A for this repo"
  elif [ "$cs" -lt 10 ]; then
    echo "::error title=OpenSSF Scorecard::${check} scored ${cs}/10 — caused by files in this repo; fix the finding rather than waiving the check"
    failed=1
  else
    echo "ok:   ${check} = 10"
  fi
done
unset IFS

# Reporting half. Only gates when a repo has opted into a floor.
echo "Aggregate score: ${score} (floor: ${min_score})"
if awk -v s="$score" -v m="$min_score" 'BEGIN { exit !(s < m) }'; then
  echo "::error title=OpenSSF Scorecard::Aggregate ${score} is below this repo's ${min_score} floor"
  failed=1
fi

[ "$failed" -eq 0 ] || exit 1
echo "Posture checks passed."
