import { fail } from '../shared/errors';
import {
  formatAll, formatInBase, isBaseName, parseBaseName, toInt64, toUint64,
  type BaseName, type Display,
} from './int64';
import { parseLiteral } from './parse';

export { formatAll, formatInBase, parseLiteral };
export type { BaseName, Display };

/** What one Programmer command produced. The CLI decides how to print it. */
export type ProgrammerResult =
  | { kind: 'value'; value: bigint; display: Display } // shown in all four bases
  | { kind: 'converted'; text: string }                 // `convert` / `255 dec hex`
  | { kind: 'base'; base: BaseName };                   // `base hex`

const BITWISE = new Set(['and', 'or', 'xor']);
const SHIFTS = new Set(['<<', '>>', '>>>']);

const asValue = (value: bigint): ProgrammerResult => ({ kind: 'value', value, display: formatAll(value) });

/** The shift count is always a plain decimal 0..63 (R13: `0x3` and `2.5` are INVALID_SHIFT). */
function parseShiftCount(word: string): bigint {
  const bad = (): never => fail('INVALID_SHIFT', 'A shift count must be a whole number from 0 to 63');
  if (!/^\d+$/.test(word)) bad();
  const n = BigInt(word);
  if (n > 63n) bad();
  return n;
}

/** A Programmer Calculator session. Holds the input base. */
export class Programmer {
  base: BaseName = 'dec';

  execute(line: string): ProgrammerResult {
    // Spaces are optional around shift operators (R29): `1<<3`.
    const words = line.replace(/(>>>|>>|<<)/g, ' $1 ').trim().split(/\s+/).filter(Boolean);
    if (words.length === 0) fail('UNKNOWN_COMMAND', 'Type a number or a command. Try help');

    const first = words[0].toLowerCase();

    if (first === 'base') {
      if (words.length !== 2) fail('INVALID_BASE', 'Use: base bin | oct | dec | hex');
      this.base = parseBaseName(words[1]);
      return { kind: 'base', base: this.base };
    }

    if (first === 'convert') {
      if (words.length !== 4) fail('UNKNOWN_COMMAND', 'Use: convert <value> <from> <to>');
      return this.convert(words[1], words[2], words[3]);
    }

    if (first === 'not') {
      if (words.length !== 2) fail('UNKNOWN_COMMAND', 'Use: NOT <value>');
      return asValue(toInt64(~parseLiteral(words[1], this.base)));
    }

    if (words.length === 1) return asValue(parseLiteral(words[0], this.base));

    if (words.length === 3) {
      // The operator is always the MIDDLE word, so hex words such as FACE/BEEF/DEC
      // stay numbers (R11).
      const op = words[1].toLowerCase();
      if (BITWISE.has(op)) {
        const a = parseLiteral(words[0], this.base);
        const b = parseLiteral(words[2], this.base);
        return asValue(toInt64(op === 'and' ? a & b : op === 'or' ? a | b : a ^ b));
      }
      if (SHIFTS.has(op)) {
        const a = parseLiteral(words[0], this.base);
        const n = parseShiftCount(words[2]);
        if (op === '<<') return asValue(toInt64(a << n));       // bits past 63 are dropped
        if (op === '>>') return asValue(a >> n);                // arithmetic, sign-extending
        return asValue(toInt64(toUint64(a) >> n));              // logical, zero-filling
      }
      // `255 dec hex`: the word "convert" is optional (R24).
      if (isBaseName(words[1]) && isBaseName(words[2])) return this.convert(words[0], words[1], words[2]);
    }

    fail('UNKNOWN_COMMAND', 'Not a command. Try help');
  }

  /** The `from` base reads the value, independent of the current input base. */
  private convert(value: string, from: string, to: string): ProgrammerResult {
    const fromBase = parseBaseName(from);
    const toBase = parseBaseName(to);
    return { kind: 'converted', text: formatInBase(parseLiteral(value, fromBase), toBase) };
  }
}