const assert = require('node:assert/strict');
const { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const script = path.join(__dirname, '../scripts/ci-gate-watchdog.sh');

test('a queued sibling times out by cancelling the workflow run', (t) => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'ci-gate-watchdog-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const calls = path.join(dir, 'calls');
  const gh = path.join(dir, 'gh');

  writeFileSync(
    gh,
    `#!/bin/sh
case "$*" in
  *"repos/example/repo/actions/runs/123/jobs?per_page=100"*)
    printf '456\\tshared-gate / Nix Validate / Validate\\n'
    ;;
  *"repos/example/repo/actions/runs/123/cancel"*)
    printf '%s\\n' "$*" >> "$CALLS"
    ;;
  *)
    exit 1
    ;;
esac
`,
  );
  chmodSync(gh, 0o755);

  const run = spawnSync('bash', [script], {
    encoding: 'utf8',
    env: {
      ...process.env,
      CALLS: calls,
      GH_TOKEN: 'test',
      PATH: `${dir}:${process.env.PATH}`,
      QUEUE_TIMEOUT_MINUTES: '0',
      REPO: 'example/repo',
      RUN_ID: '123',
    },
  });

  assert.equal(run.status, 0, run.stderr);
  assert.match(run.stdout, /Timeout \(0m\) reached/);
  assert.match(run.stdout, /Stuck queued job: shared-gate \/ Nix Validate \/ Validate/);
  assert.match(run.stdout, /Cancelling workflow run 123/);
  assert.equal(readFileSync(calls, 'utf8'), 'api -X POST repos/example/repo/actions/runs/123/cancel\n');
});
