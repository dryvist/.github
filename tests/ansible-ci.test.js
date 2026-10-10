'use strict';

const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const test = require('node:test');

const ansibleCi = readFileSync('.github/workflows/_ansible-ci.yml', 'utf8');
const renovateValidator = readFileSync('.github/workflows/renovate-config-validate.yml', 'utf8');
const renovatePreset = JSON.parse(readFileSync('renovate-presets.json', 'utf8'));

test('shared Ansible CI runs strict Renovate validation for renovate.json changes', () => {
  assert.match(ansibleCi, /renovate_config:\n\s+- 'renovate\.json'/);
  assert.match(ansibleCi, /renovate_config:\n\s+name: Renovate Config Validate/);
  assert.match(ansibleCi, /if: \$\{\{ needs\.changes\.outputs\.renovate_config == 'true' \}\}/);
  assert.match(ansibleCi, /uses: \.\/\.github\/workflows\/renovate-config-validate\.yml/);
  assert.match(ansibleCi, /needs: \[changes, ansible-lint, molecule, token-limits, renovate-annotations, renovate_config\]/);
  assert.match(ansibleCi, /CI_GATE_ALLOWED_SKIPS: .*renovate_config/);
  assert.match(renovateValidator, /workflow_call:/);
  assert.match(renovateValidator, /config_file:/);
  assert.match(renovateValidator, /RENOVATE_CONFIG_FILE/);
  assert.match(renovateValidator, /renovate-config-validator --strict/);
  assert.match(renovateValidator, /RENOVATE_VERSION: "44\.82\.4"/);
  assert.match(renovateValidator, /node-version: "24\.11\.0"/);
  assert.match(renovateValidator, /key: renovate-cli-\$\{\{ runner\.os \}\}-\$\{\{ env\.RENOVATE_VERSION \}\}/);
});

test('Renovate custom managers track the validator tool and compatible Node pins', () => {
  const cases = [
    {
      depName: 'node',
      datasource: 'node-version',
      line: '          node-version: "24.11.0"',
      version: '24.11.0',
    },
    {
      depName: 'renovate',
      datasource: 'npm',
      line: '      RENOVATE_VERSION: "44.82.4"',
      version: '44.82.4',
    },
  ];

  for (const { depName, datasource, line, version } of cases) {
    const manager = renovatePreset.customManagers.find(
      (entry) => entry.depNameTemplate === depName && entry.datasourceTemplate === datasource,
    );
    assert.ok(manager, `missing ${datasource} manager for ${depName}`);
    assert.ok(manager.managerFilePatterns.some((pattern) => pattern.includes('.github/workflows')));
    const match = manager.matchStrings.map((pattern) => new RegExp(pattern).exec(line)).find(Boolean);
    assert.equal(match?.groups?.currentValue, version);
  }
});

test('unmapped Molecule paths never fail the run; they select the full profile with a warning per path', () => {
  assert.doesNotMatch(ansibleCi, /Require focused Molecule path mappings/);
  assert.doesNotMatch(ansibleCi, /Add Molecule scenario or caller-contract path mappings/);
  assert.match(ansibleCi, /echo "::notice::molecule off, mapping not required"/);
  assert.match(ansibleCi, /echo "::warning::unmapped path \$path, running full profile"/);
  assert.match(ansibleCi, /done < <\(jq -r '\.\[\]' <<<"\$\{MOLECULE_FILES:-\[\]\}"\)/);
  assert.match(ansibleCi, /echo "full_profile=true" >> "\$GITHUB_OUTPUT"/);
  assert.match(ansibleCi, /elif \[\[ "\$FULL_PROFILE" == true \]\]; then\n\s+printf 'scenarios=\\n'/);
});

test('unmapped paths warn only on molecule-matched files and select the full profile whether or not mappings are set', () => {
  assert.match(ansibleCi, /id: filter\n\s+with:\n\s+base: [^\n]*\n\s+list-files: json/);
  assert.match(ansibleCi, /MOLECULE_FILES: \$\{\{ steps\.filter\.outputs\.molecule_files \}\}/);
  assert.match(
    ansibleCi,
    /FULL_PROFILE: \$\{\{ steps\.unmapped\.outputs\.full_profile \|\| steps\.scenario_selection\.outputs\.full_profile \}\}/,
  );
  assert.doesNotMatch(ansibleCi, /still fails classification/);
});

test('Galaxy installs run only when requirements.yml exists and say so when it does not', () => {
  assert.equal((ansibleCi.match(/hashFiles\('requirements\.yml'\) != ''/g) || []).length, 4);
  assert.equal((ansibleCi.match(/echo "::notice::no requirements\.yml, nothing to install"/g) || []).length, 2);
  assert.doesNotMatch(ansibleCi, /if: steps\.galaxy-cache\.outputs\.cache-hit != 'true'\n/);
});

test('mapped Molecule paths still go through the scenario selector', () => {
  assert.match(ansibleCi, /Select scenarios only when every relevant path is covered/);
  assert.match(ansibleCi, /run: node \.gh-shared\/\.github\/scripts\/select-molecule-scenarios\.js/);
});
