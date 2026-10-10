import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repo = fileURLToPath(new URL('../', import.meta.url));
const script = join(repo, 'scripts/check-template-callers.sh');

// A caller shaped like a template's ci-gate.yml: one job that calls _ci-gate.yml
// at `ref`, with the python profile unless withBlock says otherwise.
function caller({
  ref = 'v1',
  withBlock = '    with:\n      profile: python\n',
  grant = ['contents: read', 'pull-requests: read', 'actions: write'],
} = {}) {
  const perms = grant.map((line) => `      ${line}`).join('\n');
  return `name: CI Gate
on:
  pull_request:
jobs:
  gate:
    permissions:
${perms}
    uses: dryvist/.github/.github/workflows/_ci-gate.yml@${ref}
${withBlock}`;
}

// Copies the script and the workflows into a throwaway root, applies an optional
// edit to the copied gate, writes the callers under callers/, and runs the checker.
// With `hooks`, writes a template's pre-commit config and its shared template and
// adds --hooks for the python-template pair.
function run({ gateEdit, callers, hooks }) {
  const root = mkdtempSync(join(tmpdir(), 'template-callers-'));
  try {
    mkdirSync(join(root, 'scripts'));
    cpSync(script, join(root, 'scripts/check-template-callers.sh'));
    cpSync(join(repo, '.github'), join(root, '.github'), { recursive: true });
    const gate = join(root, '.github/workflows/_ci-gate.yml');
    if (gateEdit) writeFileSync(gate, gateEdit(readFileSync(gate, 'utf8')));
    mkdirSync(join(root, 'callers'));
    const paths = Object.entries(callers).map(([name, text]) => {
      const path = join(root, 'callers', `${name}.yml`);
      writeFileSync(path, text);
      return path;
    });
    const args = [];
    if (hooks) {
      mkdirSync(join(root, 'hooks'));
      const config = join(root, 'hooks', 'python-template.pre-commit-config.yaml');
      const shared = join(root, 'hooks', 'python.yaml');
      writeFileSync(config, hooks.config);
      writeFileSync(shared, hooks.shared);
      args.push('--hooks', config, shared);
    }
    return spawnSync('bash', [join(root, 'scripts/check-template-callers.sh'), ...args, ...paths], {
      cwd: root,
      encoding: 'utf8',
    });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test('a caller that passes known inputs and grants the gate its scopes passes', () => {
  const r = run({ callers: { 'python-template': caller({ withBlock: '    with:\n      profile: python\n' }) } });
  assert.equal(r.status, 0, r.stdout + r.stderr);
});

test('a with key the gate does not declare fails, naming the template and key', () => {
  const r = run({
    callers: {
      'cc-edge-pack-template': caller({ withBlock: '    with:\n      profile: docs\n      bogus_key: true\n' }),
    },
  });
  assert.equal(r.status, 1);
  assert.match(r.stdout, /cc-edge-pack-template: job 'gate' passes 'bogus_key'/);
});

test('a required gate input the caller omits fails, naming the template and input', () => {
  const r = run({
    gateEdit: (text) =>
      text.replace(/^ {4}inputs:\n/m, '    inputs:\n      must_pass:\n        type: boolean\n        required: true\n'),
    callers: { 'tofu-aws-templates': caller() },
  });
  assert.equal(r.status, 1);
  assert.match(r.stdout, /tofu-aws-templates: job 'gate' omits required input 'must_pass'/);
});

test('a caller that grants less than the gate needs fails, naming the scope', () => {
  const r = run({ callers: { 'python-template': caller({ grant: ['contents: read', 'pull-requests: read'] }) } });
  assert.equal(r.status, 1);
  assert.match(r.stdout, /python-template: job 'gate' grants actions: none; _ci-gate.yml needs write/);
});

test('a caller with no job that calls _ci-gate.yml fails', () => {
  const r = run({
    callers: {
      'docs-template':
        'name: docs\non: push\njobs:\n  build:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: true\n',
    },
  });
  assert.equal(r.status, 1);
  assert.match(r.stdout, /docs-template: no job calls _ci-gate.yml/);
});

test('a caller pinned to a ref other than v1 fails, naming the job and ref', () => {
  const r = run({ callers: { 'python-template': caller({ ref: 'main' }) } });
  assert.equal(r.status, 1);
  assert.match(
    r.stdout,
    /python-template: job 'gate' calls dryvist\/\.github\/\.github\/workflows\/_ci-gate\.yml@main, not dryvist/,
  );
});

test('a caller with no profile input fails, naming the job', () => {
  const r = run({ callers: { 'python-template': caller({ withBlock: '    with:\n      nix_validate: true\n' }) } });
  assert.equal(r.status, 1);
  assert.match(r.stdout, /python-template: job 'gate' omits the profile input/);
});

test('a profile the gate does not accept fails, naming the value', () => {
  const r = run({ callers: { 'python-template': caller({ withBlock: '    with:\n      profile: java\n' }) } });
  assert.equal(r.status, 1);
  assert.match(r.stdout, /python-template: job 'gate' passes profile 'java'/);
});

const SHARED_HOOKS = `repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.15.18
    hooks:
      - id: ruff-check
      - id: pyright
`;

test('a shared hook id missing from the template pre-commit config fails, naming the hook', () => {
  const r = run({
    callers: { 'python-template': caller() },
    hooks: {
      shared: SHARED_HOOKS,
      config: `repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.15.18
    hooks:
      - id: ruff-check
`,
    },
  });
  assert.equal(r.status, 1);
  assert.match(r.stdout, /python-template: pre-commit config has no 'pyright' hook from python.yaml/);
});

test('repo-local hooks beyond the shared set pass', () => {
  const r = run({
    callers: { 'python-template': caller() },
    hooks: {
      shared: SHARED_HOOKS,
      config: `${SHARED_HOOKS}  - repo: local
    hooks:
      - id: local-check
        name: local check
        entry: true
        language: system
        pass_filenames: false
`,
    },
  });
  assert.equal(r.status, 0, r.stdout + r.stderr);
});
