#!/usr/bin/env bash
# Renovate annotation gate — fails when a version pin sits in a path the
# Renovate preset's annotated-pin customManagers cover (renovate-presets.json
# "Renovate-annotated version pins in Ansible role defaults") but carries no
# `# renovate: datasource=... depName=...` comment above it. An unannotated
# pin in these paths is invisible to Renovate and rots silently — see
# renovate-audit gap #1/#4 (docs.jacobpevans.com/conventions/dependency-automation).
#
# `_image:` keys are exempt: the separate no-annotation docker-image
# customManager already tracks those by pattern, no annotation needed.
#
# Exit codes:
#   0 — every pin in a covered path is annotated
#   1 — one or more unannotated pins found (see stderr for file:line)
#
# Usage: check-renovate-annotations.sh [ROOT]   (ROOT defaults to .)

set -euo pipefail

ROOT="${1:-.}"

# Paths mirror the customManagers' managerFilePatterns in renovate-presets.json.
PATH_ARGS=(
  -path '*/roles/*/defaults/main.yml' -o -path '*/roles/*/defaults/main.yaml'
  -o -path '*/roles/*/defaults/main/*.yml' -o -path '*/roles/*/defaults/main/*.yaml'
  -o -path '*/roles/*/vars/*.yml' -o -path '*/roles/*/vars/*.yaml'
  -o -path '*/roles/*/tasks/*.yml' -o -path '*/roles/*/tasks/*.yaml'
  -o -path '*/roles/*/templates/*'
  -o -path '*/inventory/*.yml' -o -path '*/inventory/*.yaml'
  -o -path '*/group_vars/*.yml' -o -path '*/group_vars/*.yaml'
  -o -path '*/host_vars/*.yml' -o -path '*/host_vars/*.yaml'
  -o -path '*/playbooks/*.yml' -o -path '*/playbooks/*.yaml'
  -o -path '*/scripts/*'
  -o -name 'requirements*.yml' -o -name 'requirements*.yaml'
)

# A pin line's shape — must match the scalar/list-item/git-SHA forms the
# annotated-pin customManagers extract. A generic `foo_image:` never matches
# `_version:`, so it needs no special-case exemption here.
version_re="^[[:space:]]*[A-Za-z0-9_]+_version:[[:space:]]*[\"']?[0-9vV]"
list_pin_re="^[[:space:]]*-[[:space:]]*[\"']?[^\"'[:space:]]+==[0-9]"
git_sha_re="^[[:space:]]*version:[[:space:]]*[\"']?[0-9a-fA-F]{40}"
annotation_re="^[[:space:]]*# renovate:"
comment_re="^[[:space:]]*#"

fail=0

while IFS= read -r -d '' f; do
  # Tracks whether an annotation was seen above, surviving blank lines and
  # any number of plain comment lines in between (mirrors the customManager
  # regex's `(?:\s*#[^\n]*\n)*` gap) — reset only by real content.
  annotated=0
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))

    # Blank line: annotation state carries through to the next line.
    [[ -z "${line//[[:space:]]/}" ]] && continue

    if [[ "$line" =~ $annotation_re ]]; then
      annotated=1
      continue
    fi

    # A plain (non-renovate) comment line: keep whatever state we had.
    if [[ "$line" =~ $comment_re ]]; then
      continue
    fi

    is_pin=0
    if [[ "$line" =~ $version_re || "$line" =~ $list_pin_re || "$line" =~ $git_sha_re ]]; then
      is_pin=1
    fi

    if [[ "$is_pin" -eq 1 && "$annotated" -eq 0 ]]; then
      echo "::error file=${f#./},line=${lineno}::unannotated version pin — add a '# renovate: datasource=... depName=...' comment on the line above (blank lines OK): ${line}" >&2
      fail=1
    fi

    annotated=0
  done <"$f"
done < <(find "$ROOT" -type f \( "${PATH_ARGS[@]}" \) -not -path '*/.git/*' -not -path '*/.worktrees/*' -print0)

if [[ "$fail" -ne 0 ]]; then
  echo "Renovate annotation check FAILED — see file:line entries above." >&2
  exit 1
fi

echo "Renovate annotation check OK."
