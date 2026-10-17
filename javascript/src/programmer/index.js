// Public API of the Programmer Calculator engine (no I/O).
//   createProgrammerSession() -> { run(line) -> result, get inputBase() }
// run() returns one of:
//   { type: 'value',   value: BigInt }
//   { type: 'convert', text: string }
//   { type: 'base',    base: string }
import { fail } from '../shared/index.js';
import { parseLiteral, parseShiftCount, resolveBase } from './parse.js';
import { operations } from './operations.js';
import { formatAllBases, formatInBase } from './format.js';

export { formatAllBases, formatInBase, parseLiteral, operations };

const BITWISE = { and: 'and', or: 'or', xor: 'xor' };
const SHIFTS = { '<<': 'shl', '>>': 'sar', '>>>': 'shr' };

export function createProgrammerSession() {
  let inputBase = 'dec';

  function run(line) {
    // Allow `1<<3` as well as `1 << 3`.
    const parts = String(line).replace(/(>>>|>>|<<)/g, ' $1 ').trim().split(/\s+/).filter(Boolean);
    if (parts.length === 0) fail('UNKNOWN_COMMAND', 'Empty command');
    const head = parts[0].toLowerCase();

    if (head === 'base') {
      if (parts.length !== 2) fail('INVALID_BASE', 'Usage: base <bin|oct|dec|hex>');
      inputBase = resolveBase(parts[1]);
      return { type: 'base', base: inputBase };
    }

    if (head === 'convert') {
      if (parts.length !== 4) fail('UNKNOWN_COMMAND', 'Usage: convert <value> <from> <to>');
      const from = resolveBase(parts[2]);
      const to = resolveBase(parts[3]);
      return { type: 'convert', text: formatInBase(parseLiteral(parts[1], from), to) };
    }

    if (head === 'not') {
      if (parts.length !== 2) fail('UNKNOWN_COMMAND', 'Usage: NOT <value>');
      return { type: 'value', value: operations.not(parseLiteral(parts[1], inputBase)) };
    }

    if (parts.length === 1) {
      return { type: 'value', value: parseLiteral(parts[0], inputBase) };
    }

    if (parts.length === 3) {
      const op = parts[1].toLowerCase();
      if (Object.hasOwn(BITWISE, op)) {
        const a = parseLiteral(parts[0], inputBase);
        const b = parseLiteral(parts[2], inputBase);
        return { type: 'value', value: operations[BITWISE[op]](a, b) };
      }
      if (Object.hasOwn(SHIFTS, op)) {
        const a = parseLiteral(parts[0], inputBase);
        const n = parseShiftCount(parts[2]);
        return { type: 'value', value: operations[SHIFTS[op]](a, n) };
      }
    }
    return fail('UNKNOWN_COMMAND', 'Unrecognized command');
  }

  return { run, get inputBase() { return inputBase; } };
}
