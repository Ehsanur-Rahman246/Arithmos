// Data-driven runner for the shared standard cases (spec Section 8).
// Asserts results and error CODES only — never message text.
import { test } from 'node:test';
import { loadCases } from './helpers/load-cases.js';
import { runStandardCase } from './helpers/run-case.js';

for (const c of loadCases('standard')) {
  test(`${c.id}: ${c.input ?? c.steps.map((s) => s.input).join(' ; ')}`, () => runStandardCase(c));
}
