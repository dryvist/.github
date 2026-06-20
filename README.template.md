<!--
  README template for every repo in the ecosystem.
  Standard: https://docs.jacobpevans.com/conventions/readme-conventions

  Rules this template encodes:
  - Standalone: describe ONLY this repo. No "Related Repos" table, no
    sibling descriptions, no repo-relationship diagrams — that map lives
    on the docs site.
  - Dependencies are contracts, not names: say "consumes an inventory
    matching <schema>", not "run <other-repo> first".
  - Exactly one cross-repo link: the footer, routed by visibility
    (public -> docs.jacobpevans.com, private -> docs.dryvist.com).
  Keep, rename, or drop the repo-specific sections as the repo needs.
  Delete these comments when you copy the file.
-->

# repo-name

One sentence: what this repo is and who it's for.

[![CI](https://github.com/dryvist/repo-name/actions/workflows/ci.yml/badge.svg)](https://github.com/dryvist/repo-name/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

## Requirements

### Prerequisites & OS Requirements

- **Tool / Dependency**: Describe any prerequisite tool, OS, or dependent repository needed for this project.
- **OS Support**: Describe OS compatibility.

### Optional Enhancements

- **Tool / Feature**: Describe any optional enhancements or setup.

## Installation

Prerequisites, then the shortest path to running it.

```bash
# the minimum commands to get it working
```

## Usage

The common operations, with copy-pasteable examples.

## Configuration

<!-- Repo-specific. Add Layout / Testing / Roles / etc. as needed; drop what doesn't apply. -->

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Workspace conventions (commits, branches, PRs)
live at [docs.jacobpevans.com/conventions](https://docs.jacobpevans.com/conventions/overview).

## License

[Apache-2.0](LICENSE).

---

> Part of a [larger ecosystem of ~40 repos](https://docs.jacobpevans.com) — see how it all fits together.
<!-- PRIVATE repos use instead:
> Part of the [dryvist homelab](https://docs.dryvist.com) — how the private repos and infrastructure connect (gated).
-->
