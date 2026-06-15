#!/usr/bin/env bash
# ansible-ci-lint.sh — invoked by the `ansible-lint` job in _ansible-ci.yml.
# Installs lint tooling (system env via uv), the galaxy collections, then runs
# optional yamllint and ansible-lint. Scope + yamllint are driven by env so the
# reusable workflow stays bash-free.
#
# Required: uv on PATH.
# Optional env:
#   YAMLLINT   — "true" to also run `yamllint .`
#   LINT_SCOPE — args for ansible-lint (e.g. "playbooks/ roles/"); empty = whole repo
set -euo pipefail

pkgs=(ansible-lint ansible-core)
[ "${YAMLLINT:-false}" = "true" ] && pkgs+=(yamllint)
uv pip install --system "${pkgs[@]}"

if [ -f requirements.yml ]; then
  ansible-galaxy collection install -r requirements.yml
fi

if [ "${YAMLLINT:-false}" = "true" ]; then
  yamllint .
fi

read -ra scope <<< "${LINT_SCOPE:-}"
ansible-lint "${scope[@]}"
