'use strict';

const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const test = require('node:test');

const workflow = readFileSync(
  join(__dirname, '../.github/workflows/_ansible-ci.yml'),
  'utf8',
);

const ansibleLintStart = workflow.indexOf('  ansible-lint:\n');
const moleculeStart = workflow.indexOf('\n  molecule:\n', ansibleLintStart);
assert.notEqual(ansibleLintStart, -1, 'Ansible lint job is present');
assert.notEqual(moleculeStart, -1, 'Molecule job follows Ansible lint');
const ansibleLint = workflow.slice(ansibleLintStart, moleculeStart);

test('reconciles a restored Galaxy cache against current requirements before lint', () => {
  const cacheStart = ansibleLint.indexOf('- name: Cache Ansible Galaxy content');
  const collectionsStart = ansibleLint.indexOf('- name: Install Ansible collections');
  const rolesStart = ansibleLint.indexOf('- name: Install Ansible roles');
  const lintActionStart = ansibleLint.indexOf('uses: ansible/ansible-lint@');

  assert.ok(cacheStart >= 0, 'Ansible lint job caches Galaxy content');
  assert.ok(collectionsStart > cacheStart, 'collection install follows cache restore');
  assert.ok(rolesStart > collectionsStart, 'role install follows collection install');
  assert.ok(lintActionStart > rolesStart, 'ansible-lint runs after dependency reconciliation');
  assert.match(ansibleLint.slice(cacheStart, collectionsStart), /id: galaxy-cache/);
  assert.match(ansibleLint.slice(cacheStart, collectionsStart), /restore-keys:/);

  for (const [start, end, command] of [
    [collectionsStart, rolesStart, 'ansible-galaxy collection install'],
    [rolesStart, lintActionStart, 'ansible-galaxy role install'],
  ]) {
    const step = ansibleLint.slice(start, end);
    assert.match(step, /if: steps\.galaxy-cache\.outputs\.cache-hit != 'true'/);
    assert.ok(step.includes(`run: ${command} -r requirements.yml --force`));
  }
});
