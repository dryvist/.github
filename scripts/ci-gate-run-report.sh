#!/usr/bin/env bash
# ci-gate-run-report.sh — invoked by the `gate` job in _ci-gate.yml.
#
# Writes a per-job run report to $GITHUB_STEP_SUMMARY: each job's result,
# execution duration (completed_at - started_at), and queue delay
# (started_at - created_at). The `gate` job runs last with every sibling in a
# terminal state, so job timestamps are final here — the only point in the run
# where a queue-delay scan reads true values.
#
# Also appends a loud runner-capacity warning naming any job that sat longer
# than 5 minutes in `queued` before a runner picked it up. Warning only: this
# script never fails the gate (the workflow step is `continue-on-error`).
#
# Required env:
#   GH_TOKEN             — GitHub token with actions:read on the run
#   REPO                 — owner/repo of the current workflow run
#   RUN_ID               — workflow run id
#   GITHUB_STEP_SUMMARY  — summary file path (auto-set by the runner)

set -euo pipefail

: "${GH_TOKEN:?required}"
: "${REPO:?required}"
: "${RUN_ID:?required}"
: "${GITHUB_STEP_SUMMARY:?required}"

# Queue-delay threshold (seconds) above which a job is flagged as a
# runner-capacity signal. 5 minutes.
queue_warn_seconds=300

jobs_json="$(gh api --paginate "repos/${REPO}/actions/runs/${RUN_ID}/jobs?per_page=100")"

# fromdateiso8601 parses the `...Z` timestamps GitHub returns. Durations are
# integer seconds, so `dur` can use modulo safely. A running job (the gate
# itself) has no completed_at, so its duration renders as "—".
{
  echo "### CI job durations"
  echo ""
  echo "| Job | Result | Duration | Queue delay |"
  echo "| --- | --- | --- | --- |"
  jq -r '
    def dur: if . >= 60 then "\((./60|floor))m \((.%60))s" else "\(.)s" end;
    .jobs[]
    | (if .started_at and .completed_at
         then ((.completed_at|fromdateiso8601) - (.started_at|fromdateiso8601)) | dur
         else "—" end) as $d
    | (if .started_at and .created_at
         then ((.started_at|fromdateiso8601) - (.created_at|fromdateiso8601))
         else null end) as $q
    | "| \(.name) | \(.conclusion // .status) | \($d) | \(if $q == null then "—" else ($q|dur) end) |"
  ' <<<"$jobs_json"
} >>"$GITHUB_STEP_SUMMARY"

slow="$(jq -r --argjson threshold "$queue_warn_seconds" '
  def dur: if . >= 60 then "\((./60|floor))m \((.%60))s" else "\(.)s" end;
  .jobs[]
  | select(.started_at and .created_at)
  | { name, q: ((.started_at|fromdateiso8601) - (.created_at|fromdateiso8601)) }
  | select(.q > $threshold)
  | "\(.name) waited \(.q|dur) in queue"
' <<<"$jobs_json")"

if [ -n "$slow" ]; then
  {
    echo ""
    echo "> [!WARNING]"
    echo "> Runner-capacity signal — jobs queued longer than 5 minutes:"
    while IFS= read -r line; do
      echo "> - ${line}"
    done <<<"$slow"
  } >>"$GITHUB_STEP_SUMMARY"
fi
