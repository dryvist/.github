'use strict';

const INCIDENT_RE = /\b(?:zammad|vikunja)[ \t]+#?\d+\b/i;
const AGENT_MARKER_RE = /^Agent:/im;

function isAgentAuthored(pr) {
  const login = pr.user && pr.user.login;
  if (typeof login === 'string' && login.endsWith('[bot]')) return true;
  return AGENT_MARKER_RE.test(pr.body || '');
}

function citesIncident(body) {
  return INCIDENT_RE.test(body || '');
}

module.exports = async ({ context, core }) => {
  const pr = context.payload.pull_request;
  if (!pr) return core.info('Not a pull_request event — skipping.');
  if (!isAgentAuthored(pr)) return core.info(`${pr.user.login} is not an agent — skipping.`);
  if (citesIncident(pr.body)) return core.info('Incident id found in the PR body.');
  const msg = "Agent PR body must cite an incident id ('Zammad <n>' or 'Vikunja <n>').";
  return process.env.AGENT_PR_BODY_BLOCK === 'true' ? core.setFailed(msg) : core.warning(msg);
};

module.exports.isAgentAuthored = isAgentAuthored;
module.exports.citesIncident = citesIncident;
