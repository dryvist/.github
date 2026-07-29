#!/usr/bin/env bash
# Scan a home-manager module tree for autonomous-config references.
#
# Usage: containment-scan.sh <module-dir> <forbidden-file> [allowlist-file]
#
# Exits 0 if clean, 1 on any violation or on a tree with no .nix files.
# Kept as a standalone script so both the exported check and its selftest
# run the identical logic — `nix flake check` does not evaluate `lib.`
# outputs, so a test that re-implemented the scan would prove nothing.
set -euo pipefail

src=${1:?module directory required}
forbidden_file=${2:?forbidden-patterns file required}
allowlist_file=${3:-/dev/null}

if [ ! -d "$src" ]; then
  echo "containment: not a directory: $src" >&2
  exit 1
fi

# Guard against a vacuous pass: with no .nix files every grep below
# trivially matches nothing, so the scan would look green while enforcing
# nothing. A repo that reorganises its modules out from under the
# configured path must fail loudly, not silently stop being checked.
count=$(find "$src" -type f -name '*.nix' | wc -l)
if [ "$count" -eq 0 ]; then
  echo "containment: no .nix files under $src — refusing to pass vacuously" >&2
  exit 1
fi

status=0
while IFS= read -r f; do
  rel=${f#"$src"/}

  if [ -s "$allowlist_file" ] && grep -Fxq -- "$rel" "$allowlist_file"; then
    continue
  fi

  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    if grep -Fq -- "$pat" "$f"; then
      echo "containment VIOLATION: $rel references '$pat'" >&2
      status=1
    fi
  done <"$forbidden_file"
done < <(find "$src" -type f -name '*.nix' | sort)

if [ "$status" -ne 0 ]; then
  {
    echo ""
    echo "Autonomous config must never render onto a host filesystem."
    echo "Keep it behind the image-build lib, or add the file to the"
    echo "allowlist with a comment saying why it is not a host-render path."
  } >&2
  exit 1
fi

echo "containment OK: $count home-manager .nix file(s) clean"
