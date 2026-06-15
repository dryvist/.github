#!/usr/bin/env python3
"""Token-limit checker (no API key; offline tiktoken).

Reads ``.token-limits.yaml`` from the current working directory and fails
(exit 1) on any file that exceeds its token budget. Counts tokens with the
public, open-source ``tiktoken`` tokenizer (OpenAI ``o200k_base``) — a stable
proxy for "keep this doc lean"; exact Anthropic counts are not needed and are
not available without auth.

Pairs with ``_file-size.yml`` (byte gate): a file is **token-gated** iff it
matches a ``limits`` fnmatch pattern, and the byte gate skips those files — so
every file is governed by exactly one gate.

.token-limits.yaml (all keys optional):
    defaults: { max_tokens: 2000 }   # budget for files matched only by a
                                      # catch-all pattern that omits a value
    exclude:  ['TERRAFORM.md']        # globs skipped by BOTH gates (machine output)
    limits:                           # fnmatch patterns -> max tokens.
      AGENTS.md: 2000                 # Matching is tried against the full repo
      '*README.md': 1500             # path AND the basename; '*' spans '/'.
      'docs/*.md': 3000              # Most-restrictive (smallest) match wins.
      '*.md': 2000

No ``.token-limits.yaml`` -> no-op (exit 0).
"""
from __future__ import annotations

import fnmatch
import os
import sys

CONFIG = ".token-limits.yaml"
SKIP_DIRS = {".git", "node_modules", "result", ".gh-shared", ".terraform", ".direnv"}


def _matches(path: str, name: str, pattern: str) -> bool:
    return fnmatch.fnmatch(path, pattern) or fnmatch.fnmatch(name, pattern)


def main() -> int:
    if not os.path.exists(CONFIG):
        print(f"No {CONFIG} — token check skipped.")
        return 0

    try:
        import yaml
    except ImportError:
        print("::error::pyyaml not installed")
        return 1

    with open(CONFIG, encoding="utf-8") as fh:
        cfg = yaml.safe_load(fh) or {}

    limits = cfg.get("limits") or {}
    exclude = cfg.get("exclude") or []
    default_limit = (cfg.get("defaults") or {}).get("max_tokens", 2000)
    if not limits:
        print(f"No `limits` patterns in {CONFIG} — nothing token-gated.")
        return 0

    try:
        import tiktoken

        enc = tiktoken.get_encoding("o200k_base")
    except Exception as exc:  # noqa: BLE001 — infra failure must not block merges
        print(f"::warning::tiktoken unavailable ({exc}); token check skipped")
        return 0

    def limit_for(path: str, name: str) -> int | None:
        hits = [
            (lim if lim is not None else default_limit)
            for pat, lim in limits.items()
            if _matches(path, name, pat)
        ]
        return min(hits) if hits else None

    errors = checked = 0
    for root, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            path = os.path.relpath(os.path.join(root, name), ".")
            if any(_matches(path, name, ex) for ex in exclude):
                continue
            limit = limit_for(path, name)
            if limit is None:
                continue  # not token-gated — the byte gate covers it
            try:
                with open(os.path.join(root, name), encoding="utf-8") as fh:
                    text = fh.read()
            except (UnicodeDecodeError, OSError):
                continue  # binary / unreadable
            tokens = len(enc.encode(text))
            checked += 1
            if tokens > limit:
                print(f"::error file={path}::{path} is {tokens} tokens (exceeds {limit} limit)")
                errors += 1
            else:
                print(f"OK {path}: {tokens}/{limit} tokens")

    print(f"Token limit check: {checked} file(s) checked, {errors} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
