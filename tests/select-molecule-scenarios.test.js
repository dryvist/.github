'use strict';

const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { mkdtempSync, readFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const test = require('node:test');
const selectorPath = require.resolve('../.github/scripts/select-molecule-scenarios.js');
const workflowPath = require.resolve('../.github/workflows/_ansible-ci.yml');
const { selectMoleculeScenarios } = require(selectorPath);

function selection(changedFiles, scenarios = {}, contractFiles = [], fullMatrixFiles = []) {
  const filterOutputs = {
    changed_files: JSON.stringify(changedFiles),
    contract_only_files: JSON.stringify(contractFiles),
    full_matrix_files: JSON.stringify(fullMatrixFiles),
  };
  const matchedFilters = ['changed'];
  for (const [name, files] of Object.entries(scenarios)) {
    matchedFilters.push(name);
    filterOutputs[`${name}_files`] = JSON.stringify(files);
  }
  if (contractFiles.length > 0) matchedFilters.push('contract_only');
  if (fullMatrixFiles.length > 0) matchedFilters.push('full_matrix');
  return selectMoleculeScenarios({ changedFiles, matchedFilters, filterOutputs });
}

test('selects all mapped scenarios when every relevant path is covered', () => {
  assert.equal(
    selection(['roles/a/tasks/main.yml', 'molecule/b/molecule.yml'], {
      a: ['roles/a/tasks/main.yml'],
      b: ['molecule/b/molecule.yml'],
    }),
    '["a","b"]',
  );
});

test('selects the mapped scenario for a caller workflow change', () => {
  const changedFile = '.github/workflows/ci-gate.yml';

  assert.equal(
    selection([changedFile], { llm_gpu_serving: [changedFile] }),
    '["llm_gpu_serving"]',
  );
});

test('caller workflow paths are classified without forcing the full matrix', () => {
  const workflow = readFileSync(workflowPath, 'utf8');
  const changedStart = workflow.indexOf('            changed:\n');
  const fullMatrixStart = workflow.indexOf('            full_matrix:\n', changedStart);
  const scenarioFiltersStart = workflow.indexOf('            ${{ inputs.molecule_scenario_filters }}', fullMatrixStart);

  assert.ok(changedStart >= 0);
  assert.ok(fullMatrixStart > changedStart);
  assert.ok(scenarioFiltersStart > fullMatrixStart);
  assert.match(workflow.slice(changedStart, fullMatrixStart), /- '\.github\/workflows\/\*\*'/);
  assert.doesNotMatch(workflow.slice(fullMatrixStart, scenarioFiltersStart), /\.github\/workflows\/\*\*/);
});

test('accepts scenario names used by the repository scenario discovery contract', () => {
  assert.equal(
    selection(['molecule/scenario-2/molecule.yml'], {
      'scenario-2': ['molecule/scenario-2/molecule.yml'],
    }),
    '["scenario-2"]',
  );
});

test('an unmapped path fails instead of widening a PR to the full matrix', () => {
  assert.throws(
    () =>
      selection(['roles/a/tasks/main.yml', 'roles/new_role/tasks/main.yml'], {
        a: ['roles/a/tasks/main.yml'],
      }),
    /no scenario, caller-contract, or full-matrix mapping: roles\/new_role\/tasks\/main.yml/,
  );
});

test('uses contract-only coverage when every relevant path is covered', () => {
  assert.equal(
    selection(['roles/no_scenario/tasks/main.yml', 'tests/contract.py'], {}, [
      'roles/no_scenario/tasks/main.yml',
      'tests/contract.py',
    ]),
    '[]',
  );
});

test('uses contract coverage for a requirements-only change without widening the matrix', () => {
  const workflow = readFileSync(workflowPath, 'utf8');
  const fullMatrix = workflow.match(/^            full_matrix:\n((?:^              .*\n)*)/m)?.[1];

  assert.ok(fullMatrix, 'the full_matrix filter is present');
  assert.doesNotMatch(fullMatrix, /^              - 'requirements\.yml'$/m);
  assert.doesNotMatch(fullMatrix, /^              - '\.github\/(?:workflows|scripts)\/\*\*'$/m);
  assert.match(fullMatrix, /^              - 'requirements-ci\.txt'$/m);
  assert.equal((workflow.match(/^              - 'requirements\.yml'$/gm) || []).length, 3);
  assert.equal(selection(['requirements.yml'], {}, ['requirements.yml']), '[]');
  assert.equal(
    selection(['.github/workflows/ci-gate.yml'], {
      default: ['.github/workflows/ci-gate.yml'],
    }),
    '["default"]',
  );
});

test('uncovered requirements paths still fail selection', () => {
  assert.throws(
    () => selection(['requirements.yml']),
    /no scenario, caller-contract, or full-matrix mapping: requirements\.yml$/,
  );
});

test('unmapped CI harness paths select no scenario instead of failing', () => {
  assert.equal(selection(['.github/workflows/new-ci.yml']), '[]');
  assert.equal(selection(['.github/scripts/select-molecule-scenarios.js']), '[]');
  assert.equal(
    selection(['roles/a/tasks/main.yml', '.github/workflows/new-ci.yml'], {
      a: ['roles/a/tasks/main.yml'],
    }),
    '["a"]',
  );
});

test('an unmapped role path still fails beside an unmapped CI harness path', () => {
  assert.throws(
    () => selection(['.github/workflows/new-ci.yml', 'roles/new_role/tasks/main.yml']),
    /no scenario, caller-contract, or full-matrix mapping: roles\/new_role\/tasks\/main\.yml$/,
  );
});

test('a CI harness path runs the full set when the caller maps it into every scenario', () => {
  const changedFile = '.github/workflows/new-ci.yml';

  assert.equal(selection([changedFile], { a: [changedFile], b: [changedFile] }), '["a","b"]');
});

test('an unmapped CI harness path exits 0 with an empty matrix', () => {
  const directory = mkdtempSync(join(tmpdir(), 'molecule-selector-'));
  const outputPath = join(directory, 'github-output');
  try {
    execFileSync(process.execPath, [selectorPath], {
      env: {
        ...process.env,
        CHANGED_FILES: '[".github/workflows/new-ci.yml"]',
        MATCHED_FILTERS: '["changed"]',
        FILTER_OUTPUTS: '{}',
        GITHUB_OUTPUT: outputPath,
      },
    });
    assert.equal(readFileSync(outputPath, 'utf8'), 'scenarios=[]\n');
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
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

test('an unrelated playbook path fails instead of widening the campaign contract selection', () => {
  assert.throws(
    () =>
      selection(
        ['playbooks/llm-model-campaign-target.yml', 'playbooks/site.yml'],
        {},
        ['playbooks/llm-model-campaign-target.yml'],
      ),
    /no scenario, caller-contract, or full-matrix mapping: playbooks\/site\.yml/,
  );
});

test('an unmapped path fails for a mixed contract-only change', () => {
  assert.throws(
    () =>
      selection(['roles/no_scenario/tasks/main.yml', 'roles/new_role/tasks/main.yml'], {}, [
        'roles/no_scenario/tasks/main.yml',
      ]),
    /no scenario, caller-contract, or full-matrix mapping: roles\/new_role\/tasks\/main.yml/,
  );
});

test('mixed scenario and contract paths run the mapped scenarios and caller contracts', () => {
  assert.equal(
    selection(
      ['roles/a/tasks/main.yml', 'roles/no_scenario/tasks/main.yml'],
      {
        a: ['roles/a/tasks/main.yml'],
      },
      ['roles/no_scenario/tasks/main.yml'],
    ),
    '["a"]',
  );
});

test('does not widen an empty focused path set to the full matrix', () => {
  assert.equal(selection([]), '[]');
});

test('defers unmapped shared paths to the main-merge suite instead of widening a PR', () => {
  assert.equal(selection(['.github/workflows/ci.yml'], {}, [], ['.github/workflows/ci.yml']), '[]');
});

test('runs mapped scenarios while deferring shared paths to the main-merge suite', () => {
  assert.equal(
    selection(
      ['roles/a/tasks/main.yml', '.github/workflows/ci.yml'],
      { a: ['roles/a/tasks/main.yml'] },
      [],
      ['.github/workflows/ci.yml'],
    ),
    '["a"]',
  );
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
