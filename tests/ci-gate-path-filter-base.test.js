import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const workflow = readFileSync(
  new URL('../.github/workflows/_ci-gate.yml', import.meta.url),
  'utf8',
);

test('both shared path filters compare pushes against the pushed branch', () => {
  const filters = workflow
    .split('\n      - uses: dorny/paths-filter@')
    .slice(1)
    .map((step) => step.split('\n      - uses:')[0]);
  assert.equal(filters.length, 2);
  for (const filter of filters) {
    assert.match(filter, /^\s+base: \$\{\{ github\.ref \}\}$/m);
  }
});
