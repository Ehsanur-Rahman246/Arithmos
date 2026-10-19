// Command layer for the converter (no I/O): parses a line, returns text.
//   convert <value> <from> <to> | <value> <from> <to> | ... <from> all | list [category]
import { fail, formatNumber } from '../shared/index.js';
import { convert, convertAll, listCategories, listUnits } from './convert.js';

const VALUE_RE = /^[+-]?(?:\d+\.?\d*|\.\d+)$/;

function parseValue(text) {
  if (!VALUE_RE.test(text)) fail('INVALID_NUMBER', `'${text}' is not a number`);
  const n = Number(text);
  if (!Number.isFinite(n)) fail('OVERFLOW', 'That number is too large');
  return n;
}

export function createConverterSession() {
  function run(line) {
    const parts = String(line).trim().split(/\s+/).filter(Boolean);
    if (parts.length === 0) fail('UNKNOWN_COMMAND', 'Type a value, e.g. 100');
    const head = parts[0].toLowerCase();

    if (head === 'list') {
      if (parts.length === 1) return listCategories().join(', ');
      if (parts.length === 2) return listUnits(parts[1]).join(', ');
      return fail('UNKNOWN_COMMAND', 'Use: list  or  list <category>');
    }

    let args;
    if (head === 'convert') {
      if (parts.length !== 4) fail('UNKNOWN_COMMAND', 'Use: convert <value> <from> <to>');
      args = parts.slice(1);
    } else {
      if (parts.length !== 3) fail('UNKNOWN_COMMAND', 'Not a command. Try: convert 100 cm in');
      args = parts;
    }
    const [valueText, from, to] = args;
    const value = parseValue(valueText);

    if (to.toLowerCase() === 'all') {
      // Format everything first: any overflow fails the whole command.
      return convertAll(value, from).map((r) => `${r.symbol}: ${formatNumber(r.value)}`).join('\n');
    }
    return formatNumber(convert(value, from, to));
  }
  return { run };
}
