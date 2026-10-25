import { fail } from '../shared/errors';
import { formatNumber } from '../shared/format-number';
import { evaluate } from './evaluator';
import { parse } from './parser';
import { tokenize } from './tokenizer';

/** Evaluate one expression to a number. `ans` is the previous result. */
export function calculate(expr: string, ans = 0): number {
  try {
    return evaluate(parse(tokenize(expr)), ans);
  } catch (e) {
    // Absurdly deep nesting overflows the JS stack; report it as a normal error.
    if (e instanceof RangeError) fail('INVALID_EXPRESSION', 'The expression is nested too deeply');
    throw e;
  }
}

/** A Standard Calculator session. Holds `ans`, which changes only on success. */
export class Calculator {
  ans = 0;

  evaluate(line: string): string {
    const value = calculate(line, this.ans);
    const text = formatNumber(value); // may throw; ans is untouched in that case
    this.ans = value;
    return text;
  }
}