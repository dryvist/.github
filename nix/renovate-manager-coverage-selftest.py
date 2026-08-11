#!/usr/bin/env python3
"""Assert the Ansible role-defaults Renovate managers match both defaults layouts.

A `managerFilePatterns` regex that matches nothing fails silently — no warning,
no error, the file just stops appearing on the Dependency Dashboard. So the
patterns are checked against real path shapes rather than eyeballed.

Usage: renovate-manager-coverage-selftest.py <path to renovate-presets.json>
"""

import json
import re
import sys

# Renovate writes a regex pattern as "/.../" and a glob as a bare string.
# Only the regex form is used by these managers.
RE_DELIMITED = re.compile(r"^/(.*)/$")

# Paths every Ansible role-defaults manager must see. The `main/` entries are
# the split layout that a token-budget refactor produces.
MUST_MATCH = [
    "roles/hermes_agent/defaults/main.yml",
    "roles/qdrant_docker/defaults/main.yaml",
    "roles/hermes_agent/defaults/main/10-installer-and-bundles.yml",
    "roles/openbao/defaults/main/00-install-and-node.yml",
    "roles/llm_router/defaults/main/30-openrouter.yaml",
]

# Paths they must NOT see. `vars/` and `tasks/` are different file kinds, and a
# sibling named `main-extra.yml` is not a defaults file — a lazy `main.*`
# pattern would swallow all three.
MUST_NOT_MATCH = [
    "roles/hermes_agent/vars/main.yml",
    "roles/hermes_agent/tasks/main.yml",
    "roles/hermes_agent/defaults/main-extra.yml",
    "roles/hermes_agent/defaults/main/README.md",
]

# Identified by what they match on, not by list position — reordering the
# managers in the preset must not silently skip the assertion.
DEFAULTS_MANAGER_MARKER = "/defaults/main"


def patterns_of(manager: dict) -> list[re.Pattern[str]]:
    compiled = []
    for raw in manager.get("managerFilePatterns", []):
        delimited = RE_DELIMITED.match(raw)
        if not delimited:  # a glob, not a regex — not our concern here
            continue
        compiled.append(re.compile(delimited.group(1)))
    return compiled


def main() -> int:
    preset = json.load(open(sys.argv[1]))
    managers = [
        m
        for m in preset.get("customManagers", [])
        if any(
            DEFAULTS_MANAGER_MARKER in p
            for p in m.get("managerFilePatterns", [])
        )
    ]

    failures = []
    if not managers:
        failures.append(
            "no role-defaults customManager found — did the marker path change?"
        )

    for manager in managers:
        # The description is a string or a list of strings; either way its head
        # is enough to name which manager failed.
        desc = manager.get("description", "<undescribed>")
        name = (desc[0] if isinstance(desc, list) else desc)[:60]
        pats = patterns_of(manager)

        for path in MUST_MATCH:
            if not any(p.search(path) for p in pats):
                failures.append(f"{name!r}: does NOT match {path} (it must)")
        for path in MUST_NOT_MATCH:
            if any(p.search(path) for p in pats):
                failures.append(f"{name!r}: matches {path} (it must not)")

    if failures:
        print("Renovate manager coverage FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1

    print(f"Renovate manager coverage OK ({len(managers)} role-defaults managers)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
