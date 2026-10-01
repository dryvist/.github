#!/usr/bin/env bash
# Check the direct flake inputs owned by one of OWNERS.
#
# Usage: flake-lock-fresh.sh [--pr BASE_LOCK] [flake.lock]
#   default (freshness): fail when an owned input is not locked at its branch head.
#   --pr BASE_LOCK: compare against the base branch's lock, with no live lookup of
#                   branch heads. Fail when an owned input moved to a rev that does
#                   not descend from the base lock's rev. A missing BASE_LOCK means
#                   the lock is new and only the pinned-rev rule applies.
# Env:   OWNERS            space-separated input owners to check (case-insensitive);
#                          inputs from any other owner are ignored. Defaults to OWNED below.
#        GIT_TOKEN         optional token for private inputs
#        STALE_NAMES_FILE  optional; the stale input names are written there, one per line
# Only root inputs of type github are checked. The branch is original.ref, or the
# repository's default branch when the input names none. An owned input pinned to
# a revision (original.rev) fails: ours always track a branch.
set -euo pipefail

base=
if [ "${1:-}" = --pr ]; then base=${2:?--pr needs a base lock path}; shift 2; fi
lock=${1:-flake.lock}
[ -f "$lock" ] || { echo "no $lock, nothing to check"; exit 0; }
# The one list of owners whose flake inputs are ours. JacobPEvans redirects to dryvist.
OWNED="dryvist JacobPEvans JacobPEvans-personal"
OWNERS=${OWNERS:-$OWNED}
[ -n "${STALE_NAMES_FILE:-}" ] && : >"$STALE_NAMES_FILE"

# name <TAB> owner/repo <TAB> ls-remote ref <TAB> locked rev (no field is ever empty)
inputs=$(jq -r --arg owners "$OWNERS" '
  ($owners | ascii_downcase | split(" ") | map(select(. != ""))) as $ours
  | . as $l | $l.nodes[$l.root].inputs // {} | to_entries[]
  | .key as $name | ($l.nodes[.value | if type == "string" then . else last end]) as $n
  | select($n.original.type? == "github" and (($n.original.owner | ascii_downcase) as $o | $ours | index($o)))
  | [$name, "\($n.original.owner)/\($n.original.repo)",
     (if $n.original.rev then "PINNED" elif $n.original.ref then "refs/heads/\($n.original.ref)" else "HEAD" end),
     $n.locked.rev] | @tsv' "$lock")

stale=0
while IFS=$'\t' read -r name repo want rev; do
  [ -n "$name" ] || continue
  if [ "$want" = PINNED ]; then
    echo "::error::owned input $name ($repo) is pinned to a rev; track a branch instead"
    stale=1
    continue
  fi
  if [ -n "$base" ]; then
    old=$([ -f "$base" ] && jq -r --arg n "$name" '. as $l | ($l.nodes[$l.root].inputs // {})[$n] // empty
      | $l.nodes[if type == "string" then . else last end].locked.rev // empty' "$base")
    if [ -z "$old" ] || [ "$old" = "$rev" ]; then
      echo "$name: unchanged from base"
      continue
    fi
    # status is "ahead" when the new rev descends from the base rev.
    auth=()
    [ -n "${GIT_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GIT_TOKEN")
    status=$(curl -fsSL ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/$repo/compare/$old...$rev" | jq -r .status) || status=unknown
    if [ "$status" = ahead ]; then
      echo "$name: $old -> $rev moves forward"
    else
      echo "::error::$name ($repo) moves from $old to $rev, which does not descend from it ($status)"
      stale=1
    fi
    continue
  fi
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
