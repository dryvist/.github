'use strict';

const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const test = require('node:test');

const validator = readFileSync('.github/workflows/renovate-config-validate.yml', 'utf8');

test('Renovate config validator keeps its strict, configurable contract', () => {
  assert.match(validator, /workflow_call:/);
  assert.match(validator, /config_file:/);
  assert.match(validator, /RENOVATE_CONFIG_FILE/);
  assert.match(validator, /renovate-config-validator --strict/);
  assert.match(validator, /RENOVATE_VERSION: "\d+\.\d+\.\d+"/);
  assert.match(validator, /node-version: "\d+\.\d+\.\d+"/);
  assert.match(validator, /key: renovate-cli-\$\{\{ runner\.os \}\}-\$\{\{ env\.RENOVATE_VERSION \}\}/);
});
