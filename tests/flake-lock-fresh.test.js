'use strict';

// flake-lock-fresh.sh: a direct input owned by one of OWNERS must be locked at its branch head.
// A fake `git` on PATH answers ls-remote, so the test needs no network.
const assert = require('node:assert/strict');
const test = require('node:test');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const script = path.join(__dirname, '..', 'scripts', 'flake-lock-fresh.sh');
const HEAD = 'a'.repeat(40);
const STALE = 'b'.repeat(40);

function run(lock) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flf-'));
  // Fake git: every ref resolves to HEAD.
  fs.writeFileSync(path.join(dir, 'git'), `#!/bin/sh\nprintf '%s\\t%s\\n' ${HEAD} "$3"\n`, { mode: 0o755 });
  fs.writeFileSync(path.join(dir, 'flake.lock'), JSON.stringify(lock));
  const names = path.join(dir, 'stale-names');
  const r = spawnSync('bash', [script, path.join(dir, 'flake.lock')], {
    env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, OWNERS: 'ours other-ours', STALE_NAMES_FILE: names },
    encoding: 'utf8',
  });
  return { ...r, names: fs.readFileSync(names, 'utf8').split('\n').filter(Boolean) };
}

const node = (owner, rev, ref) => ({
  original: { type: 'github', owner, repo: 'r', ...(ref ? { ref } : {}) },
  locked: { type: 'github', owner, repo: 'r', rev },
});

const lock = (nodes) => ({
  version: 7,
  root: 'root',
  nodes: { root: { inputs: Object.fromEntries(Object.keys(nodes).map((k) => [k, k])) }, ...nodes },
});

test('passes when every owned input is at its branch head', () => {
  const r = run(lock({ a: node('ours', HEAD, 'main'), b: node('Ours', HEAD) }));
  assert.equal(r.status, 0, r.stdout + r.stderr);
});

test('fails and names the input when an owned input is stale', () => {
  const r = run(lock({ a: node('ours', HEAD, 'main'), b: node('ours', STALE, 'develop') }));
  assert.equal(r.status, 1);
  assert.match(r.stdout, /b \(ours\/r develop\) locked at b{40}, branch head is a{40}/);
  assert.deepEqual(r.names, ['b']);
});

test('checks every owner in OWNERS, not only the first', () => {
  const r = run(lock({ c: node('Other-Ours', STALE) }));
  assert.equal(r.status, 1);
  assert.deepEqual(r.names, ['c']);
});

test('never lists a third-party input, even a stale one', () => {
  const r = run(lock({ nixpkgs: node('NixOS', STALE, 'nixos-unstable'), b: node('ours', STALE) }));
  assert.equal(r.status, 1);
  assert.deepEqual(r.names, ['b']);
});

test('skips an owned input pinned to a revision', () => {
  const pinned = node('ours', STALE);
  pinned.original.rev = STALE;
  const r = run(lock({ p: pinned }));
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.deepEqual(r.names, []);
});
