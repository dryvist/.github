import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const script = fileURLToPath(new URL('../scripts/check-file-sizes.sh', import.meta.url));

// Limits mirror configs/file-size-defaults.yml: warn 6144, error 12288 bytes.
const CONFIG = 'defaults:\n  warn: 6144\n  error: 12288\nscan:\n  - .md\nexempt:\n  - CHANGELOG\n';

// Writes each file as N bytes into a throwaway repo root, runs the checker there, removes it.
function runWithFiles(sizes) {
  const root = mkdtempSync(join(tmpdir(), 'file-size-'));
  try {
    const config = join(root, 'config.yml');
    writeFileSync(config, CONFIG);
    for (const [name, bytes] of Object.entries(sizes)) {
      writeFileSync(join(root, name), Buffer.alloc(bytes, 'x'));
    }
    return spawnSync('bash', [script], {
      cwd: root,
      encoding: 'utf8',
      env: { PATH: process.env.PATH, FILE_SIZE_DEFAULTS_CONFIG: config },
    });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test('a file at 90% or more of the limit warns with size and limit, and does not fail', () => {
  // 11674 / 12288 is 95%; 11060 is the first byte count at 90% (11060 * 100 >= 12288 * 90).
  const run = runWithFiles({ 'near.md': 11674, 'edge.md': 11060 });

  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stdout, /^::warning::\.\/near\.md is 11674\/12288 \(90%\+\)$/m);
  assert.match(run.stdout, /^::warning::\.\/edge\.md is 11060\/12288 \(90%\+\)$/m);
});

test('a file just under 90% of the limit gets only the recommended warning', () => {
  // 11059 * 100 = 1105900 is below 12288 * 90 = 1105920.
  const run = runWithFiles({ 'below.md': 11059 });

  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.doesNotMatch(run.stdout, /\(90%\+\)/);
  assert.match(run.stdout, /^::warning file=\.\/below\.md::/m);
});

test('a file over the limit still fails and gets no 90% band line', () => {
  const run = runWithFiles({ 'over.md': 13000 });

  assert.equal(run.status, 1, run.stdout + run.stderr);
  assert.match(run.stdout, /^::error file=\.\/over\.md::/m);
  assert.doesNotMatch(run.stdout, /\(90%\+\)/);
});
