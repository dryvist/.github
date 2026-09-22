#!/usr/bin/env python3
"""J3: scheduled prompt audit (plan section J3). Same stale-pattern
checklist as /claude-api prompt-audit (plan section F2), run over every
skill/rule file by the router's cheapest capable role. Files one Vikunja
task per finding into project 48 — never a GitHub issue.
"""
import glob
import json
import os
import urllib.request

CHECKLIST = """\
Audit this AI agent skill/rule file for stale patterns: outdated model
names or ids, dead tool/command references, contradicted-by-newer-file
guidance, mandatory-procedure anti-patterns, or claims no longer true of
the current harness. List each finding as:
FILE:LINE | ISSUE (<20 words)
If there are no findings, output exactly: No findings.
"""


def call_router(base_url, api_key, model, content):
    body = {
        "model": model,
        "messages": [{"role": "system", "content": CHECKLIST}, {"role": "user", "content": content[:40000]}],
        "max_tokens": 500,
        "temperature": 0,
    }
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.load(resp)["choices"][0]["message"]["content"].strip()


def file_vikunja_task(vikunja_url, token, title, description):
    req = urllib.request.Request(
        f"{vikunja_url.rstrip('/')}/projects/48/tasks",
        data=json.dumps({"title": title, "description": description}).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="PUT",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def main():
    base_url = os.environ["ROUTER_BASE_URL"]
    api_key = os.environ["ROUTER_API_KEY"]
    model = os.environ["ROUTER_MODEL"]
    vikunja_url = os.environ["VIKUNJA_URL"]
    vikunja_token = os.environ["VIKUNJA_API_TOKEN"]
    repo = os.environ["REPO_NAME"]

    paths = sorted(set(glob.glob("**/SKILL.md", recursive=True)) | set(glob.glob("agentsmd/rules/**/*.md", recursive=True)))
    for path in paths:
        text = open(path, encoding="utf-8", errors="ignore").read()
        findings = call_router(base_url, api_key, model, f"# {path}\n\n{text}")
        if findings and findings != "No findings.":
            file_vikunja_task(
                vikunja_url, vikunja_token,
                title=f"prompt-audit: {repo}/{path}",
                description=f"Scheduled monthly prompt audit (plan J3).\n\n```\n{findings}\n```",
            )
            print(f"Filed: {path}")
        else:
            print(f"Clean: {path}")


if __name__ == "__main__":
    main()
