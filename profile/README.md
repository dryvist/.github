# dryvist

<p align="center">
  <a href="https://docs.jacobpevans.com" target="_blank" rel="noopener noreferrer" aria-label="docs.jacobpevans.com — full architecture documentation">
    <img src="https://img.shields.io/badge/DOCS.JACOBPEVANS.COM-4FB3A9?style=for-the-badge" alt="docs.jacobpevans.com" width="500" />
  </a>
</p>

<p align="center">
  <em>The implementation layer for a fully automated, AI-assisted infrastructure portfolio.</em>
</p>

---

## What this org is

`dryvist` is where the **infrastructure** lives. Humans set direction, AI
agents implement, automation runs the boring parts, and a human gives the
final sign-off. Every repo here is a piece of that pipeline — declared once,
reproduced everywhere, observable end-to-end.

The map for all of it lives at **[docs.jacobpevans.com](https://docs.jacobpevans.com)**.

---

## What lives here

<p align="center">
  <img src="https://skillicons.dev/icons?i=nix,terraform,ansible,docker,kubernetes,githubactions,git,github&perline=8" alt="Tech stacks hosted in dryvist: Nix, Terraform, Ansible, Docker, Kubernetes, GitHub Actions, Git, GitHub" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Claude-CC785C?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude" />
  <img src="https://img.shields.io/badge/Gemini-8E75B2?style=for-the-badge&logo=google&logoColor=white" alt="Gemini" />
  <img src="https://img.shields.io/badge/Copilot-000000?style=for-the-badge&logo=githubcopilot&logoColor=white" alt="GitHub Copilot" />
  <img src="https://img.shields.io/badge/MLX-000000?style=for-the-badge&logo=apple&logoColor=white" alt="MLX" />
  <img src="https://img.shields.io/badge/OpenTelemetry-4B5563?style=for-the-badge&logo=opentelemetry&logoColor=white" alt="OpenTelemetry" />
  <img src="https://img.shields.io/badge/Splunk-000000?style=for-the-badge&logo=splunk&logoColor=white" alt="Splunk" />
  <img src="https://img.shields.io/badge/Cribl-00B4E6?style=for-the-badge&logoColor=white" alt="Cribl" />
  <img src="https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white" alt="Proxmox" />
</p>

The work splits into six broad categories. Each one links to the section of
the docs site that explains how it fits together.

- **[Nix ecosystem](https://docs.jacobpevans.com/nix/overview)** —
  reproducible everything. Declarative dev environments, system configs for
  macOS and NixOS, AI tooling as composable home-manager modules, and netboot
  bootstrap for bare metal.

- **[Infrastructure as code](https://docs.jacobpevans.com/infrastructure/overview)** —
  Terraform / OpenTofu modules for Proxmox, AWS, and GitHub itself. State
  backends, self-hosted runners, and org-wide GitHub governance, all
  declarative.

- **[Configuration management](https://docs.jacobpevans.com/infrastructure/overview)** —
  Ansible roles for Proxmox hosts, application deployments, and observability
  stacks. Pairs with the IaC layer to turn provisioned hosts into running
  services.

- **[AI development tooling](https://docs.jacobpevans.com/ai-development/overview)** —
  vendor-agnostic AI assistant instructions, reusable agent workflows,
  Claude Code plugins, and scheduled routines that keep a portfolio running
  itself 24/7.

- **[Observability](https://docs.jacobpevans.com/observability/overview)** —
  Cribl Edge / Stream packs and supporting infrastructure for piping
  telemetry from AI coding tools, Kubernetes, and homelab workloads into
  Splunk and OpenTelemetry collectors.

- **[Templates &amp; dev tooling](https://docs.jacobpevans.com/ai-development/overview)** —
  starter scaffolds, benchmark harnesses, and small utilities that make
  spinning up the next thing fast.

---

## Read the docs first

<p align="center">
  <a href="https://docs.jacobpevans.com" target="_blank" rel="noopener noreferrer" aria-label="docs.jacobpevans.com">
    <img src="https://img.shields.io/badge/Start_Here-docs.jacobpevans.com-E06B4A?style=for-the-badge" alt="Start at docs.jacobpevans.com" width="500" />
  </a>
</p>

The repos here are the moving parts. **[docs.jacobpevans.com](https://docs.jacobpevans.com)**
is the assembly diagram — architecture, data flows, decisions, and how every
piece connects. Read it before you read code.

---

## Org-wide standards

- **License:** [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0) unless
  a repo states otherwise.
- **Commits:** Conventional Commits (`feat:`, `fix:`, `chore:`, …) — drives
  automated releases.
- **Reviews:** Every PR is reviewed by multiple AI models before a human
  signs off.

Canonical configs, AI assistant policy, and inheritance from
[`JacobPEvans/.github`](https://github.com/JacobPEvans/.github) live in
[`dryvist/.github`](https://github.com/dryvist/.github).
