#!/usr/bin/env bash
# ansible-ci-molecule-deps.sh — invoked by the `molecule` job in _ansible-ci.yml.
# Installs molecule + the docker driver + ansible-core (system env via uv), any
# repo-pinned CI extras (requirements-ci.txt), and the galaxy collections — so no
# repo needs its own molecule-deps step.
#
# Required: uv on PATH. Optional requirements-ci.txt / requirements.yml in cwd.
set -euo pipefail

uv pip install --system \
  molecule 'molecule-plugins[docker]>=23.0.0' 'ansible-core>=2.16' \
  'docker>=7.0.0' 'urllib3<2.0' 'requests<2.32' netaddr ansible-lint

if [ -f requirements-ci.txt ]; then
  uv pip install --system -r requirements-ci.txt
fi

if [ -f requirements.yml ]; then
  ansible-galaxy collection install -r requirements.yml --force
fi
