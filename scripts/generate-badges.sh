#!/usr/bin/env bash
# generate-badges.sh — D-R-Y badge generator and auditor for dryvist repositories.
#
# Inspects target repository workflows and files, derives the canonical set of badges
# scoped to the deployed branch (main), and formats them according to dryvist org standards.
# Uses reference-style markdown links for workflow badges to maintain strict MD013 line length.
#
# Usage:
#   ./scripts/generate-badges.sh [--repo <name>] [--path <path>] [--write] [--check]
#   ./scripts/generate-badges.sh --all [--write] [--check]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ORG="dryvist"
BRANCH="main"

TARGET_REPO=""
TARGET_PATH=""
DO_WRITE=false
DO_CHECK=false
DO_ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      TARGET_REPO="$2"
      shift 2
      ;;
    --path)
      TARGET_PATH="$2"
      shift 2
      ;;
    --write)
      DO_WRITE=true
      shift
      ;;
    --check)
      DO_CHECK=true
      shift
      ;;
    --all)
      DO_ALL=true
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]

Options:
  --repo <name>    Target repository name (e.g. tofu-proxmox, .github)
  --path <path>    Local path to repository (defaults to auto-discovery)
  --write          Update README.md in-place with generated badges
  --check          Check if README.md has expected badges (exit 1 if drifted)
  --all            Iterate through all repos in tofu-github inventory
  -h, --help       Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

find_repo_dir() {
  local repo="$1"
  if [[ -n "$TARGET_PATH" && -d "$TARGET_PATH" ]]; then
    echo "$TARGET_PATH"
    return 0
  fi
  # If currently inside the target repo
  if [[ "$repo" == ".github" && -f "${ROOT_DIR}/README.md" ]]; then
    echo "$ROOT_DIR"
    return 0
  fi
  # Search sibling paths under /Users/jevans/git/public or parent directories
  local search_roots=(
    "${ROOT_DIR}/../.."
    "${ROOT_DIR}/.."
    "/Users/jevans/git/public"
  )
  for sroot in "${search_roots[@]}"; do
    if [[ -d "$sroot" ]]; then
      local found
      found=$(find "$sroot" -maxdepth 3 -type d -name "$repo" 2>/dev/null | head -n 1 || true)
      if [[ -n "$found" && -d "$found" ]]; then
        echo "$found"
        return 0
      fi
    fi
  done
  echo ""
}

