#!/usr/bin/env python3
"""Fail if a token-gated file exceeds its .token-limits.yaml budget.

Counts with the public, offline tiktoken tokenizer (no API key). First matching
`limits` glob wins (list specific patterns first); `exclude` globs are skipped.
Pairs with the byte file-size gate, which drops .md when this config is present.
"""
import fnmatch
import os
import subprocess
import sys

import tiktoken
import yaml

cfg = yaml.safe_load(open(".token-limits.yaml")) if os.path.exists(".token-limits.yaml") else {}
cfg = cfg if isinstance(cfg, dict) else {}
limits = cfg.get("limits")
limits = limits if isinstance(limits, dict) else {}
exclude = cfg.get("exclude")
exclude = exclude if isinstance(exclude, list) else []
if not limits:
    sys.exit(0)

enc = tiktoken.get_encoding("o200k_base")
SKIP = {".git", "node_modules", "result", ".terraform", ".direnv", ".gh-shared"}


def hit(path, name, pat):
    return fnmatch.fnmatch(path, pat) or fnmatch.fnmatch(name, pat)


def pr_diff_paths():
    """Files the PR actually changed, or None when HEAD isn't a PR merge commit.

    On a `pull_request` checkout, `github.sha` is the merge commit
    (`HEAD^1` = base, `HEAD^2` = PR head), so a two-parent HEAD means this is
    a merge-ref checkout and `HEAD^1...HEAD` is exactly what the PR would add
    to the base branch. A push checkout has one parent, so this returns None
    and callers fall back to scanning the whole tree as before.
    """
    if subprocess.run(
        ["git", "rev-parse", "-q", "--verify", "HEAD^2"], capture_output=True
    ).returncode != 0:
        return None
    diff = subprocess.run(
        ["git", "diff", "--name-only", "HEAD^1...HEAD"], capture_output=True, text=True
    )
    return set(diff.stdout.splitlines()) if diff.returncode == 0 else None


changed = pr_diff_paths()

errors = 0
for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in SKIP]
    for name in files:
        path = os.path.relpath(os.path.join(root, name), ".")
        if changed is not None and path not in changed:
            continue
        if any(hit(path, name, e) for e in exclude):
            continue
        lim = next((v for p, v in limits.items() if isinstance(v, int) and hit(path, name, p)), None)
        if lim is None:
            continue
        try:
            tokens = len(enc.encode(open(os.path.join(root, name), encoding="utf-8").read()))
        except (UnicodeDecodeError, OSError):
            continue
        if tokens > lim:
            print(f"::error file={path}::{path} is {tokens} tokens (exceeds {lim})")
            errors += 1

sys.exit(1 if errors else 0)
