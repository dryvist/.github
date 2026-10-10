import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const script = fileURLToPath(new URL('../scripts/ci-gate-unmapped.sh', import.meta.url));

function run(env) {
  const dir = mkdtempSync(join(tmpdir(), 'ci-gate-unmapped-'));
  const output = join(dir, 'github-output');
  try {
    const result = spawnSync('bash', [script], {
      encoding: 'utf8',
      env: { PATH: process.env.PATH, GITHUB_OUTPUT: output, ...env },
    });
    const written = (() => {
      try {
        return readFileSync(output, 'utf8');
      } catch {
        return '';
      }
    })();
    return { ...result, written };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('a path no filter covers warns and sets full=true without failing', () => {
  const run1 = run({
    ALL: '["flake.lock","svc/app.yml","README.md"]',
    NIX: '["flake.lock"]',
    MARKDOWN: '["README.md"]',
  });

  assert.equal(run1.status, 0);
  assert.match(run1.stdout, /^::warning::unmapped path svc\/app\.yml, running full profile$/m);
  assert.equal(run1.written.trim(), 'full=true');
});

test('docs and mapped paths produce no warning and full=false', () => {
  const run1 = run({
    ALL: '["nix/a.nix","NOTES.md"]',
    NIX: '["nix/a.nix"]',
    MARKDOWN: '[]',
  });

  assert.equal(run1.status, 0);
  assert.doesNotMatch(run1.stdout, /::warning::/);
  assert.equal(run1.written.trim(), 'full=false');
});

test('no changed files at all is not an error', () => {
  const run1 = run({});

  assert.equal(run1.status, 0);
  assert.equal(run1.written.trim(), 'full=false');
});
