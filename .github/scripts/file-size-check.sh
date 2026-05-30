#!/usr/bin/env bash
# File-size check executed by .github/workflows/file-size.yml.
#
# Reads org defaults from a trusted file (passed as the only argument) and
# per-repo overrides from the consuming repo's .github/file-size.yml or
# legacy .file-size.yml at root. Override values are attacker-controllable
# on PR runs and are validated against strict regexes before use; the
# defaults file is in the org-controlled checkout and therefore trusted.
#
# Emits GitHub Actions ::warning:: and ::error:: annotations. Exits non-zero
# only when at least one file exceeds the error threshold.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <path-to-defaults-yml>" >&2
  exit 2
fi

DEFAULTS_FILE=$1

if [ ! -f "$DEFAULTS_FILE" ]; then
  echo "::error::defaults file not found: $DEFAULTS_FILE"
  exit 2
fi

# Validators for attacker-controllable override values. yq output is treated
# as untrusted string data; nothing flows into shell eval, but explicit
# format checks block surprise inputs.
is_positive_int() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]; }
is_extension()    { [[ "$1" =~ ^\.[a-zA-Z0-9]+$ ]]; }
is_basename()     { [[ "$1" =~ ^[a-zA-Z0-9_.-]+$ ]]; }

# Org defaults — trusted source, no validation needed.
WARN=$(yq '.defaults.warn' "$DEFAULTS_FILE")
ERR=$(yq '.defaults.error' "$DEFAULTS_FILE")
DEFAULT_SCAN=$(yq '.scan | .[]' "$DEFAULTS_FILE" | tr '\n' ' ')
EXEMPT=" $(yq '.exempt | .[]' "$DEFAULTS_FILE" | tr '\n' ' ')"

# Per-repo override: prefer .github/file-size.yml, fall back to legacy
# .file-size.yml at root (deprecation warning emitted).
OVERRIDE=""
if [ -f ".github/file-size.yml" ]; then
  OVERRIDE=".github/file-size.yml"
elif [ -f ".file-size.yml" ]; then
  OVERRIDE=".file-size.yml"
  echo "::warning::.file-size.yml at repo root is deprecated; move to .github/file-size.yml"
fi

EXT_LIMIT=0
EXTENDED=" "

if [ -n "$OVERRIDE" ]; then
  cand=$(yq ".defaults.warn // $WARN" "$OVERRIDE")
  if is_positive_int "$cand"; then
    WARN=$cand
  else
    echo "::warning file=$OVERRIDE::defaults.warn must be a positive integer; ignoring '$cand'"
  fi

  cand=$(yq ".defaults.error // $ERR" "$OVERRIDE")
  if is_positive_int "$cand"; then
    ERR=$cand
  else
    echo "::warning file=$OVERRIDE::defaults.error must be a positive integer; ignoring '$cand'"
  fi

  cand=$(yq '.extended.limit // 0' "$OVERRIDE")
  if [[ "$cand" =~ ^[0-9]+$ ]]; then
    EXT_LIMIT=$cand
  else
    echo "::warning file=$OVERRIDE::extended.limit must be a non-negative integer; ignoring '$cand'"
  fi

  cfg_scan=""
  while IFS= read -r ext; do
    [ -z "$ext" ] && continue
    if is_extension "$ext"; then
      cfg_scan="$cfg_scan$ext "
    else
      echo "::warning file=$OVERRIDE::scan entry '$ext' must match ^\\.[a-zA-Z0-9]+\$; skipped"
    fi
  done < <(yq '.scan // [] | .[]' "$OVERRIDE")
  [ -n "$cfg_scan" ] && DEFAULT_SCAN="$cfg_scan"

  while IFS= read -r base; do
    [ -z "$base" ] && continue
    if is_basename "$base"; then
      EXTENDED="$EXTENDED$base "
    else
      echo "::warning file=$OVERRIDE::extended.files entry '$base' must match ^[a-zA-Z0-9_.-]+\$; skipped"
    fi
  done < <(yq '.extended.files // [] | .[]' "$OVERRIDE")

  while IFS= read -r base; do
    [ -z "$base" ] && continue
    if is_basename "$base"; then
      EXEMPT="$EXEMPT$base "
    else
      echo "::warning file=$OVERRIDE::exempt entry '$base' must match ^[a-zA-Z0-9_.-]+\$; skipped"
    fi
  done < <(yq '.exempt // [] | .[]' "$OVERRIDE")
fi

# Build find name arguments from scan extensions.
name_args=()
first=true
for ext in $DEFAULT_SCAN; do
  if $first; then
    first=false
  else
    name_args+=(-o)
  fi
  name_args+=(-name "*${ext}")
done

errors=0
warnings=0

while IFS= read -r -d '' f; do
  base="${f##*/}"
  base="${base%.*}"
  size=$(stat -c%s "$f")

  if [[ "$EXEMPT" == *" $base "* ]]; then
    continue
  fi

  if [[ "$EXT_LIMIT" -gt 0 ]] && [[ "$EXTENDED" == *" $base "* ]]; then
    limit=$EXT_LIMIT
    warn_threshold=$limit
  else
    limit=$ERR
    warn_threshold=$WARN
  fi

  if [ "$size" -gt "$limit" ]; then
    echo "::error file=$f::$f is $((size / 1024))KB (exceeds $((limit / 1024))KB limit)"
    errors=$((errors + 1))
  elif [ "$size" -gt "$warn_threshold" ]; then
    echo "::warning file=$f::$f is $((size / 1024))KB (exceeds $((warn_threshold / 1024))KB recommended)"
    warnings=$((warnings + 1))
  fi
done < <(find . -type f \( "${name_args[@]}" \) \
  -not -path "./.git/*" \
  -not -path "./.org-github/*" \
  -not -path "./node_modules/*" \
  -not -path "./result/*" \
  -not -name "*.lock" \
  -not -name "package-lock.json" \
  -not -name "pnpm-lock.yaml" \
  -print0)

echo "File size check: ${errors} error(s), ${warnings} warning(s)"
if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0
