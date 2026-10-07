'use strict';

const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { mkdtempSync, readFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const test = require('node:test');
const selectorPath = require.resolve('../.github/scripts/select-molecule-scenarios.js');
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

test('selects the mapped scenario for a caller workflow change', () => {
  const changedFile = '.github/workflows/ci-gate.yml';

  assert.equal(selection([changedFile], {
    llm_gpu_serving: [changedFile],
  }), '["llm_gpu_serving"]');
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

test('uses the campaign contract for the observed playbook and telemetry fixture changes', () => {
  const changedFiles = [
    'playbooks/llm-model-campaign-target.yml',
    'playbooks/tasks/llm-model-campaign-convert.yml',
    'playbooks/templates/llm-model-campaign-dimensions.json.j2',
    'tests/llm_model_campaign/fixtures/nvidia-smi-enforced-power-limit.csv',
    'tests/llm_model_campaign/test_dimensions.py',
  ];

  assert.equal(selection(changedFiles, {}, changedFiles), '[]');
});

test('an unrelated playbook change still widens the campaign contract selection', () => {
  assert.equal(selection([
    'playbooks/llm-model-campaign-target.yml',
    'playbooks/site.yml',
  ], {}, ['playbooks/llm-model-campaign-target.yml']), '');
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
