// Walks the AST and returns a JS number. Applies percent rules (spec 3.4) and
// power/sqrt domain rules (spec 3.5). Throws ArithmosError, never returns NaN.
import { fail } from '../shared/index.js';

function guard(x) {
  if (Number.isNaN(x)) fail('DOMAIN_ERROR', 'Result is not a number');
  if (!Number.isFinite(x)) fail('OVERFLOW', 'Result is too large to represent');
  return x;
}

function power(base, exp) {
  if (base === 0 && exp === 0) fail('UNDEFINED', '0^0 is undefined');
  if (base === 0 && exp < 0) fail('DIV_BY_ZERO', 'Zero cannot be raised to a negative power');
  if (base < 0 && !Number.isInteger(exp)) fail('DOMAIN_ERROR', 'Negative base with fractional exponent');
  return guard(Math.pow(base, exp));
}

export function evaluateAst(ast, context = { ans: 0 }) {
  const ev = (n) => {
    switch (n.type) {
      case 'num': return guard(n.value);
      case 'ans': return context.ans;
      case 'group': return ev(n.arg);
      case 'pct': return guard(ev(n.arg) / 100);
      case 'unary': {
        const v = ev(n.arg);
        return n.op === '-' ? -v : v;
      }
      case 'call': {
        const v = ev(n.arg);
        if (n.fn === 'sqrt') {
          if (v < 0) fail('DOMAIN_ERROR', 'Square root of a negative number');
          return Math.sqrt(v);
        }
        return Math.abs(v);
      }
      case 'bin': {
        const l = ev(n.left);
        // A percent that is the *direct* right operand of + or - is relative
        // to the left operand (spec 3.4).
        if ((n.op === '+' || n.op === '-') && n.right.type === 'pct') {
          const delta = guard(l * (ev(n.right.arg) / 100));
          return guard(n.op === '+' ? l + delta : l - delta);
        }
        const r = ev(n.right);
        switch (n.op) {
          case '+': return guard(l + r);
          case '-': return guard(l - r);
          case '*': return guard(l * r);
          case '/':
            if (r === 0) fail('DIV_BY_ZERO', 'Cannot divide by zero');
            return guard(l / r);
          case '^': return power(l, r);
          default: return fail('INVALID_EXPRESSION', `Unknown operator ${n.op}`);
        }
      }
      default: return fail('INVALID_EXPRESSION', 'Malformed expression');
    }
  };
  return guard(ev(ast));
}
