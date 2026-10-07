import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const workflow = readFileSync(
  new URL('../.github/workflows/_ci-gate.yml', import.meta.url),
  'utf8',
);

test('both shared path filters compare pushes against the pushed branch', () => {
  const filters = workflow.split('uses: dorny/paths-filter@');
  assert.equal(filters.length - 1, 2);
  for (const filter of filters.slice(1)) {
    assert.match(filter, /with:\n(?:[^\n]*\n)*?\s+base: \$\{\{ github\.ref \}\}/);
  }
});
