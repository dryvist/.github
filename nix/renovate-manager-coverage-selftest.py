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

    failures.extend(check_requirements_managers(preset))

    if failures:
        print("Renovate manager coverage FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1

    print(f"Renovate manager coverage OK ({len(managers)} role-defaults managers)")
    return 0



# --- requirements.yml managers -------------------------------------------
# These match on file path AND on content. A managerFilePatterns regex that
# matches no file fails silently; so does a matchStrings regex that matches no
# TEXT. The second failure is the one that actually bit us -- the git-pinned
# collections in requirements.yml were invisible to every manager, so nothing
# ever proposed moving a SHA that had been frozen for months.

REQUIREMENTS_MARKER = "requirements"

REQUIREMENTS_MUST_MATCH = [
    "requirements.yml",
    "ansible/requirements.yaml",
]
REQUIREMENTS_MUST_NOT_MATCH = [
    "requirements.txt",
    "docs/requirements-notes.yml",
]

# Real shapes, not toys: a git digest pin carrying a currentValue annotation,
# and an upstream-release watch on a forked dependency.
GIT_PIN_SAMPLE = """
  # renovate: datasource=git-refs depName=https://github.com/acme/contracts.git currentValue=main
  - name: https://github.com/acme/contracts.git#/ansible/
    type: git
    version: eb4d69b489e8ad1e49f65d2dfc91d170ca7a77cb
"""

UPSTREAM_WATCH_SAMPLE = """
  # renovate: datasource=galaxy depName=community.example
  # upstream-latest: 2.0.0
  - name: https://github.com/someone/community.example.git
    type: git
    version: 5ba27669fa069899306077f9d108a0b737a57bb3
"""

# A Galaxy-versioned entry must NOT be picked up by the git-digest manager --
# the built-in ansible-galaxy manager already owns those.
PLAIN_GALAXY_SAMPLE = """
  - name: community.docker
    version: ">=3.6.0"
"""


def _py_regex(pattern: str) -> "re.Pattern[str]":
    """Renovate writes (?<name>...); Python requires (?P<name>...)."""
    return re.compile(pattern.replace("(?<", "(?P<").replace("(?P<=", "(?<="))


def check_requirements_managers(preset: dict) -> list[str]:
    managers = [
        m
        for m in preset.get("customManagers", [])
        if any(
            REQUIREMENTS_MARKER in p
            for p in m.get("managerFilePatterns", [])
        )
    ]
    if not managers:
        return ["no requirements.yml customManager found"]

    problems = []
    for manager in managers:
        desc = manager.get("description", "<undescribed>")
        name = (desc[0] if isinstance(desc, list) else desc)[:60]
        pats = patterns_of(manager)

        for path in REQUIREMENTS_MUST_MATCH:
            if not any(p.search(path) for p in pats):
                problems.append(f"{name!r}: does NOT match {path} (it must)")
        for path in REQUIREMENTS_MUST_NOT_MATCH:
            if any(p.search(path) for p in pats):
                problems.append(f"{name!r}: matches {path} (it must not)")

        # Content coverage: every manager must match at least one real sample,
        # and none may claim a plain Galaxy pin.
        matchers = [_py_regex(s) for s in manager.get("matchStrings", [])]
        hit_any = any(
            m.search(sample)
            for m in matchers
            for sample in (GIT_PIN_SAMPLE, UPSTREAM_WATCH_SAMPLE)
        )
        if not hit_any:
            problems.append(
                f"{name!r}: matchStrings match NEITHER real sample "
                "— the manager is inert"
            )
        for m in matchers:
            if m.search(PLAIN_GALAXY_SAMPLE):
                problems.append(
                    f"{name!r}: matches a plain Galaxy pin (the built-in "
                    "ansible-galaxy manager owns those)"
                )

    # Between them the managers must cover BOTH shapes, not the same one twice.
    all_matchers = [
        _py_regex(s) for m in managers for s in m.get("matchStrings", [])
    ]
    for label, sample in (
        ("git digest pin", GIT_PIN_SAMPLE),
        ("upstream-release watch", UPSTREAM_WATCH_SAMPLE),
    ):
        if not any(m.search(sample) for m in all_matchers):
            problems.append(f"no manager matches the {label} shape")
    return problems


if __name__ == "__main__":
    sys.exit(main())
