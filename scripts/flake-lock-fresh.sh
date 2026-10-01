#!/usr/bin/env bash
# Fail when a direct flake input owned by one of OWNERS is not locked at its branch head.
#
# Usage: flake-lock-fresh.sh [flake.lock]
# Env:   OWNERS            space-separated input owners to check (case-insensitive);
#                          inputs from any other owner are ignored
#        GIT_TOKEN         optional token for private inputs
#        STALE_NAMES_FILE  optional; the stale input names are written there, one per line
# Only root inputs of type github are checked. The branch is original.ref, or the
# repository's default branch when the input names none.
set -euo pipefail

lock=${1:-flake.lock}
[ -f "$lock" ] || { echo "no $lock, nothing to check"; exit 0; }
: "${OWNERS:?OWNERS is required}"
[ -n "${STALE_NAMES_FILE:-}" ] && : >"$STALE_NAMES_FILE"

# name <TAB> owner/repo <TAB> ls-remote ref <TAB> locked rev (no field is ever empty)
inputs=$(jq -r --arg owners "$OWNERS" '
  ($owners | ascii_downcase | split(" ") | map(select(. != ""))) as $ours
  | . as $l | $l.nodes[$l.root].inputs // {} | to_entries[]
  | .key as $name | ($l.nodes[.value | if type == "string" then . else last end]) as $n
  | select($n.original.type? == "github" and (($n.original.owner | ascii_downcase) as $o | $ours | index($o)))
  | [$name, "\($n.original.owner)/\($n.original.repo)",
     (if $n.original.ref then "refs/heads/\($n.original.ref)" else "HEAD" end), $n.locked.rev] | @tsv' "$lock")

stale=0
while IFS=$'\t' read -r name repo want rev; do
  [ -n "$name" ] || continue
  url="https://github.com/$repo.git"
  [ -n "${GIT_TOKEN:-}" ] && url="https://x-access-token:$GIT_TOKEN@github.com/$repo.git"
  head=$(git ls-remote "$url" "$want" | awk -v w="$want" '$2 == w { print $1 }')
  if [ -z "$head" ]; then
    echo "::error::$name: cannot resolve ${want#refs/heads/} of $repo"
    stale=1
  elif [ "$head" != "$rev" ]; then
    echo "::error::$name ($repo ${want#refs/heads/}) locked at $rev, branch head is $head. Run: nix flake update $name"
    [ -n "${STALE_NAMES_FILE:-}" ] && echo "$name" >>"$STALE_NAMES_FILE"
    stale=1
  else
    echo "$name: at head $head"
  fi
done <<<"$inputs"
exit "$stale"
