const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const test = require('node:test');

const SCRIPT_PATH = path.resolve(__dirname, '../scripts/generate-badges.sh');

test('generate-badges.sh produces canonical badges for dryvist/.github', () => {
  const output = execFileSync(SCRIPT_PATH, ['--repo', '.github'], { encoding: 'utf-8' });
  assert.match(output, /actions\/workflows\/ci-gate\.yml\/badge\.svg\?branch=main/);
  assert.match(output, /License-Apache_2\.0/);
  assert.match(output, /built%20with-Nix/);
  assert.match(output, /renovate-enabled/);
  assert.match(output, /docs-jacobpevans\.com/);
});

test('generate-badges.sh produces reference-style links for tofu-proxmox', () => {
  const output = execFileSync(SCRIPT_PATH, ['--repo', 'tofu-proxmox'], { encoding: 'utf-8' });
  assert.match(output, /\[!\[CI Gate\]\[badge-ci\]\]\[workflow-ci\]/);
  assert.match(output, /\[!\[Post-Merge Tests\]\[badge-pm\]\]\[workflow-pm\]/);
  assert.match(output, /\[!\[Release Please\]\[badge-rp\]\]\[workflow-rp\]/);
  assert.match(output, /\[badge-ci\]: https:\/\/github\.com\/dryvist\/tofu-proxmox\/actions\/workflows\/ci-gate\.yml/);
});

test('generate-badges.sh --check succeeds on current canonical README', () => {
  const output = execFileSync(SCRIPT_PATH, ['--repo', '.github', '--check'], { encoding: 'utf-8' });
  assert.match(output, /OK: \.github badges are canonical\./);
});
