#!/usr/bin/env bash
# Selftest for containment-scan.sh.
#
# Usage: containment-selftest.sh <scan-script> <forbidden-file>
#
# Exists because `nix flake check` does not evaluate `lib.` outputs, so the
# exported check would otherwise ship with nothing exercising it. Runs the
# real scanner against fixtures rather than re-implementing the scan, so
# the test cannot drift from the logic it covers.
set -euo pipefail

scan=${1:?scan script required}
forbidden=${2:?forbidden-patterns file required}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

mkdir -p clean dirty empty flagged declaring
echo '{ ... }: { programs.claude.enable = true; }' >clean/home.nix
echo '{ ... }: { text = "bypassPermissions"; }' >dirty/home.nix
echo '{ ... }: { defaultApprovalMode = "yolo"; }' >flagged/home.nix
touch empty/.keep

# An options module that names the value in a types.enum and explains it in
# prose. Legitimate — this is how the option gets typed at all.
cat >declaring/options.nix <<'FIXTURE'
{ lib, ... }: {
  defaultMode = lib.mkOption {
    type = lib.types.enum [ "default" "auto" "bypassPermissions" ];
    default = "auto";
    description = "bypassPermissions skips all deny/ask checks.";
  };
}
FIXTURE

# 1. clean tree passes
if ! bash "$scan" "$work/clean" "$forbidden" 2>err_clean; then
  echo "FAIL: clean tree should pass" >&2
  cat err_clean >&2
  exit 1
fi

# 2. an assigned posture fails, and the message names the pattern
if bash "$scan" "$work/dirty" "$forbidden" 2>err_dirty; then
  echo "FAIL: assigned posture should fail" >&2
  exit 1
fi
grep -q "VIOLATION" err_dirty
grep -q "bypassPermissions" err_dirty

# 3. a tree with no .nix files fails rather than passing vacuously
if bash "$scan" "$work/empty" "$forbidden" 2>err_empty; then
  echo "FAIL: empty tree should not pass vacuously" >&2
  exit 1
fi
grep -q "vacuously" err_empty

# 4. the non-Claude CLIs' posture values are covered too. This is also the
# last line of the forbidden file, which passAsFile writes without a
# trailing newline — a bare `while read` would silently skip it.
if bash "$scan" "$work/flagged" "$forbidden" 2>err_flag; then
  echo "FAIL: assigned yolo should fail" >&2
  exit 1
fi
grep -q "yolo" err_flag

# 5. REGRESSION: enum + prose declaration must NOT be flagged. The first
# real consumer (nix-claude-code modules/core.nix) looks exactly like this,
# and matching bare value names failed it.
if ! bash "$scan" "$work/declaring" "$forbidden" 2>err_decl; then
  echo "FAIL: enum/prose declaration must not be flagged" >&2
  cat err_decl >&2
  exit 1
fi

# 6. allowlisted file is skipped
printf 'home.nix\n' >allow
if ! bash "$scan" "$work/dirty" "$forbidden" allow 2>err_allow; then
  echo "FAIL: allowlisted violation should be skipped" >&2
  cat err_allow >&2
  exit 1
fi

echo "containment selftest: 6/6 cases OK"
