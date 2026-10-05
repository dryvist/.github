import { pathToFileURL } from 'node:url';

type JobResult = {
  result?: unknown;
};

type Needs = Record<string, JobResult>;

const knownResults = new Set(['success', 'failure', 'cancelled', 'skipped']);

function gateFailures(
  needs: Needs,
  allowedSkips: ReadonlySet<string>,
  allowedFailures: ReadonlySet<string>,
): string[] {
  return Object.entries(needs).flatMap(([name, job]) => {
    const result = job.result;
    if (result === 'success' || (result === 'skipped' && allowedSkips.has(name))) return [];
    if (result === 'failure' && allowedFailures.has(name)) return [];
    if (typeof result !== 'string' || !knownResults.has(result)) {
      return [`job "${name}" returned unknown result ${JSON.stringify(result) ?? String(result)}`];
    }
    return [`job "${name}" returned ${result}`];
  });
}

function parseSet(value: string | undefined): ReadonlySet<string> {
  return new Set((value ?? '').split(',').map((entry) => entry.trim()).filter(Boolean));
}

function isNeeds(value: unknown): value is Needs {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    Object.values(value).every((job) => typeof job === 'object' && job !== null && !Array.isArray(job))
  );
}

function main(): void {
  let parsed: unknown;
  try {
    parsed = JSON.parse(process.env.CI_GATE_JOBS ?? '');
  } catch {
    console.error('Merge Gate failed: CI_GATE_JOBS is not valid JSON.');
    process.exitCode = 1;
    return;
  }
  if (!isNeeds(parsed)) {
    console.error('Merge Gate failed: CI_GATE_JOBS must be an object of job results.');
    process.exitCode = 1;
    return;
  }

  const failures = gateFailures(
    parsed,
    parseSet(process.env.CI_GATE_ALLOWED_SKIPS),
    parseSet(process.env.CI_GATE_ALLOWED_FAILURES),
  );
  if (failures.length > 0) {
    console.error(`Merge Gate failed: ${failures.join('; ')}.`);
    process.exitCode = 1;
    return;
  }
  console.log(`Merge Gate passed: ${Object.keys(parsed).length} jobs checked.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