generate_badge_block() {
  local repo="$1"
  local repo_dir="$2"
  local badge_lines=()
  local ref_lines=()

  local has_ci=false
  local has_pm=false
  local has_rp=false
  local has_license=false
  local has_flake=false
  local has_renovate=false

  if [[ -n "$repo_dir" && -d "$repo_dir" ]]; then
    [[ -f "${repo_dir}/.github/workflows/ci-gate.yml" ]] && has_ci=true
    [[ -f "${repo_dir}/.github/workflows/post-merge-tests.yml" ]] && has_pm=true
    [[ -f "${repo_dir}/.github/workflows/release-please.yml" ]] && has_rp=true
    [[ -f "${repo_dir}/LICENSE" || -f "${repo_dir}/LICENSE.md" ]] && has_license=true
    [[ -f "${repo_dir}/flake.nix" ]] && has_flake=true
    [[ -f "${repo_dir}/renovate.json" || -f "${repo_dir}/default.json" ]] && has_renovate=true
  else
    # Query raw GitHub content
    local ci_code pm_code rp_code lic_code flk_code ren_code
    ci_code=$(curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/${ORG}/${repo}/HEAD/.github/workflows/ci-gate.yml")
    pm_code=$(curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/${ORG}/${repo}/HEAD/.github/workflows/post-merge-tests.yml")
    rp_code=$(curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/${ORG}/${repo}/HEAD/.github/workflows/release-please.yml")
    lic_code=$(curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/${ORG}/${repo}/HEAD/LICENSE")
    flk_code=$(curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/${ORG}/${repo}/HEAD/flake.nix")
    ren_code=$(curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/${ORG}/${repo}/HEAD/renovate.json")

    [[ "$ci_code" == "200" ]] && has_ci=true
    [[ "$pm_code" == "200" ]] && has_pm=true
    [[ "$rp_code" == "200" ]] && has_rp=true
    [[ "$lic_code" == "200" ]] && has_license=true
    [[ "$flk_code" == "200" ]] && has_flake=true
    [[ "$ren_code" == "200" ]] && has_renovate=true
  fi

  # Tier 1: Core CI & Workflow Status (Reference-style links for MD013 line length compliance)
  if [[ "$has_ci" == true ]]; then
    badge_lines+=("[![CI Gate][badge-ci]][workflow-ci]")
    ref_lines+=("[badge-ci]: https://github.com/${ORG}/${repo}/actions/workflows/ci-gate.yml/badge.svg?branch=${BRANCH}")
    ref_lines+=("[workflow-ci]: https://github.com/${ORG}/${repo}/actions/workflows/ci-gate.yml?query=branch%3A${BRANCH}")
  fi
  if [[ "$has_pm" == true ]]; then
    badge_lines+=("[![Post-Merge Tests][badge-pm]][workflow-pm]")
    ref_lines+=("[badge-pm]: https://github.com/${ORG}/${repo}/actions/workflows/post-merge-tests.yml/badge.svg?branch=${BRANCH}")
    ref_lines+=("[workflow-pm]: https://github.com/${ORG}/${repo}/actions/workflows/post-merge-tests.yml?query=branch%3A${BRANCH}")
  fi
  if [[ "$has_rp" == true ]]; then
    badge_lines+=("[![Release Please][badge-rp]][workflow-rp]")
    badge_lines+=("[![Release][badge-release]][release-url]")
    ref_lines+=("[badge-rp]: https://github.com/${ORG}/${repo}/actions/workflows/release-please.yml/badge.svg?branch=${BRANCH}")
    ref_lines+=("[workflow-rp]: https://github.com/${ORG}/${repo}/actions/workflows/release-please.yml?query=branch%3A${BRANCH}")
    ref_lines+=("[badge-release]: https://img.shields.io/github/v/release/${ORG}/${repo}?sort=semver&style=flat-square&color=2F7E78")
    ref_lines+=("[release-url]: https://github.com/${ORG}/${repo}/releases")
  fi

  # Tier 2: Governance & Ecosystem (Short URLs keep inline well under 160 characters)
  if [[ "$has_license" == true ]]; then
    badge_lines+=("[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-2F7E78?style=flat-square)](LICENSE)")
  fi
  if [[ "$has_flake" == true ]]; then
    badge_lines+=("[![Built with Nix](https://img.shields.io/badge/built%20with-Nix-5277C3?style=flat-square&logo=nixos&logoColor=white)](flake.nix)")
  fi
  if [[ "$has_renovate" == true ]]; then
    badge_lines+=("[![Renovate](https://img.shields.io/badge/renovate-enabled-2F7E78?style=flat-square&logo=renovatebot&logoColor=white)](https://github.com/${ORG}/.github)")
  fi

  # Central Docs link
  badge_lines+=("[![Docs](https://img.shields.io/badge/docs-jacobpevans.com-4FB3A9?style=flat-square)](https://docs.jacobpevans.com)")

  for badge in "${badge_lines[@]}"; do
    echo "$badge"
  done
  if [[ ${#ref_lines[@]} -gt 0 ]]; then
    echo ""
    for ref in "${ref_lines[@]}"; do
      echo "$ref"
    done
  fi
}

process_repo() {
  local repo="$1"
  local repo_dir
  repo_dir=$(find_repo_dir "$repo")
  local block
  block=$(generate_badge_block "$repo" "$repo_dir")

  if [[ "$DO_WRITE" == false && "$DO_CHECK" == false ]]; then
    echo "=== Badges for ${ORG}/${repo} ==="
    echo "$block"
    echo ""
    return 0
  fi

  if [[ -z "$repo_dir" || ! -f "${repo_dir}/README.md" ]]; then
    echo "Skipping ${repo}: local README.md not found" >&2
    return 0
  fi

  local readme="${repo_dir}/README.md"

  python3 - <<PY
import re
import sys

readme_path = "$readme"
repo = "$repo"
new_badge_block = """$block""".strip()

with open(readme_path, "r", encoding="utf-8") as f:
    content = f.read()

lines = content.splitlines()

# Locate top # Heading
title_idx = -1
for i, line in enumerate(lines):
    if line.startswith("# "):
        title_idx = i
        break

if title_idx == -1:
    print(f"Error: No H1 title found in {readme_path}", file=sys.stderr)
    sys.exit(1)

# Find where existing badge block or prose begins
badge_start = title_idx + 1
while badge_start < len(lines) and lines[badge_start].strip() == "":
    badge_start += 1

# If there are existing badges or reference definitions, find their end
badge_end = badge_start
while badge_end < len(lines):
    line = lines[badge_end].strip()
    if line.startswith("[![") or line.startswith("![") or line.startswith("<a href=") or line.startswith("<img") or line.startswith("[badge-") or line.startswith("[workflow-") or line.startswith("[release-url]"):
        badge_end += 1
    elif line == "":
        # Check if next line is another badge, reference definition, or the tofu-proxmox blockquote
        if badge_end + 1 < len(lines):
            nxt = lines[badge_end + 1].strip()
            if nxt.startswith("[![") or nxt.startswith("![") or nxt.startswith("[badge-") or nxt.startswith("[workflow-") or nxt.startswith("[release-url]"):
                badge_end += 1
                continue
            if nxt.startswith("> **Read the first two badges"):
                badge_end += 1
                while badge_end < len(lines) and (lines[badge_end].startswith(">") or lines[badge_end].strip() == ""):
                    # check if still blockquote
                    if lines[badge_end].startswith(">"):
                        badge_end += 1
                    else:
                        break
                break
        break
    elif line.startswith("> **Read the first two badges") or line.startswith(">"):
        while badge_end < len(lines) and lines[badge_end].startswith(">"):
            badge_end += 1
        break
    else:
        break

before = lines[:title_idx + 1]
after = lines[badge_end:]
while after and after[0].strip() == "":
    after.pop(0)

rebuilt = before + ["", new_badge_block, ""] + after
rebuilt_text = "\n".join(rebuilt).rstrip() + "\n"

if "$DO_CHECK" == "true":
    if rebuilt_text != content:
        print(f"DRIFT DETECTED: {repo} README.md does not match canonical badges.")
        sys.exit(2)
    else:
        print(f"OK: {repo} badges are canonical.")
        sys.exit(0)

if "$DO_WRITE" == "true":
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(rebuilt_text)
    print(f"UPDATED: {repo} README.md with canonical badges.")
PY
}

if [[ "$DO_ALL" == true ]]; then
  inventory="${ROOT_DIR}/../tofu-github/config/repos.yml"
  if [[ -f "$inventory" ]]; then
    repos=$(yq -r '.repos | keys | .[]' "$inventory")
  else
    repos=$(curl -s "https://api.github.com/orgs/${ORG}/repos?per_page=100" | jq -r '.[] | select(.archived | not) | .name')
  fi
  for r in $repos; do
    process_repo "$r"
  done
elif [[ -n "$TARGET_REPO" ]]; then
  process_repo "$TARGET_REPO"
else
  process_repo ".github"
fi
