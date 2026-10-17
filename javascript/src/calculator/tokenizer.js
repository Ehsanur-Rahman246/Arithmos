// Turns an expression string into tokens: num, op, lparen, rparen, percent,
// ident (sqrt, abs, ans, of). Unknown characters -> INVALID_EXPRESSION.
import { fail } from '../shared/index.js';

const NUMBER_RE = /^(?:\d+\.?\d*|\.\d+)/;
const IDENT_RE = /^[A-Za-z][A-Za-z0-9_]*/;
const KEYWORDS = new Set(['sqrt', 'abs', 'ans', 'of']);

export function tokenize(input) {
  const s = String(input);
  const tokens = [];
  let i = 0;
  while (i < s.length) {
    const ch = s[i];
    if (/\s/.test(ch)) { i++; continue; }
    const rest = s.slice(i);
    let m = NUMBER_RE.exec(rest);
    if (m) {
      tokens.push({ type: 'num', value: Number(m[0]) });
      i += m[0].length;
      continue;
    }
    m = IDENT_RE.exec(rest);
    if (m) {
      const word = m[0].toLowerCase();
      if (!KEYWORDS.has(word)) fail('INVALID_EXPRESSION', `Unknown token '${m[0]}'`);
      tokens.push({ type: 'ident', value: word });
      i += m[0].length;
      continue;
    }
    if ('+-*/^'.includes(ch)) tokens.push({ type: 'op', value: ch });
    else if (ch === '(') tokens.push({ type: 'lparen' });
    else if (ch === ')') tokens.push({ type: 'rparen' });
    else if (ch === '%') tokens.push({ type: 'percent' });
    else fail('INVALID_EXPRESSION', `Unexpected character '${ch}'`);
    i++;
  }
  return tokens;
}
