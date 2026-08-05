#!/usr/bin/env bash
# Checks for scripts/scorecard-enforce.sh. No framework: fixtures are inline
# JSON matching real Scorecard output, and each case asserts an exit code.
#
#   bash tests/scorecard-enforce/test-scorecard-enforce.sh
#
# The cases that matter are the asymmetry the gate is built on: a regressed
# BLOCKING check must fail the run, while a low aggregate must not.
set -uo pipefail

SCRIPT="${1:-$(dirname "$0")/../../scripts/scorecard-enforce.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

run() {
  name="$1"
  exp="$2"
  shift 2
  out=$(env "$@" bash "$SCRIPT" 2>&1)
  rc=$?
  if [ "$rc" -eq "$exp" ]; then
    echo "PASS  $name"
    pass=$((pass + 1))
  else
    echo "FAIL  $name (rc=$rc, want $exp)"
    printf '      %s\n' "${out//$'\n'/$'\n'      }"
    fail=$((fail + 1))
  fi
}

# Mirrors dryvist/.github's own measured run: aggregate 7.9, blocking checks
# clean, several non-blocking checks well below 10.
cat > "$TMP/good.json" <<'EOF'
{"score":7.9,"checks":[
 {"name":"Dangerous-Workflow","score":10},{"name":"Binary-Artifacts","score":10},
 {"name":"Pinned-Dependencies","score":7},{"name":"Token-Permissions","score":8},
 {"name":"SAST","score":0},{"name":"Packaging","score":-1}]}
EOF
cat > "$TMP/dw.json" <<'EOF'
{"score":7.0,"checks":[
 {"name":"Dangerous-Workflow","score":0},{"name":"Binary-Artifacts","score":10}]}
EOF
cat > "$TMP/na.json" <<'EOF'
{"score":6.0,"checks":[
 {"name":"Dangerous-Workflow","score":-1},{"name":"Binary-Artifacts","score":10}]}
EOF
cat > "$TMP/absent.json" <<'EOF'
{"score":6.0,"checks":[{"name":"Binary-Artifacts","score":10}]}
EOF
echo '{"checks":[{"name":"Dangerous-Workflow","score":10}]}' > "$TMP/noscore.json"

B="Dangerous-Workflow,Binary-Artifacts"

run "healthy repo passes" 0 \
  RESULTS="$TMP/good.json" BLOCKING_CHECKS="$B" MIN_SCORE=0
run "low aggregate does NOT block at floor 0" 0 \
  RESULTS="$TMP/good.json" BLOCKING_CHECKS="$B" MIN_SCORE=0
run "Dangerous-Workflow regression blocks" 1 \
  RESULTS="$TMP/dw.json" BLOCKING_CHECKS="$B" MIN_SCORE=0
run "N/A blocking check is skipped" 0 \
  RESULTS="$TMP/na.json" BLOCKING_CHECKS="$B" MIN_SCORE=0
run "absent blocking check is skipped" 0 \
  RESULTS="$TMP/absent.json" BLOCKING_CHECKS="$B" MIN_SCORE=0
run "missing aggregate score fails" 1 \
  RESULTS="$TMP/noscore.json" BLOCKING_CHECKS="$B" MIN_SCORE=0
run "opted-in floor blocks below it" 1 \
  RESULTS="$TMP/good.json" BLOCKING_CHECKS="$B" MIN_SCORE=8
run "opted-in floor passes at the boundary" 0 \
  RESULTS="$TMP/good.json" BLOCKING_CHECKS="$B" MIN_SCORE=7.9
run "empty blocking list tolerated" 0 \
  RESULTS="$TMP/good.json" BLOCKING_CHECKS="" MIN_SCORE=0
run "whitespace in blocking list tolerated" 0 \
  RESULTS="$TMP/good.json" BLOCKING_CHECKS="Dangerous-Workflow, Binary-Artifacts" MIN_SCORE=0
run "missing results file fails" 1 \
  RESULTS="$TMP/nope.json" BLOCKING_CHECKS="$B" MIN_SCORE=0

echo "== ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
