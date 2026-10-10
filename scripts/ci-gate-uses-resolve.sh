#!/usr/bin/env bash
# Fails when a caller workflow's `uses:` names a reusable workflow or local
# path that does not exist.
#   ./.github/workflows/<file>            must exist in the checked-out repo
#   dryvist/<repo>/.github/workflows/<file>@<ref>
#                                         must exist at <ref>, read via the API
# Other `uses:` values (actions, non-dryvist workflows) are not checked here.
# actionlint does not resolve either form, so this check is the enforcement.
#
# Environment:
#   GH_TOKEN  token for `gh api` (dryvist remote refs only)
set -euo pipefail

errors=0

fail() {
  echo "::error file=${1}::${1} calls ${2}, which does not resolve (${3})"
  errors=$((errors + 1))
}

shopt -s nullglob
for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
  while IFS= read -r line; do
    value=${line#*uses:}
    value=${value%%#*}
    value=$(printf '%s' "$value" | tr -d "\"' \t")

    case "$value" in
      ./.github/workflows/*)
        if [[ ! -f "${value#./}" ]]; then
          fail "$wf" "$value" "local file missing"
        fi
        ;;
      dryvist/*/.github/workflows/*@*)
        rest=${value#dryvist/}
        repo=${rest%%/*}
        rest=${rest#*/}
        file=${rest%@*}
        ref=${value##*@}
        file=${file#.github/workflows/}
        if ! gh api --method HEAD \
          "repos/dryvist/${repo}/contents/.github/workflows/${file}?ref=${ref}" \
          >/dev/null 2>&1; then
          fail "$wf" "$value" "not found at ref, or not readable with this token"
        fi
        ;;
    esac
  done < <(grep -E '^[[:space:]]*(-[[:space:]]+)?uses:' "$wf" || true)
done

if [[ "$errors" -gt 0 ]]; then
  echo "uses resolve check: ${errors} unresolved reference(s)"
  exit 1
fi
echo "uses resolve check: all reusable workflow references resolve"
