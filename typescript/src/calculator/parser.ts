import { fail } from '../shared/errors';
import type { Token } from './tokenizer';

// `percent` and `group` are their own nodes: the evaluator needs to know that
// `200 + 10%` has a percent as its DIRECT right operand, while `200 + (10%)`
// does not (spec §3.4, amendment R1).
export type Node =
  | { type: 'num'; text: string }
  | { type: 'ans' }
  | { type: 'unary'; op: '+' | '-'; arg: Node }
  | { type: 'percent'; arg: Node }
  | { type: 'group'; arg: Node }
  | { type: 'call'; fn: 'sqrt' | 'abs'; arg: Node }
  | { type: 'binary'; op: '+' | '-' | '*' | '/' | '^' | 'of'; left: Node; right: Node };

/**
 * Recursive descent, lowest precedence first (spec §3.3):
 *   additive : mul (('+'|'-') mul)*
 *   mul      : unary (('*'|'/'|'of') unary)*
 *   unary    : ('+'|'-') unary | power
 *   power    : postfix ('^' unary)?          right-assoc, allows 2^-1
 *   postfix  : primary '%'*
 *   primary  : number | ans | fn '(' additive ')' | '(' additive ')'
 */
class Parser {
  private pos = 0;
  constructor(private readonly t: Token[]) {}

  peek(): Token | undefined { return this.t[this.pos]; }
  private next(): Token | undefined { return this.t[this.pos++]; }

  private isOp(tok: Token | undefined, ...ops: string[]): boolean {
    return tok?.kind === 'op' && ops.includes(tok.op);
  }

  additive(): Node {
    let left = this.mul();
    while (this.isOp(this.peek(), '+', '-')) {
      const op = (this.next() as { op: '+' | '-' }).op;
      left = { type: 'binary', op, left, right: this.mul() };
    }
    return left;
  }

  private mul(): Node {
    let left = this.unary();
    for (;;) {
      const tok = this.peek();
      if (this.isOp(tok, '*', '/')) {
        const op = (this.next() as { op: '*' | '/' }).op;
        left = { type: 'binary', op, left, right: this.unary() };
      } else if (tok?.kind === 'word' && tok.word === 'of') {
        this.next();
        left = { type: 'binary', op: 'of', left, right: this.unary() };
      } else {
        return left;
      }
    }
  }

  private unary(): Node {
    const tok = this.peek();
    if (this.isOp(tok, '+', '-')) {
      const op = (this.next() as { op: '+' | '-' }).op;
      return { type: 'unary', op, arg: this.unary() };
    }
    return this.power();
  }

  private power(): Node {
    const base = this.postfix();
    if (this.isOp(this.peek(), '^')) {
      this.next();
      return { type: 'binary', op: '^', left: base, right: this.unary() };
    }
    return base;
  }

  private postfix(): Node {
    let n = this.primary();
    while (this.peek()?.kind === 'percent') {
      this.next();
      n = { type: 'percent', arg: n };
    }
    return n;
  }

  private expectClose(): void {
    const tok = this.next();
    if (!tok) fail('INVALID_EXPRESSION', 'Missing closing parenthesis');
    if (tok.kind !== 'rparen') fail('INVALID_EXPRESSION', 'Unexpected symbol');
  }

  private primary(): Node {
    const tok = this.next();
    if (!tok) fail('INVALID_EXPRESSION', 'The expression ends too early');
    switch (tok.kind) {
      case 'num':
        return { type: 'num', text: tok.text };
      case 'lparen': {
        const arg = this.additive();
        this.expectClose();
        return { type: 'group', arg };
      }
      case 'word':
        if (tok.word === 'ans') return { type: 'ans' };
        if (tok.word === 'of') fail('INVALID_EXPRESSION', `Unexpected '${tok.raw.toLowerCase()}'`);
        // sqrt / abs
        if (this.next()?.kind !== 'lparen') {
          fail('INVALID_EXPRESSION', `${tok.word} needs parentheses, like ${tok.word}(4)`);
        }
        {
          const arg = this.additive();
          this.expectClose();
          return { type: 'call', fn: tok.word as 'sqrt' | 'abs', arg };
        }
      default:
        // ')', '*', '%', ... cannot start an operand
        fail('INVALID_EXPRESSION', 'Unexpected symbol');
    }
  }
}

export function parse(tokens: Token[]): Node {
  if (tokens.length === 0) fail('INVALID_EXPRESSION', 'Nothing to calculate');
  const p = new Parser(tokens);
  const node = p.additive();
  // Leftovers mean two operands in a row, e.g. `2(3)` or `2 3` (no implicit multiplication).
  if (p.peek()) fail('INVALID_EXPRESSION', 'Unexpected symbol');
  return node;
}