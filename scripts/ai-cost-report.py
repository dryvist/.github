#!/usr/bin/env python3
"""J4: weekly cost report (plan section J4). Queries the observability
stack's Prometheus-compatible API (VictoriaMetrics) for the metrics in
ai-cost-report.yaml. Fails loudly if AI_METRICS_URL is unset — no silent
skip. Files a Vikunja task (project 45) only when a threshold breaks; a
clean run logs to the job summary only, per agent-notifications.md.
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

import yaml


def query(base_url, promql):
    url = f"{base_url.rstrip('/')}/api/v1/query?{urllib.parse.urlencode({'query': promql})}"
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def scalar(result):
    data = result.get("data", {}).get("result", [])
    if not data:
        return None
    # instant vector: take the first series' value; topk/multi-series callers
    # read the full `data` list themselves via breach() below.
    return float(data[0]["value"][1])


def breach(name, value, threshold):
    if value is None or not threshold:
        return None
    if "min" in threshold and value < threshold["min"]:
        return f"{name}={value:.3g} below min {threshold['min']}"
    if "max" in threshold and value > threshold["max"]:
        return f"{name}={value:.3g} above max {threshold['max']}"
    return None


def file_vikunja_task(vikunja_url, token, title, description):
    req = urllib.request.Request(
        f"{vikunja_url.rstrip('/')}/projects/45/tasks",
        data=json.dumps({"title": title, "description": description}).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="PUT",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def main():
    base_url = os.environ.get("AI_METRICS_URL")
    if not base_url:
        print("::error::AI_METRICS_URL is unset — no observability endpoint to query. "
              "See the Vikunja project-45 task filed alongside this workflow.", file=sys.stderr)
        sys.exit(1)

    cfg = yaml.safe_load(open("ai-cost-report.yaml"))["queries"]

    lines = []
    breaches = []
    for name, spec in cfg.items():
        try:
            result = query(base_url, spec["promql"])
        except (urllib.error.URLError, urllib.error.HTTPError) as exc:
            lines.append(f"{name}: query failed — {exc}")
            continue
        value = scalar(result)
        if value is None:
            lines.append(f"{name}: no data")
            continue
        lines.append(f"{name}: {value:.3g} {spec.get('unit', '')}")
        b = breach(name, value, spec.get("threshold"))
        if b:
            breaches.append(b)

    summary = "## Weekly AI cost report\n\n" + "\n".join(f"- {line}" for line in lines)
    with open(os.environ.get("GITHUB_STEP_SUMMARY", "/dev/stdout"), "a") as fh:
        fh.write(summary + "\n")
    print(summary)

    if breaches:
        vikunja_url = os.environ["VIKUNJA_URL"]
        vikunja_token = os.environ["VIKUNJA_API_TOKEN"]
        file_vikunja_task(
            vikunja_url, vikunja_token,
            title=f"AI cost report: {len(breaches)} threshold breach(es)",
            description="Weekly cost report (plan J4) crossed a threshold:\n\n"
                         + "\n".join(f"- {b}" for b in breaches)
                         + "\n\nFull report:\n\n" + summary,
        )
        print(f"Filed Vikunja task for {len(breaches)} breach(es).")
    else:
        print("No threshold breach — log only.")


if __name__ == "__main__":
    main()
