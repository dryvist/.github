#!/usr/bin/env python3
"""J2: cost-review judge (plan section J2). Sends the PR diff to the org
model router's cheapest capable role (never a hardcoded vendor model id —
MODEL is a router role alias resolved by the router itself) and posts one
line per finding as a PR comment. Advisory only: this script never exits
non-zero for a finding, only for a router/API failure.
"""
import json
import os
import subprocess
import sys
import urllib.request

CHECKLIST = """\
Review this diff to an AI agent's config (skills, rules, hooks, agent
definitions, or harness settings). Report only real findings, one per line,
exactly in this format and nothing else:
SEVERITY | FILE:LINE | ISSUE (<15 words)
SEVERITY is one of: high, medium, low. Check for:
- changes that break prompt-cache reuse (dynamic/timestamped injected text)
- always-on context growth (new always-loaded rule, skill, or MCP server)
- mandatory-procedure or "verify twice" anti-patterns
- contradictions with soul.md or operating-core.md
- uncapped agent/subagent fan-out
- prose worker output where one line would do
- unfiltered tool output reaching the model
- harness-only changes with no parity update for the other harnesses
If there are no findings, output exactly: No findings.
"""


def main():
    base = os.environ["BASE_SHA"]
    head = os.environ["HEAD_SHA"]
    diff = subprocess.run(
        ["git", "diff", f"{base}...{head}", "--", ".", ":(exclude).worktrees"],
        capture_output=True, text=True, check=True,
    ).stdout
    if not diff.strip():
        print("Empty diff, nothing to review.")
        return

    base_url = os.environ["ROUTER_BASE_URL"].rstrip("/")
    api_key = os.environ["ROUTER_API_KEY"]
    model = os.environ["ROUTER_MODEL"]  # a router role alias, e.g. "cost-judge"

    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": CHECKLIST},
            {"role": "user", "content": diff[:60000]},
        ],
        "max_tokens": 1000,
        "temperature": 0,
    }
    req = urllib.request.Request(
        f"{base_url}/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.load(resp)
    findings = result["choices"][0]["message"]["content"].strip()

    comment = f"### Cost-review judge (advisory)\n\n{findings}\n\n_Not a merge gate — plan section J2._"
    pr_url = os.environ["PR_URL"]
    with open("comment-body.md", "w") as fh:
        fh.write(comment)
    subprocess.run(["gh", "pr", "comment", pr_url, "--body-file", "comment-body.md"], check=True)
    print(findings)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001 — advisory job, report and exit clean
        print(f"::warning::cost-review judge failed: {exc}", file=sys.stderr)
