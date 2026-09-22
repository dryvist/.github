#!/usr/bin/env python3
"""J1: deterministic AI-config budget gates (plan section J1). No model
call — every check here is a size, a regex, or a frontmatter key, so it
never needs one. Thresholds live in ai-config-budget.yaml (repo root),
never hardcoded here.

Checks, each FAIL or WARN as configured:
  - skill `description:` frontmatter length
  - SKILL.md body size (exempt with a references/ sibling)
  - always-on rule files' total size
  - hook-injected output size / dynamic (timestamp-like) content
  - `gh (pr|issue|run) (list|view)` missing --json or --limit
  - agent frontmatter missing model:/effort:
  - inline MCP server config outside the mcp-available/ pattern
"""
import fnmatch
import glob
import json
import os
import re
import subprocess
import sys

import yaml

CFG_PATH = "ai-config-budget.yaml"
cfg = yaml.safe_load(open(CFG_PATH)) if os.path.exists(CFG_PATH) else {}
cfg = cfg if isinstance(cfg, dict) else {}

failures = []
warnings = []


def fail(msg):
    failures.append(msg)


def warn(msg):
    warnings.append(msg)


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n?", text, re.DOTALL)
    if not m:
        return {}, text
    try:
        fm = yaml.safe_load(m.group(1))
    except yaml.YAMLError:
        return {}, text
    return (fm if isinstance(fm, dict) else {}), text[m.end():]


# --- skill description + SKILL.md body size -------------------------------
sk = cfg.get("skill_description", {})
sm = cfg.get("skill_md_body", {})
for path in glob.glob("**/SKILL.md", recursive=True):
    text = open(path, encoding="utf-8").read()
    fm, body = frontmatter(text)
    desc = fm.get("description", "")
    desc_bytes = len(desc.encode("utf-8"))
    if sk and desc_bytes > sk.get("fail_bytes", 1024):
        fail(f"{path}: description is {desc_bytes} bytes (limit {sk['fail_bytes']})")
    elif sk and len(desc) > sk.get("warn_chars", 250):
        warn(f"{path}: description is {len(desc)} chars (warn over {sk['warn_chars']})")

    body_bytes = len(body.encode("utf-8"))
    if sm:
        has_refs = os.path.isdir(os.path.join(os.path.dirname(path), sm.get("references_dir", "references")))
        if body_bytes > sm.get("fail_bytes", 6144) and not has_refs:
            fail(f"{path}: body is {body_bytes} bytes (limit {sm['fail_bytes']}) with no references/ split")

# --- always-on rules total size --------------------------------------------
ar = cfg.get("always_on_rules", {})
if ar:
    total = 0
    present = []
    for p in ar.get("paths", []):
        if os.path.isfile(p):
            total += os.path.getsize(p)
            present.append(p)
    if present and total > ar.get("fail_bytes", 12288):
        fail(f"always-on rules total {total} bytes across {present} (limit {ar['fail_bytes']})")

# --- hook-injected output ----------------------------------------------------
ho = cfg.get("hook_output", {})
if ho:
    patterns = [re.compile(p) for p in ho.get("dynamic_patterns", [])]
    for h in ho.get("hooks", []):
        cmd = h["cmd"]
        stdin = h.get("stdin", "{}")
        try:
            proc = subprocess.run(cmd, shell=True, input=stdin, capture_output=True, text=True, timeout=30)
        except subprocess.TimeoutExpired:
            fail(f"hook `{cmd}` timed out")
            continue
        out = proc.stdout
        out_bytes = len(out.encode("utf-8"))
        if out_bytes > ho.get("fail_bytes", 1024):
            fail(f"hook `{cmd}` emits {out_bytes} bytes (limit {ho['fail_bytes']})")
        for pat in patterns:
            if pat.search(out):
                fail(f"hook `{cmd}` output matches dynamic pattern {pat.pattern!r} (breaks cache reuse)")
                break

# --- gh CLI missing --json/--limit ------------------------------------------
gh = cfg.get("gh_cli", {})
if gh:
    required = gh.get("require_flags", ["--json", "--limit"])
    gh_re = re.compile(r"gh\s+(pr|issue|run)\s+(list|view)\b[^\n]*")
    for path in glob.glob("**/*.sh", recursive=True) + glob.glob("**/*.yml", recursive=True) + glob.glob("**/*.yaml", recursive=True):
        if any(seg in path for seg in (".git/", "node_modules/", ".worktrees/")):
            continue
        text = open(path, encoding="utf-8", errors="ignore").read()
        for m in gh_re.finditer(text):
            line = m.group(0)
            missing = [f for f in required if f not in line]
            if missing:
                lineno = text[: m.start()].count("\n") + 1
                fail(f"{path}:{lineno}: `{line.strip()}` missing {missing}")

# --- agent frontmatter missing model:/effort: -------------------------------
af = cfg.get("agent_frontmatter", {})
if af:
    required = af.get("require_keys", ["model", "effort"])
    for path in glob.glob("**/agents/*.md", recursive=True):
        fm, _ = frontmatter(open(path, encoding="utf-8").read())
        missing = [k for k in required if k not in fm]
        if missing:
            warn(f"{path}: agent definition missing {missing}")

# --- inline MCP servers outside the mcp-available/ pattern ------------------
mc = cfg.get("mcp_servers", {})
if mc:
    allowed_glob = mc.get("allowed_glob", "mcp-available/*.json")
    for path in glob.glob("**/*.json", recursive=True):
        if any(seg in path for seg in (".git/", "node_modules/", ".worktrees/")):
            continue
        if fnmatch.fnmatch(path, allowed_glob):
            continue
        try:
            data = json.load(open(path, encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        if isinstance(data, dict) and isinstance(data.get("mcpServers"), dict) and data["mcpServers"]:
            fail(f"{path}: inline mcpServers config outside {allowed_glob}")

# --- report -------------------------------------------------------------------
for w in warnings:
    print(f"::warning::{w}")
for f in failures:
    print(f"::error::{f}")

if failures:
    print(f"\n{len(failures)} failure(s), {len(warnings)} warning(s).")
    sys.exit(1)
print(f"OK — {len(warnings)} warning(s).")
