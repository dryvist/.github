import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const workflowsDir = fileURLToPath(new URL('../.github/workflows/', import.meta.url));

// A reusable workflow declares `workflow_call:` under `on:` (two-space indent).
const readWorkflow = (name) => readFileSync(`${workflowsDir}${name}`, 'utf8');
const workflows = readdirSync(workflowsDir).filter((name) => name.endsWith('.yml'));
const reusables = workflows.filter((name) => /^ {2}workflow_call:/m.test(readWorkflow(name)));

test('the scan finds the shared gate among the reusable workflows', () => {
  assert.ok(reusables.includes('_ci-gate.yml'), `reusables found: ${reusables.join(', ')}`);
});

test('no reusable workflow declares a workflow-level concurrency block', () => {
  // Callers own concurrency. A called run's group matches every sibling call in
  // the same caller run, so a top-level block cancels its own siblings.
  const offenders = reusables.filter((name) => /^concurrency:/m.test(readWorkflow(name)));
  assert.deepEqual(
    offenders,
    [],
    `remove the top-level concurrency block from: ${offenders.join(', ')}`,
  );
});

test('ansible_lint_args is declared on the gate and forwarded to lint_args', () => {
  const gate = readWorkflow('_ci-gate.yml');
  assert.match(gate, /^ {6}ansible_lint_args:$/m);
  assert.match(gate, /^ {6}lint_args: \$\{\{ inputs\.ansible_lint_args \}\}$/m);
});
