#!/usr/bin/env bash
# Disclosure denylist scan — fails a PR if any changed file, the PR title, or
# the PR body contains a fixed string from the org denylist
# (DISCLOSURE_DENYLIST, materialized to a file by the caller workflow).
#
# The denylist itself is sensitive (the terms it lists are exactly what must
# never appear publicly), so a hit is reported as `path:line` ONLY — never
# the matched term, never the line content. Printing either would re-leak
# the very thing the scan exists to catch.
#
# Usage: disclosure-denylist-scan.sh <denylist-file> <base-ref>
#   <denylist-file> — one fixed string per line (blank lines / #-comments skipped)
#   <base-ref>      — git ref to diff against for the changed-file set
#
# Reads PR_TITLE / PR_BODY from the environment (may be unset outside a PR).
#
# Exit codes:
#   0 — no hits
#   1 — one or more hits (see stdout for path:line)
#   2 — instrument error (missing/empty denylist file, bad base ref)

set -euo pipefail

DENYLIST_FILE="${1:?usage: disclosure-denylist-scan.sh <denylist-file> <base-ref>}"
BASE_REF="${2:?usage: disclosure-denylist-scan.sh <denylist-file> <base-ref>}"

if [[ ! -s "$DENYLIST_FILE" ]]; then
  echo "::error::denylist file missing or empty: $DENYLIST_FILE" >&2
  exit 2
fi

# Strip blank lines and #-comments so an operator can annotate the source list.
PATTERNS_FILE="$(mktemp)"
trap 'rm -f "$PATTERNS_FILE"' EXIT
grep -vE '^[[:space:]]*(#|$)' "$DENYLIST_FILE" > "$PATTERNS_FILE"

if [[ ! -s "$PATTERNS_FILE" ]]; then
  echo "::error::denylist file has no active patterns after stripping comments/blanks" >&2
  exit 2
fi

hits=0

scan_file() {
  local label="$1" path="$2"
  [[ -f "$path" ]] || return 0
  # -H forces the "path:line:content" shape even for a single file; cut
  # drops the content field so only "label:line" ever reaches stdout.
  while IFS=: read -r _path lineno; do
    [[ -n "$lineno" ]] || continue
    echo "${label}:${lineno}"
    hits=$((hits + 1))
  done < <(grep -niHFf "$PATTERNS_FILE" -- "$path" | cut -d: -f1,2 || true)
}

# Changed files in the PR diff (working tree vs. base ref).
if git rev-parse -q --verify "$BASE_REF" >/dev/null; then
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    scan_file "$f" "$f"
  done < <(git diff --name-only "$BASE_REF"...HEAD -- . 2>/dev/null || true)
else
  echo "::error::base ref not found: $BASE_REF" >&2
  exit 2
fi

# PR title / body, scanned the same way via pseudo-files so no title/body
# text is ever echoed back — only "PR title:1" / "PR body:<n>" on a hit.
if [[ -n "${PR_TITLE:-}" ]]; then
  title_file="$(mktemp)"
  printf '%s\n' "$PR_TITLE" > "$title_file"
  scan_file "PR title" "$title_file"
  rm -f "$title_file"
fi
if [[ -n "${PR_BODY:-}" ]]; then
  body_file="$(mktemp)"
  printf '%s\n' "$PR_BODY" > "$body_file"
  scan_file "PR body" "$body_file"
  rm -f "$body_file"
fi

if [[ "$hits" -gt 0 ]]; then
  echo "::error::disclosure denylist: ${hits} hit(s) — see path:line above" >&2
  exit 1
fi

echo "Disclosure denylist: 0 hits."
exit 0
