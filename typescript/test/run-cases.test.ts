// Runs the shared cases (docs/release-1-cases.json). Never skip or todo a case.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { Calculator } from '../src/calculator';
import { convertLine } from '../src/converter';
import { Programmer } from '../src/programmer';
import { ArithmosError } from '../src/shared/errors';

interface Step {
  input: string;
  expected?: string | Record<string, string>;
  expectedContains?: string[];
  error?: string;
}
interface Case extends Partial<Step> {
  id: string;
  tool: 'standard' | 'programmer' | 'converter';
  setup?: string[];
  steps?: Step[];
}

// dist/test/ → repo root is three levels up.
const FILE = path.resolve(__dirname, '../../../docs/release-1-cases.json');
const cases = JSON.parse(readFileSync(FILE, 'utf8')) as Case[];

test('the shared file holds all 175 cases', () => {
  assert.equal(cases.length, 175);
});

/** Run one line through the right engine and compare with the expectation. */
function check(tool: Case['tool'], session: { calc: Calculator; prog: Programmer }, step: Step): void {
  const run = (): unknown => {
    if (tool === 'standard') return session.calc.evaluate(step.input);
    if (tool === 'programmer') return session.prog.execute(step.input);
    return convertLine(step.input);
  };

  if (step.error !== undefined) {
    assert.throws(run, (e: unknown) => e instanceof ArithmosError && e.code === step.error, step.input);
    return;
  }

  const out = run();
  if (typeof step.expected === 'string') {
    if (tool === 'standard') assert.equal(out, step.expected);
    else if (tool === 'programmer') assert.equal((out as { text: string }).text, step.expected);
    else assert.equal((out as string[]).join('\n'), step.expected);
  } else if (step.expected) {
    const display = (out as { display: Record<string, string> }).display;
    for (const [field, value] of Object.entries(step.expected)) assert.equal(display[field], value, field);
  } else if (step.expectedContains) {
    for (const line of step.expectedContains) assert.ok((out as string[]).includes(line), line);
  } else {
    assert.fail('case has no outcome');
  }
}

for (const c of cases) {
  test(`${c.id} (${c.tool})`, () => {
    const session = { calc: new Calculator(), prog: new Programmer() };
    for (const line of c.setup ?? []) session.prog.execute(line);
    for (const step of c.steps ?? [c as Step]) check(c.tool, session, step);
  });
}