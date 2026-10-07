'use strict';

const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { mkdtempSync, readFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const test = require('node:test');
const selectorPath = require.resolve('../.github/scripts/select-molecule-scenarios.js');
const ansibleCiWorkflowPath = require.resolve('../.github/workflows/_ansible-ci.yml');
const { selectMoleculeScenarios } = require(selectorPath);

function selection(changedFiles, scenarios = {}, contractFiles = []) {
  const filterOutputs = {
    changed_files: JSON.stringify(changedFiles),
    contract_only_files: JSON.stringify(contractFiles),
  };
  const matchedFilters = ['changed'];
  for (const [name, files] of Object.entries(scenarios)) {
    matchedFilters.push(name);
    filterOutputs[`${name}_files`] = JSON.stringify(files);
  }
  if (contractFiles.length > 0) matchedFilters.push('contract_only');
  return selectMoleculeScenarios({ changedFiles, matchedFilters, filterOutputs });
}

test('selects all mapped scenarios when every relevant path is covered', () => {
  assert.equal(selection(['roles/a/tasks/main.yml', 'molecule/b/molecule.yml'], {
    a: ['roles/a/tasks/main.yml'],
    b: ['molecule/b/molecule.yml'],
  }), '["a","b"]');
});

test('accepts scenario names used by the repository scenario discovery contract', () => {
  assert.equal(selection(['molecule/scenario-2/molecule.yml'], {
    'scenario-2': ['molecule/scenario-2/molecule.yml'],
  }), '["scenario-2"]');
});

test('an unmapped path widens a mixed known and unknown role change', () => {
  assert.equal(selection(['roles/a/tasks/main.yml', 'roles/new_role/tasks/main.yml'], {
    a: ['roles/a/tasks/main.yml'],
  }), '');
});

test('uses contract-only coverage when every relevant path is covered', () => {
  assert.equal(selection(['roles/no_scenario/tasks/main.yml', 'tests/contract.py'], {}, [
    'roles/no_scenario/tasks/main.yml',
    'tests/contract.py',
  ]), '[]');
});

test('uses contract coverage for a requirements-only change without widening the matrix', () => {
  const workflow = readFileSync(ansibleCiWorkflowPath, 'utf8');
  const fullMatrix = workflow.match(/^            full_matrix:\n((?:^              .*\n)*)/m)?.[1];

  assert.ok(fullMatrix, 'the full_matrix filter is present');
  assert.doesNotMatch(fullMatrix, /^              - 'requirements\.yml'$/m);
  assert.match(fullMatrix, /^              - 'requirements-ci\.txt'$/m);
  assert.equal((workflow.match(/^              - 'requirements\.yml'$/gm) || []).length, 3);
  assert.equal(selection(['requirements.yml'], {}, ['requirements.yml']), '[]');
});

test('an uncovered requirements-only change keeps the full matrix', () => {
  assert.equal(selection(['requirements.yml']), '');
});

test('an unmapped path widens a mixed contract-only change', () => {
  assert.equal(selection(['roles/no_scenario/tasks/main.yml', 'roles/new_role/tasks/main.yml'], {}, [
    'roles/no_scenario/tasks/main.yml',
  ]), '');
});

test('mixed scenario and contract paths run the mapped scenarios and caller contracts', () => {
  assert.equal(selection(['roles/a/tasks/main.yml', 'roles/no_scenario/tasks/main.yml'], {
    a: ['roles/a/tasks/main.yml'],
  }, ['roles/no_scenario/tasks/main.yml']), '["a"]');
});

test('writes the selected matrix to GITHUB_OUTPUT', () => {
  const directory = mkdtempSync(join(tmpdir(), 'molecule-selector-'));
  const outputPath = join(directory, 'github-output');
  try {
    execFileSync(process.execPath, [selectorPath], {
      env: {
        ...process.env,
        CHANGED_FILES: '["roles/a/tasks/main.yml"]',
        MATCHED_FILTERS: '["changed","a"]',
        FILTER_OUTPUTS: '{"a_files":"[\\"roles/a/tasks/main.yml\\"]"}',
        GITHUB_OUTPUT: outputPath,
      },
    });
    assert.equal(readFileSync(outputPath, 'utf8'), 'scenarios=["a"]\n');
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
