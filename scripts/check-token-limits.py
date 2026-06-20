#!/usr/bin/env python3
"""Fail if a token-gated file exceeds its .token-limits.yaml budget.

Counts with the public, offline tiktoken tokenizer (no API key). First matching
`limits` glob wins (list specific patterns first); `exclude` globs are skipped.
Pairs with the byte file-size gate, which drops .md when this config is present.
"""
import fnmatch
import os
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
SKIP = {".git", "node_modules", "result", ".terraform", ".terragrunt-cache", ".direnv", ".gh-shared"}


def hit(path, name, pat):
    return fnmatch.fnmatch(path, pat) or fnmatch.fnmatch(name, pat)


errors = 0
for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in SKIP]
    for name in files:
        path = os.path.relpath(os.path.join(root, name), ".")
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
