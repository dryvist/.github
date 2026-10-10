import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const script = fileURLToPath(new URL('../scripts/ci-gate-uses-resolve.sh', import.meta.url));

// Builds a throwaway caller repo, runs the checker inside it, and removes it.
function runInCaller(callerYaml, extraFiles = {}) {
  const root = mkdtempSync(join(tmpdir(), 'ci-gate-uses-'));
  try {
    mkdirSync(join(root, '.github', 'workflows'), { recursive: true });
    writeFileSync(join(root, '.github', 'workflows', 'caller.yml'), callerYaml);
    for (const [path, body] of Object.entries(extraFiles)) {
      writeFileSync(join(root, path), body);
    }
    return spawnSync('bash', [script], {
      cwd: root,
      encoding: 'utf8',
      env: { PATH: process.env.PATH },
    });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test('a local reusable reference that exists passes', () => {
  const run = runInCaller(
    'jobs:\n  gate:\n    uses: ./.github/workflows/real.yml\n',
    { '.github/workflows/real.yml': 'on: workflow_call\n' },
  );

  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stdout, /all reusable workflow references resolve/);
});

test('a missing local reusable reference fails with the caller and target named', () => {
  const run = runInCaller('jobs:\n  gate:\n    uses: ./.github/workflows/missing.yml\n');

  assert.equal(run.status, 1);
  assert.match(
    run.stdout,
    /^::error file=\.github\/workflows\/caller\.yml::\.github\/workflows\/caller\.yml calls \.\/\.github\/workflows\/missing\.yml, which does not resolve/m,
  );
});

test('third-party action references are ignored', () => {
  const run = runInCaller(
    'jobs:\n  a:\n    steps:\n      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7\n',
  );

  assert.equal(run.status, 0, run.stdout + run.stderr);
});

test('a dryvist ref outside the public shared repos is not checked, only noticed', () => {
  // No GH_TOKEN is set, so reaching `gh api` would fail the run. A zero exit
  // with the notice proves the reference was skipped, not looked up.
  const ref = 'dryvist/private-thing/.github/workflows/x.yml@main';
  const run = runInCaller(`jobs:\n  a:\n    uses: ${ref}\n`);

  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stdout, new RegExp(`::notice::not checked \\(${ref.replace(/[./]/g, '\\$&')}\\)`));
  assert.doesNotMatch(run.stdout, /::error/);
});
