import { fail } from '../shared/errors';
import type { Node } from './parser';

/** Every intermediate result passes through here: NaN and Infinity never escape. */
function checked(r: number): number {
  if (Number.isNaN(r)) fail('DOMAIN_ERROR', 'The result is not a number');
  if (!Number.isFinite(r)) fail('OVERFLOW', 'The result is too large');
  return r;
}

/** Spec §3.5 power rules. */
function power(base: number, exp: number): number {
  if (base === 0 && exp === 0) fail('UNDEFINED', '0^0 is undefined');
  if (base === 0 && exp < 0) fail('DIV_BY_ZERO', 'Zero cannot be raised to a negative power');
  if (base < 0 && !Number.isInteger(exp)) {
    fail('DOMAIN_ERROR', 'A negative number cannot have a fractional power');
  }
  return checked(Math.pow(base, exp)); // 10^-400 underflows to 0 with no error (R9)
}

export function evaluate(node: Node, ans: number): number {
  switch (node.type) {
    case 'num':
      return checked(Number(node.text)); // a 400-digit literal is OVERFLOW
    case 'ans':
      return ans;
    case 'group':
      return evaluate(node.arg, ans);
    case 'percent':
      return evaluate(node.arg, ans) / 100;
    case 'unary': {
      const v = evaluate(node.arg, ans);
      return node.op === '-' ? -v : v;
    }
    case 'call': {
      const v = evaluate(node.arg, ans);
      if (node.fn === 'abs') return Math.abs(v);
      if (v < 0) fail('DOMAIN_ERROR', 'Cannot take the square root of a negative number');
      return Math.sqrt(v);
    }
    case 'binary': {
      const l = evaluate(node.left, ans);
      // `x + 10%` / `x - 10%`: a percent as the DIRECT right operand is relative to x.
      // Everywhere else a percent is just value / 100 (spec §3.4).
      const r =
        (node.op === '+' || node.op === '-') && node.right.type === 'percent'
          ? l * evaluate(node.right, ans)
          : evaluate(node.right, ans);
      switch (node.op) {
        case '+': return checked(l + r);
        case '-': return checked(l - r);
        case '*':
        case 'of': return checked(l * r);
        case '/':
          if (r === 0) fail('DIV_BY_ZERO', 'Cannot divide by zero');
          return checked(l / r);
        case '^': return power(l, r);
      }
    }
  }
}