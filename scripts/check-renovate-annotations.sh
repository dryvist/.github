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
# Escape hatch: a pin that is deliberately NOT a Renovate-trackable
# dependency (a PVE-host expected-version guard, an ISO/template name with
# no public datasource) satisfies this checker with a bare
# `# renovate: ignore — <reason>` comment. The checker requires the FULL
# `datasource=... depName=...[ versioning=...]` shape or a bare `ignore`
# (not just a `# renovate:` prefix — a typo like `datasorce=` or a double
# space after the colon used to still pass a prefix-only check while
# matching no real renovate-presets.json matchString, so the pin stayed
# silently untracked despite green CI); the preset's own matchStrings
# additionally require the literal `datasource=` token, so an `ignore`
# comment is annotated enough to pass here while never matching a real
# customManager and never producing a Renovate PR.
#
# Exit codes:
#   0 — every pin in a covered path is annotated
#   1 — one or more unannotated pins found (see stderr for file:line)
#   2 — instrument error: zero files matched the covered path set. A repo
#       that opts into this check but has no covered files is misconfigured
#       (wrong ROOT, or none of roles/*/defaults|vars|tasks|templates,
#       inventory/, group_vars/, host_vars/, playbooks/, scripts/,
#       requirements*.yml exist here) — NOT evidence of a clean repo. A
#       "0 files, 0 unannotated" run must never look identical to "OK".
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
# The FULL line shape, not just the `# renovate:` prefix — a typo
# (`datasorce=`) or a double space after the colon used to still satisfy a
# prefix-only check, passing this gate while matching no real
# renovate-presets.json matchString (those require the exact `datasource=`
# token), so the pin stayed silently untracked despite a "passing" CI run.
# bash's =~ uses POSIX ERE (no `(?:...)`), so groups here are plain `(...)`.
annotation_re="^[[:space:]]*# renovate: (datasource=[^[:space:]]+ depName=[^[:space:]]+( versioning=[^[:space:]]+)?( .*)?|ignore([[:space:]].*)?)\$"
comment_re="^[[:space:]]*#"

files_scanned=0
pins_seen=0
unannotated=0

while IFS= read -r -d '' f; do
  files_scanned=$((files_scanned + 1))

  # Tracks whether an annotation was seen above, surviving blank lines and
  # any number of plain comment lines in between (mirrors the customManager
  # regex's `(?:\s*#[^\n]*\n)*` gap) — reset only by real content.
  annotated=0
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    # CRLF files: strip the trailing \r `read -r` leaves in place, otherwise
    # the new `$`-anchored annotation_re never matches (the \r sits before
    # the anchor) and a stray \r leaks into the ::error text below.
    line=${line%$'\r'}

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

    if [[ "$is_pin" -eq 1 ]]; then
      pins_seen=$((pins_seen + 1))
      if [[ "$annotated" -eq 0 ]]; then
        unannotated=$((unannotated + 1))
        echo "::error file=${f#./},line=${lineno}::unannotated version pin — add a '# renovate: datasource=... depName=...' comment on the line above (blank lines OK), or '# renovate: ignore — <reason>' if this is deliberately not a Renovate-trackable dependency: ${line}" >&2
      fi
    fi

    annotated=0
  done <"$f"
done < <(find "$ROOT" -type f \( "${PATH_ARGS[@]}" \) -not -path '*/.git/*' -not -path '*/.worktrees/*' -print0)

echo "scanned ${files_scanned} files, ${pins_seen} pins, ${unannotated} unannotated" >&2

if [[ "$files_scanned" -eq 0 ]]; then
  echo "Renovate annotation check ERROR: zero files matched the covered path set under '${ROOT}'." >&2
  echo "Covered paths: roles/*/defaults|vars|tasks|templates, inventory/, group_vars/, host_vars/, playbooks/, scripts/, requirements*.yml." >&2
  echo "A repo that opts into this check but has none of those paths is misconfigured (wrong ROOT, or the toggle shouldn't be enabled here) — this is not evidence of a clean repo." >&2
  exit 2
fi

if [[ "$unannotated" -ne 0 ]]; then
  echo "Renovate annotation check FAILED — see file:line entries above." >&2
  exit 1
fi

echo "Renovate annotation check OK."
