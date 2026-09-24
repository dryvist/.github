#!/usr/bin/env bash
# terrakube-gated-apply.sh — invoked by the `trigger` job in _converge.yml
# for target: terrakube-apply.
#
# Cancels any already-queued job for the workspace, plans from the working
# directory, creates a plan-and-apply job pinned to that plan's own upload,
# approves it only when the plan's own summary shows zero destroys, and
# waits for a terminal state. Terrakube has no native FIFO cancel for queued
# jobs (issues terrakube-io/terrakube#1957, #2850), so step 1 does it.
#
# Required env:
#   TERRAKUBE_API_ADDR   — e.g. https://terrakube-api.example.com
#   TERRAKUBE_TOKEN       — bearer token, GitHub OIDC exchanged directly via
#                           Terrakube's own Federated OIDC Authentication
#                           (org Security -> Federated Credentials), never an
#                           OpenBao-minted credential — Terrakube has no
#                           OpenBao integration to mint against.
#   TERRAKUBE_ORG_ID      — organization UUID
#   TERRAKUBE_WORKSPACE_ID — workspace UUID
#   INFRA_REPO            — owner/repo of the infrastructure root, e.g.
#                           dryvist/tofu-proxmox
#   INFRA_REF             — release tag pinning that repo
#   WAIT_MINUTES          — bounded poll budget for the terminal-state wait
#
# Run from a checkout of the desired-state repository (the one carrying
# deployment.json at its root) — this script clones INFRA_REPO@INFRA_REF
# into a scratch directory, copies deployment.json into it, and plans
# from there.
set -euo pipefail

api() {
  # $1 method, $2 path (from $TERRAKUBE_API_ADDR), rest curl args
  local method=$1 path=$2
  shift 2
  curl -fsS --max-time 30 -X "$method" \
    -H "Authorization: Bearer ${TERRAKUBE_TOKEN}" \
    -H "Content-Type: application/vnd.api+json" \
    -H "Accept: application/vnd.api+json" \
    "${TERRAKUBE_API_ADDR%/}${path}" "$@"
}

# Cancels any job still `pending` or `waitingApproval` for the workspace, so
# an older push never applies after a newer one supersedes it.
cancel_queued_jobs() {
  local ids
  ids=$(api GET "/api/v1/organization/${TERRAKUBE_ORG_ID}/workspace/${TERRAKUBE_WORKSPACE_ID}/job" |
    jq -r '.data[] | select(.attributes.status == "pending" or .attributes.status == "waitingApproval") | .id')
  local id
  for id in $ids; do
    echo "cancelling queued job ${id}"
    api PATCH "/api/v1/organization/${TERRAKUBE_ORG_ID}/job/${id}" \
      -d '{"data":{"type":"job","attributes":{"status":"cancelled"}}}' >/dev/null
  done
}

# Creates the plan-and-apply job, pinned to $1 (a configuration-version
# terraformContent.tar.gz URL), using template $2. Prints the new job id.
create_job() {
  local override_source=$1 template_id=$2
  api POST "/api/v1/organization/${TERRAKUBE_ORG_ID}/job" -d "$(
    jq -n --arg t "$template_id" --arg src "$override_source" --arg ws "$TERRAKUBE_WORKSPACE_ID" '
      {data: {type: "job", attributes: {
        templateReference: $t,
        overrideBranch: "remote-content",
        overrideSource: $src
      }, relationships: {workspace: {data: {type: "workspace", id: $ws}}}}}'
  )" | jq -r '.data.id'
}

# Reads job $1's Plan step output and decides approve vs. park. Prints
# "approve" or "park: <summary line>".
gate_plan() {
  local job_id=$1
  local plan_step_id output
  # The job's `step` relationship lists step ids; the Plan step is
  # stepNumber 100 (fixed by the plan-and-apply template's tcl).
  plan_step_id=$(api GET "/api/v1/organization/${TERRAKUBE_ORG_ID}/job/${job_id}/step" |
    jq -r '.data[] | select(.attributes.stepNumber == 100) | .id')
  output=$(api GET "/api/v1/organization/${TERRAKUBE_ORG_ID}/job/${job_id}/step/${plan_step_id}" | jq -r '.data.attributes.output')
  local log
  log=$(curl -fsS --max-time 30 -H "Authorization: Bearer ${TERRAKUBE_TOKEN}" "$output")
  local summary
  summary=$(printf '%s\n' "$log" | grep -Eo 'Plan: [0-9]+ to add, [0-9]+ to change, [0-9]+ to destroy\.' | tail -1)
  if [[ -z $summary ]]; then
    # No changes at all reads as a clean, approvable no-op.
    if printf '%s\n' "$log" | grep -q 'No changes'; then
      echo "approve"
      return
    fi
    echo "park: could not find a plan summary line"
    return
  fi
  local destroy
  destroy=$(printf '%s\n' "$summary" | grep -Eo '[0-9]+ to destroy' | grep -Eo '^[0-9]+')
  if [[ $destroy -eq 0 ]]; then
    echo "approve"
  else
    echo "park: ${summary}"
  fi
}

# Clones INFRA_REPO@INFRA_REF into $1 (a fresh directory) and copies this
# checkout's deployment.json into its root. Asserts the copy matches the
# source byte-for-byte — that directory becomes the tarball `tofu plan`
# uploads, so this is checking the tarball's content, not a proxy for it.
assemble_tree() {
  local tree_dir=$1
  git clone --quiet --depth 1 --branch "$INFRA_REF" \
    "https://github.com/${INFRA_REPO}.git" "$tree_dir"
  cp deployment.json "${tree_dir}/deployment.json"
  cmp -s deployment.json "${tree_dir}/deployment.json" || {
    echo "::error::deployment.json did not copy into the assembled tree unchanged"
    exit 1
  }
}

