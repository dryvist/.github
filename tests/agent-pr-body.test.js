'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const run = require('../.github/scripts/agent-pr-body.js');
const { isAgentAuthored, citesIncident } = run;

test('agent detection: [bot] login, Agent: marker, plain human', () => {
  assert.equal(isAgentAuthored({ user: { login: 'coder-bot[bot]' }, body: '' }), true);
  assert.equal(isAgentAuthored({ user: { login: 'jpevans' }, body: 'Agent: coder' }), true);
  assert.equal(isAgentAuthored({ user: { login: 'jpevans' }, body: 'Fixes a typo.' }), false);
});

test('citesIncident: either tracker, case-insensitive, with or without #', () => {
  assert.equal(citesIncident('Fixes Zammad 17257.'), true);
  assert.equal(citesIncident('closes vikunja #3096'), true);
  assert.equal(citesIncident('No ticket here.'), false);
});

function harness(pullRequest) {
  const log = { warnings: [], failures: [] };
  const core = { info: () => {}, warning: (m) => log.warnings.push(m), setFailed: (m) => log.failures.push(m) };
  return { log, state: { context: { payload: { pull_request: pullRequest } }, core } };
}

test('missing incident id warns by default, fails when block=true', async () => {
  const bad = { user: { login: 'coder-bot[bot]' }, body: 'No incident cited.' };
  const warn = harness(bad);
  await run(warn.state);
  assert.equal(warn.log.warnings.length, 1);
  assert.deepEqual(warn.log.failures, []);

  process.env.AGENT_PR_BODY_BLOCK = 'true';
  const fail = harness(bad);
  await run(fail.state).finally(() => delete process.env.AGENT_PR_BODY_BLOCK);
  assert.deepEqual(fail.log.warnings, []);
  assert.equal(fail.log.failures.length, 1);
});

test('a non-agent PR and a non-pull_request event are both silent', async () => {
  const human = harness({ user: { login: 'jpevans' }, body: 'plain PR' });
  const noPr = harness(undefined);
  await Promise.all([run(human.state), run(noPr.state)]);
  assert.deepEqual([...human.log.warnings, ...human.log.failures, ...noPr.log.warnings, ...noPr.log.failures], []);
});
