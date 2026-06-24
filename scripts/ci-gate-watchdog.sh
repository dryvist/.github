#!/usr/bin/env bash
# ci-gate-watchdog.sh — invoked by the `watchdog` job in _ci-gate.yml.
#
# Poll the run's sibling jobs and EXIT AS SOON AS none is still `queued`
# (everything got scheduled) — only cancel jobs that remain stuck in `queued`
# after QUEUE_TIMEOUT_MINUTES. Cancelling forces a terminal state so `gate` can
# finally schedule and `re-actors/alls-green` can evaluate, ensuring the required
# `Merge Gate` status always reports.
#
# Why poll instead of `sleep $TIMEOUT`: a fixed sleep billed a full
# QUEUE_TIMEOUT_MINUTES of runner time on EVERY run, even though jobs only get
# stuck in `queued` on self-hosted runners that never pick them up. On GitHub-
# hosted runners siblings schedule within seconds, so this now exits in seconds.
# "Queue Watchdog" (this job) and "Merge Gate" (awaiting this job) are exempt —
# their `queued`/pending state here is intentional.
#
# Required env:
#   GH_TOKEN              — GitHub token with actions:write on the run
#   QUEUE_TIMEOUT_MINUTES — minutes to wait before cancelling still-queued jobs
#   REPO                  — owner/repo of the current workflow run
#   RUN_ID                — workflow run id

set -euo pipefail

: "${GH_TOKEN:?required}"
: "${QUEUE_TIMEOUT_MINUTES:?required}"
: "${REPO:?required}"
: "${RUN_ID:?required}"

# Names whose `status == "queued"` is intentional at this point in the run.
exempt_filter='.name != "Queue Watchdog" and .name != "Merge Gate"'

queued_siblings() {
  gh api --paginate "repos/${REPO}/actions/runs/${RUN_ID}/jobs?per_page=100" \
    --jq ".jobs[] | select(.status == \"queued\" and ${exempt_filter}) | \"\(.id)\t\(.name)\""
}

deadline=$(( $(date +%s) + QUEUE_TIMEOUT_MINUTES * 60 ))
poll_interval=15

# Exit the instant nothing is queued; otherwise keep watching until the deadline.
while :; do
  stuck=$(queued_siblings)
  if [ -z "$stuck" ]; then
    echo "No queued sibling jobs — all scheduled. Nothing to cancel."
    exit 0
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "Timeout (${QUEUE_TIMEOUT_MINUTES}m) reached; cancelling jobs still stuck in queued:"
    break
  fi
  sleep "$poll_interval"
done

while IFS=$'\t' read -r job_id job_name; do
  echo "Cancelling stuck queued job: ${job_name} (id=${job_id})"
  gh api -X POST "repos/${REPO}/actions/jobs/${job_id}/cancel" || true
done <<<"$stuck"
