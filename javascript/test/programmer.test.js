// Data-driven runner for the shared programmer cases (spec Section 8).
// Asserts results and error CODES only — never message text.
import { test } from 'node:test';
import { loadCases } from './helpers/load-cases.js';
import { runProgrammerCase } from './helpers/run-case.js';

for (const c of loadCases('programmer')) {
  test(`${c.id}: ${c.input ?? c.steps.map((s) => s.input).join(' ; ')}`, () => runProgrammerCase(c));
}
