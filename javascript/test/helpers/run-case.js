// Runs one shared case against an engine. Asserts results and error CODES only.
import assert from 'node:assert/strict';
import { ArithmosError } from '../../src/shared/index.js';
import { createStandardSession } from '../../src/calculator/index.js';
import { createProgrammerSession, formatAllBases } from '../../src/programmer/index.js';
import { createConverterSession } from '../../src/converter/index.js';

function expectError(fn, code) {
  assert.throws(fn, (e) => e instanceof ArithmosError && e.code === code,
    `expected ArithmosError ${code}`);
}

export function runStandardCase(c) {
  const session = createStandardSession();
  const steps = c.steps ?? [{ input: c.input, expected: c.expected, error: c.error }];
  for (const s of steps) {
    if (s.error) expectError(() => session.run(s.input), s.error);
    else assert.equal(session.run(s.input), s.expected, s.input);
  }
}

export function runProgrammerCase(c) {
  const session = createProgrammerSession();
  for (const line of c.setup ?? []) session.run(line);
  if (c.error) return expectError(() => session.run(c.input), c.error);
  const result = session.run(c.input);
  if (typeof c.expected === 'string') {
    assert.equal(result.type, 'convert');
    return assert.equal(result.text, c.expected);
  }
  assert.equal(result.type, 'value');
  const shown = formatAllBases(result.value);
  for (const [key, want] of Object.entries(c.expected)) assert.equal(shown[key], want, key);
  return undefined;
}

export function runConverterCase(c) {
  const session = createConverterSession();
  if (c.error) return expectError(() => session.run(c.input), c.error);
  const out = session.run(c.input);
  if (c.expectedContains) {
    const lines = out.split('\n');
    for (const want of c.expectedContains) assert.ok(lines.includes(want), `missing line "${want}"`);
    return undefined;
  }
  return assert.equal(out, c.expected);
}
