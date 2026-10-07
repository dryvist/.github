'use strict';

const { appendFileSync } = require('node:fs');

function parseJson(value, fallback, label) {
  try {
    return JSON.parse(value || JSON.stringify(fallback));
  } catch (error) {
    throw new Error(`${label} is not valid JSON: ${error.message}`);
  }
}

function selectMoleculeScenarios({ changedFiles, matchedFilters, filterOutputs }) {
  const reserved = new Set(['changed', 'contract_only', 'full_matrix']);
  const scenarios = matchedFilters.filter((name) => !reserved.has(name));
  const coveredFiles = new Set();

  for (const scenario of scenarios) {
    if (!/^[A-Za-z0-9_-]+$/.test(scenario)) {
      throw new Error(`Invalid Molecule scenario filter name: ${scenario}`);
    }
    const files = parseJson(filterOutputs[`${scenario}_files`], [], `${scenario}_files`);
    for (const file of files) coveredFiles.add(file);
  }

  if (matchedFilters.includes('contract_only')) {
    const files = parseJson(filterOutputs.contract_only_files, [], 'contract_only_files');
    for (const file of files) coveredFiles.add(file);
  }

  if (changedFiles.length === 0) return '[]';

  const uncoveredFiles = changedFiles.filter((file) => !coveredFiles.has(file));
  const fullMatrixFiles = new Set(parseJson(filterOutputs.full_matrix_files, [], 'full_matrix_files'));
  const unclassifiedFiles = uncoveredFiles.filter((file) => !fullMatrixFiles.has(file));
  if (unclassifiedFiles.length > 0) {
    const message = [
      'Changed Molecule paths have no scenario, caller-contract, or full-matrix mapping:',
      ...unclassifiedFiles,
    ].join(' ');
    throw new Error(message);
  }
  if (scenarios.length > 0) return JSON.stringify(scenarios);
  if (matchedFilters.includes('contract_only')) return '[]';
  if (uncoveredFiles.length > 0) return '[]';
  throw new Error('Changed Molecule paths have no scenario or caller-contract mapping.');
}

if (require.main === module) {
  try {
    const scenarios = selectMoleculeScenarios({
      changedFiles: parseJson(process.env.CHANGED_FILES, [], 'CHANGED_FILES'),
      matchedFilters: parseJson(process.env.MATCHED_FILTERS, [], 'MATCHED_FILTERS'),
      filterOutputs: parseJson(process.env.FILTER_OUTPUTS, {}, 'FILTER_OUTPUTS'),
    });
    if (!process.env.GITHUB_OUTPUT) throw new Error('GITHUB_OUTPUT is required');
    appendFileSync(process.env.GITHUB_OUTPUT, `scenarios=${scenarios}\n`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

module.exports = { selectMoleculeScenarios };
