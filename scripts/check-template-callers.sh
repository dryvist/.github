#!/usr/bin/env bash
# Static caller-contract check. Each caller is a workflow whose job calls
# _ci-gate.yml; every caller is checked against this checkout's
# .github/workflows/_ci-gate.yml:
#   1. each `with:` key of the calling job is an on.workflow_call.inputs key;
#   2. each input marked `required: true` is passed;
#   3. the calling job's permissions grant reaches the highest level each scope
#      needs across the gate's jobs (a job without a block inherits the workflow
#      default) and across the ./ reusables those jobs call;
#   4. the calling job uses dryvist/.github/.github/workflows/_ci-gate.yml@v1 and
#      its `profile:` input is one of the presets the gate accepts.
#
# A caller is named in messages by its file name without .yml. Needs mikefarah
# yq v4 (preinstalled on ubuntu-24.04). Shorthand permissions (read-all) are not
# supported: yq fails on them, and a failed query fails the check.
#
# Usage: scripts/check-template-callers.sh <caller.yml>...
# Exit codes:
#   0 — every caller matches the gate
#   1 — a mismatch, or a caller with no job that calls _ci-gate.yml

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <caller.yml>..." >&2
  exit 2
fi
if ! yq --version 2>&1 | grep -q mikefarah; then
  echo "::error::needs mikefarah yq v4 on PATH" >&2
  exit 1
fi

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gate="${repo}/.github/workflows/_ci-gate.yml"
# The reusable every caller pins, and the profile presets its `profile` input accepts.
gate_ref="dryvist/.github/.github/workflows/_ci-gate.yml@v1"
profiles="ansible nix tofu python docs"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail=0

err() {
  echo "::error::$*"
  fail=1
}

# Rank of a permission level: none 0, read 1, write 2.
rank() {
  case "$1" in
    write) echo 2 ;;
    read) echo 1 ;;
    *) echo 0 ;;
  esac
}

# "scope level" for every permission a workflow's jobs request, then the same
# for each ./ reusable they call. Other repositories are not in this checkout.
requested() {
  local file=$1 depth=$2 uses path
  if ((depth > 5)); then
    echo "::error::reusable nesting deeper than 5 at ${file#"$repo"/}" >&2
    exit 1
  fi
  # A job without a permissions block inherits the workflow default: parent(2)
  # is the document root from a job node (job -> jobs map -> root).
  yq -r '.jobs[] | (.permissions // parent(2).permissions // {}) | to_entries[] | "\(.key) \(.value)"' "$file"
  uses=$(yq -r '.jobs[] | select((.uses // "") | test("^\\./")) | .uses' "$file")
  while read -r path; do
    if [[ -n $path ]]; then
      requested "${repo}/${path#./}" $((depth + 1))
    fi
  done <<< "$uses"
}

# Highest level per scope, from "scope level" lines on stdin.
highest() {
  awk 'function rank(l) { return l == "write" ? 2 : (l == "read" ? 1 : 0) }
    NF == 2 && rank($2) > rank(top[$1]) { top[$1] = $2 }
    END { for (s in top) print s, top[s] }'
}

check_caller() {
  local file=$1 name jobs job passed granted scope need_level have uses profile
  name=$(basename "$file" .yml)
  jobs=$(yq -r '.jobs | to_entries[] | select((.value.uses // "") | contains("_ci-gate.yml")) | .key' "$file")
  if [[ -z $jobs ]]; then
    err "${name}: no job calls _ci-gate.yml"
    return 0
  fi
  while read -r job; do
    [[ -n $job ]] || continue
    uses=$(JOB="$job" yq -r '.jobs[env(JOB)].uses' "$file")
    [[ $uses == "$gate_ref" ]] ||
      err "${name}: job '${job}' calls ${uses}, not ${gate_ref}"
    profile=$(JOB="$job" yq -r '.jobs[env(JOB)].with.profile // ""' "$file")
    if [[ -z $profile ]]; then
      err "${name}: job '${job}' omits the profile input (one of: ${profiles})"
    elif [[ " $profiles " != *" $profile "* ]]; then
      err "${name}: job '${job}' passes profile '${profile}' (one of: ${profiles})"
    fi
    passed=$(JOB="$job" yq -r '(.jobs[env(JOB)].with // {}) | keys | .[]' "$file")
    while read -r key; do
      [[ -n $key ]] || continue
      grep -qxF "$key" "$work/inputs" ||
        err "${name}: job '${job}' passes '${key}', which is not an input of _ci-gate.yml"
    done <<< "$passed"
    while read -r key; do
      [[ -n $key ]] || continue
      grep -qxF "$key" <<< "$passed" ||
        err "${name}: job '${job}' omits required input '${key}'"
    done < "$work/required"
    granted=$(JOB="$job" yq -r '(.jobs[env(JOB)].permissions // .permissions // {}) | to_entries[] | "\(.key) \(.value)"' "$file")
    while read -r scope need_level; do
      [[ -n $scope ]] || continue
      have=$(awk -v s="$scope" '$1 == s { print $2 }' <<< "$granted")
      if (($(rank "${have:-none}") < $(rank "$need_level"))); then
        err "${name}: job '${job}' grants ${scope}: ${have:-none}; _ci-gate.yml needs ${need_level}"
      fi
    done < "$work/need"
  done <<< "$jobs"
}

yq -r '(.on.workflow_call.inputs // {}) | keys | .[]' "$gate" > "$work/inputs"
yq -r '(.on.workflow_call.inputs // {}) | to_entries[] | select(.value.required == true) | .key' "$gate" > "$work/required"
requested "$gate" 0 > "$work/need.raw"
highest < "$work/need.raw" > "$work/need"

for caller in "$@"; do
  check_caller "$caller"
done

if ((fail)); then
  exit 1
fi
echo "every caller matches $(basename "$gate")"
