#!/usr/bin/env bash
# ansible-ci-doppler-export.sh — invoked by the `molecule` job in _ansible-ci.yml
# when molecule_doppler_keys is set. Downloads the Doppler config once and exports
# ONLY the named keys to GITHUB_ENV (masked) — least-privilege: no inject-env-vars,
# so no unrelated secret lands in the job environment.
#
# Required env:
#   DOPPLER_TOKEN   — service token
#   KEYS            — space-separated secret names to export
#   PROJECT, CONFIG — Doppler project / config
#   GITHUB_ENV      — the job-env file
set -euo pipefail
: "${DOPPLER_TOKEN:?required}"
: "${KEYS:?required}"
: "${PROJECT:?required}"
: "${CONFIG:?required}"
: "${GITHUB_ENV:?required}"

curl -Ls --proto '=https' --tlsv1.2 https://cli.doppler.com/install.sh \
  | sh -s -- --no-package-manager >/dev/null

json=$(doppler secrets download --no-file --format json --project "$PROJECT" --config "$CONFIG")
for k in $KEYS; do
  v=$(printf '%s' "$json" | jq -r --arg k "$k" '.[$k] // empty')
  if [ -n "$v" ]; then
    echo "::add-mask::$v"
    echo "$k=$v" >> "$GITHUB_ENV"
  fi
done
