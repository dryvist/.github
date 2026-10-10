import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const workflow = readFileSync(
  new URL('../.github/workflows/_ci-gate.yml', import.meta.url),
  'utf8',
);

const nixBuildJob = workflow.slice(
  workflow.indexOf('\n  nix-build:\n'),
  workflow.indexOf('\n  markdown-lint:\n'),
);

test('nix-build is gated on the nix_build toggle alone, not on profile nix', () => {
  const ifLine = nixBuildJob.match(/^\s+if: \$\{\{ (.*) \}\}$/m);
  assert.ok(ifLine, 'nix-build job has an if: expression');
  assert.match(ifLine[1], /inputs\.nix_build\b/);
  assert.doesNotMatch(ifLine[1], /inputs\.profile == 'nix'/);
});

test('nix_build_command is an empty-by-default string input forwarded as build-command', () => {
  const input = workflow.slice(
    workflow.indexOf('\n      nix_build_command:\n'),
    workflow.indexOf('\n      nix_skip_deps_only:\n'),
  );
  assert.match(input, /type: string/);
  assert.match(input, /default: ''/);
  assert.match(nixBuildJob, /with:\n\s+build-command: \$\{\{ inputs\.nix_build_command \}\}/);
});
