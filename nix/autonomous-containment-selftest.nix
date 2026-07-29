# Selftest for the containment scanner.
#
# Exists because `nix flake check` does not evaluate `lib.` outputs — the
# exported check would otherwise ship with nothing exercising it. Runs the
# same containment-scan.sh the check runs, against three fixtures, and
# asserts the exit codes.
#
# The empty-tree case is the one that matters for longevity: a scan that
# passes on a tree it cannot see would let a repo silently stop being
# checked after a module reorganisation.
{ pkgs }:

pkgs.runCommand "autonomous-containment-selftest"
  {
    nativeBuildInputs = [ pkgs.bash ];
    forbidden = "bypassPermissions\nrenderAutonomous\nyolo";
    passAsFile = [ "forbidden" ];
  }
  ''
    set -euo pipefail
    scan=${./containment-scan.sh}

    mkdir -p clean dirty empty
    echo '{ ... }: { programs.claude.enable = true; }' > clean/home.nix
    echo '{ ... }: { text = "bypassPermissions"; }'    > dirty/home.nix
    touch empty/.keep

    # 1. clean tree passes
    if ! bash "$scan" "$PWD/clean" "$forbiddenPath" 2>err_clean; then
      echo "FAIL: clean tree should pass" >&2; cat err_clean >&2; exit 1
    fi

    # 2. a module carrying an autonomous posture fails, and says which
    if bash "$scan" "$PWD/dirty" "$forbiddenPath" 2>err_dirty; then
      echo "FAIL: dirty tree should fail" >&2; exit 1
    fi
    grep -q "VIOLATION" err_dirty
    grep -q "bypassPermissions" err_dirty

    # 3. a tree with no .nix files fails rather than passing vacuously
    if bash "$scan" "$PWD/empty" "$forbiddenPath" 2>err_empty; then
      echo "FAIL: empty tree should not pass vacuously" >&2; exit 1
    fi
    grep -q "vacuously" err_empty

    # 4. a flag-shaped posture is caught too, not just settings keys
    mkdir -p flagged
    echo '{ ... }: { shellAliases.c = "claude --yolo"; }' > flagged/home.nix
    if bash "$scan" "$PWD/flagged" "$forbiddenPath" 2>err_flag; then
      echo "FAIL: flag-shaped posture should fail" >&2; exit 1
    fi
    grep -q "yolo" err_flag

    # 5. allowlisted file is skipped
    printf 'home.nix\n' > allow
    if ! bash "$scan" "$PWD/dirty" "$forbiddenPath" "$PWD/allow" 2>err_allow; then
      echo "FAIL: allowlisted violation should be skipped" >&2
      cat err_allow >&2; exit 1
    fi

    echo "containment selftest: 5/5 cases OK"
    touch "$out"
  ''
