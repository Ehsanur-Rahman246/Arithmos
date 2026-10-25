import { fail } from '../shared/errors';

export type Token =
  | { kind: 'num'; text: string }
  | { kind: 'op'; op: '+' | '-' | '*' | '/' | '^' }
  | { kind: 'lparen' }
  | { kind: 'rparen' }
  | { kind: 'percent' }
  | { kind: 'word'; word: 'of' | 'sqrt' | 'abs' | 'ans'; raw: string };

const WORDS = new Set(['of', 'sqrt', 'abs', 'ans']);
const isDigit = (c: string): boolean => c >= '0' && c <= '9';

/** Split an expression into tokens. Keywords are case-insensitive (spec §2.4). */
export function tokenize(src: string): Token[] {
  const tokens: Token[] = [];
  let i = 0;
  while (i < src.length) {
    const c = src[i];

    if (/\s/.test(c)) { i++; continue; }

    // Number: 12, 12.5, .5, 5.  (no exponent form: `1e5` is "1" then the word "e5")
    if (isDigit(c) || c === '.') {
      let j = i;
      while (j < src.length && isDigit(src[j])) j++;
      if (src[j] === '.') {
        j++;
        while (j < src.length && isDigit(src[j])) j++;
      }
      const text = src.slice(i, j);
      if (!/\d/.test(text)) fail('INVALID_EXPRESSION', "Unexpected character '.'");
      tokens.push({ kind: 'num', text });
      i = j;
      continue;
    }

    if (/[A-Za-z_]/.test(c)) {
      let j = i;
      while (j < src.length && /[A-Za-z0-9_]/.test(src[j])) j++;
      const raw = src.slice(i, j);
      const word = raw.toLowerCase();
      if (!WORDS.has(word)) fail('INVALID_EXPRESSION', `Unknown word '${raw}'`);
      tokens.push({ kind: 'word', word: word as 'of' | 'sqrt' | 'abs' | 'ans', raw });
      i = j;
      continue;
    }

    if ('+-*/^'.includes(c)) { tokens.push({ kind: 'op', op: c as '+' | '-' | '*' | '/' | '^' }); i++; continue; }
    if (c === '(') { tokens.push({ kind: 'lparen' }); i++; continue; }
    if (c === ')') { tokens.push({ kind: 'rparen' }); i++; continue; }
    if (c === '%') { tokens.push({ kind: 'percent' }); i++; continue; }

    fail('INVALID_EXPRESSION', `Unexpected character '${String.fromCodePoint(src.codePointAt(i)!)}'`);
  }
  return tokens;
}