approve_job() {
  api PATCH "/api/v1/organization/${TERRAKUBE_ORG_ID}/job/$1" \
    -d '{"data":{"type":"job","attributes":{"status":"approved"}}}' >/dev/null
}

# Polls job $1's status until it is one of the terminal states or
# $WAIT_SECONDS elapses. Prints the final status.
wait_for_terminal() {
  local job_id=$1 elapsed=0 status
  while (( elapsed < WAIT_SECONDS )); do
    status=$(api GET "/api/v1/organization/${TERRAKUBE_ORG_ID}/job/${job_id}" | jq -r '.data.attributes.status')
    case "$status" in
      completed|failed|cancelled|rejected|denied) echo "$status"; return ;;
    esac
    sleep 10
    elapsed=$((elapsed + 10))
  done
  echo "timeout"
}

main() {
  : "${TERRAKUBE_API_ADDR:?required}"
  : "${TERRAKUBE_TOKEN:?required}"
  : "${TERRAKUBE_ORG_ID:?required}"
  : "${TERRAKUBE_WORKSPACE_ID:?required}"
  : "${TERRAKUBE_TEMPLATE_ID:?required}"
  : "${INFRA_REPO:?required}"
  : "${INFRA_REF:?required}"
  : "${WAIT_MINUTES:=10}"
  local WAIT_SECONDS=$((WAIT_MINUTES * 60))

  cancel_queued_jobs

  local tree_dir
  tree_dir=$(mktemp -d)
  assemble_tree "$tree_dir"

  # UNRESOLVED, flagged rather than guessed: a plain `tofu plan` run from
  # this tree uploads a configuration version and prints a run URL whose
  # last path segment is the job id (per the confirmed job-1026 precedent —
  # its id equals its run number). This still needs one live confirmation:
  # does that CLI-created job's own `overrideSource` already carry the
  # tarball URL this script can reuse for create_job, or does the
  # configuration version live under a different field/endpoint on that
  # job? Placeholder until confirmed:
  local plan_run_output
  plan_run_output=$(cd "$tree_dir" && tofu init -no-color && tofu plan -no-color 2>&1) || { echo "$plan_run_output"; exit 1; }
  local plan_job_id
  plan_job_id=$(printf '%s\n' "$plan_run_output" | grep -Eo '/runs/[A-Za-z0-9_-]+' | tail -1 | sed 's#/runs/##')
  [[ -n $plan_job_id ]] || { echo "::error::could not parse a run id from tofu plan's output"; exit 1; }
  local override_source
  override_source=$(api GET "/api/v1/organization/${TERRAKUBE_ORG_ID}/job/${plan_job_id}" | jq -r '.data.attributes.overrideSource')
  [[ -n $override_source && $override_source != null ]] || {
    echo "::error::job ${plan_job_id} has no overrideSource — the plain-plan-to-configuration-version lookup needs re-checking, see the comment above this line"
    exit 1
  }

  local job_id
  job_id=$(create_job "$override_source" "$TERRAKUBE_TEMPLATE_ID")
  echo "created job ${job_id}"

  local decision
  decision=$(gate_plan "$job_id")
  if [[ $decision == approve ]]; then
    approve_job "$job_id"
  else
    echo "::notice::parking job ${job_id}: ${decision#park: }"
    echo "confirmation_url=${TERRAKUBE_API_ADDR}/api/v1/organization/${TERRAKUBE_ORG_ID}/job/${job_id}" >>"${GITHUB_OUTPUT:-/dev/null}"
    exit 0
  fi

  local final_status
  final_status=$(wait_for_terminal "$job_id")
  echo "confirmation_url=${TERRAKUBE_API_ADDR}/api/v1/organization/${TERRAKUBE_ORG_ID}/job/${job_id}" >>"${GITHUB_OUTPUT:-/dev/null}"
  [[ $final_status == completed ]] || { echo "::error::job ${job_id} ended in ${final_status}"; exit 1; }
  echo "job ${job_id} completed"
}

# --self-check: exercises gate_plan's parsing against fixture logs, without
# a runner or a real Terrakube. The part self-check cannot cover — the
# plain-plan-to-configuration-version lookup above — is exactly the part
# flagged UNRESOLVED in main(); this cannot self-check a fact not yet
# confirmed against a live system.
if [[ ${1:-} == --self-check ]]; then
  fail=0
  export TERRAKUBE_ORG_ID=org1 TERRAKUBE_TOKEN=fake-token

  check_gate() {
    local _fixture_log=$1 want=$2
    curl() { printf '%s' "$_fixture_log"; }
    api() {
      case "$2" in
        */step) echo '{"data":[{"id":"s1","attributes":{"stepNumber":100}}]}' ;;
        *) echo '{"data":{"attributes":{"output":"http://fixture"}}}' ;;
      esac
    }
    local got
    got=$(gate_plan job1)
    [[ $got == "$want"* ]] || { echo "FAIL: log=$_fixture_log -> got '$got', want prefix '$want'" >&2; fail=1; }
  }

  check_gate $'Plan: 2 to add, 0 to change, 0 to destroy.' "approve"
  check_gate $'Plan: 1 to add, 0 to change, 1 to destroy.' "park"
  check_gate $'No changes. Your infrastructure matches the configuration.' "approve"
  check_gate $'garbage, no plan summary here' "park"

  [[ $fail == 0 ]] && echo "self-check OK: 4 cases"
  exit $fail
fi

main "$@"
