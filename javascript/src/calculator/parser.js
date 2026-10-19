// Recursive-descent parser producing an AST. Precedence (high -> low), spec 3.3:
//   ( ) / calls  >  postfix %  >  ^ (right-assoc)  >  unary +/-  >  * / of  >  + -
// Implicit multiplication is rejected with INVALID_EXPRESSION.
//
// AST nodes: num, ans, group, pct, unary, call, bin.
// `group` marks a parenthesised sub-expression so that `200 + (10%)` is NOT
// treated as a relative percent (only a directly attached % is).
import { fail } from '../shared/index.js';

export function parse(tokens) {
  let pos = 0;
  const peek = () => tokens[pos];
  const next = () => tokens[pos++];
  const isOp = (t, ...ops) => t && t.type === 'op' && ops.includes(t.value);
  const isWord = (t, w) => t && t.type === 'ident' && t.value === w;
  const bad = (msg) => fail('INVALID_EXPRESSION', msg);

  function expression() {
    let left = term();
    while (isOp(peek(), '+', '-')) {
      const op = next().value;
      left = { type: 'bin', op, left, right: term() };
    }
    return left;
  }

  function term() {
    let left = unary();
    for (;;) {
      const t = peek();
      if (isOp(t, '*', '/')) {
        next();
        left = { type: 'bin', op: t.value, left, right: unary() };
      } else if (isWord(t, 'of')) {
        next();
        left = { type: 'bin', op: '*', left, right: unary() };
      } else break;
    }
    return left;
  }

  function unary() {
    if (isOp(peek(), '+', '-')) {
      const op = next().value;
      return { type: 'unary', op, arg: unary() };
    }
    return power();
  }

  function power() {
    const base = postfix();
    if (isOp(peek(), '^')) {
      next();
      return { type: 'bin', op: '^', left: base, right: unary() };
    }
    return base;
  }

  function postfix() {
    let node = primary();
    while (peek() && peek().type === 'percent') {
      next();
      node = { type: 'pct', arg: node };
    }
    return node;
  }

  function primary() {
    const t = next();
    if (!t) bad('The expression ends too early');
    if (t.type === 'num') return { type: 'num', value: t.value };
    if (t.type === 'ident') {
      if (t.value === 'ans') return { type: 'ans' };
      if (t.value === 'sqrt' || t.value === 'abs') {
        const open = next();
        if (!open || open.type !== 'lparen') bad(`${t.value} needs parentheses, like ${t.value}(4)`);
        const arg = expression();
        const close = next();
        if (!close || close.type !== 'rparen') bad('Missing closing parenthesis');
        return { type: 'call', fn: t.value, arg };
      }
      bad(`Unexpected '${t.value}'`);
    }
    if (t.type === 'lparen') {
      const inner = expression();
      const close = next();
      if (!close || close.type !== 'rparen') bad('Missing closing parenthesis');
      return { type: 'group', arg: inner };
    }
    return bad('Unexpected symbol');
  }

  if (tokens.length === 0) bad('Nothing to calculate');
  const ast = expression();
  if (pos < tokens.length) bad('Unexpected symbol');
  return ast;
}
