# J4 (weekly cost report) — blocked on a secret

Plan section J4 wants a scheduled reusable workflow that queries the
observability stack (Grafana/VictoriaMetrics) for cache-read share,
5m/1h write mix, context_peak, top tool_result_tokens, subagents per
session, and cost per session, then posts to the status channel only on
a threshold breach (else log only, per `agent-notifications.md`).

No repo in `~/git/public` has an existing CI secret or URL contract for
reaching VictoriaMetrics/Grafana from a GitHub Actions job — every other
reusable workflow here reaches a service through an org secret
(`LLM_ROUTER_BASE_URL`, `VIKUNJA_URL`, etc.). Building this blind would
mean inventing that contract rather than reusing one.

**What's needed before J4 can be built:** an org secret (e.g.
`VICTORIAMETRICS_URL` / `VICTORIAMETRICS_API_TOKEN`, or a Grafana API key)
that a self-hosted-pool job can use to query the metrics backend, plus
confirmation the self-hosted pool's network path reaches it (same
same-VLAN reachability question as any other internal target).

File a Vikunja task under project 45 (`observability`) to define that
secret/URL, then this workflow is a straightforward addition alongside
`_prompt-audit.yml`.
