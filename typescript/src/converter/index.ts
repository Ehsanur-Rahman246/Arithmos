import { fail } from '../shared/errors';
import { formatNumber } from '../shared/format-number';
import { CATEGORIES, type Category, type Unit } from './units';

export { CATEGORIES };
export type { Category, Unit };

interface Entry { unit: Unit; category: Category }

// Symbols are unique across all categories, so the category is inferred from them.
const BY_SYMBOL = new Map<string, Entry>();
for (const category of CATEGORIES) {
  for (const unit of category.units) BY_SYMBOL.set(unit.symbol, { unit, category });
}

/** Symbols are case-insensitive. */
export function findUnit(input: string): Entry {
  const entry = BY_SYMBOL.get(input.toLowerCase());
  if (!entry) fail('UNKNOWN_UNIT', `'${input}' is not a known unit. Try: list`);
  return entry;
}

/** A plain decimal only: `1e3` and `1,000` are INVALID_NUMBER (R16). */
export function parseValue(text: string): number {
  if (!/^[+-]?(\d+\.?\d*|\.\d+)$/.test(text)) fail('INVALID_NUMBER', `'${text}' is not a number`);
  const n = Number(text);
  if (!Number.isFinite(n)) fail('OVERFLOW', 'That number is too large');
  return n;
}

// ---- temperature: formulas via °C, input checked against absolute zero ----

const toCelsius = (v: number, sym: string): number =>
  sym === 'c' ? v : sym === 'f' ? ((v - 32) * 5) / 9 : v - 273.15;
const fromCelsius = (c: number, sym: string): number =>
  sym === 'c' ? c : sym === 'f' ? (c * 9) / 5 + 32 : c + 273.15;

/** Exactly at the limit (0 K, -273.15 C, -459.67 F) is allowed (R20). */
function checkAbsoluteZero(v: number, sym: string): void {
  const limit = sym === 'c' ? -273.15 : sym === 'f' ? -459.67 : 0;
  if (v < limit) fail('BELOW_ABSOLUTE_ZERO', 'That is below absolute zero');
}

function convertNumber(v: number, from: Entry, to: Entry): number {
  let r: number;
  if (from.category.temperature) {
    checkAbsoluteZero(v, from.unit.symbol);
    r = fromCelsius(toCelsius(v, from.unit.symbol), to.unit.symbol);
  } else {
    r = (v * from.unit.factor) / to.unit.factor; // value × from ÷ to
  }
  if (!Number.isFinite(r)) fail('OVERFLOW', 'Result is too large to represent');
  return r;
}

function requireSameCategory(from: Entry, to: Entry): void {
  if (from.category !== to.category) {
    fail('INCOMPATIBLE_UNITS', `Cannot convert ${from.category.name} to ${to.category.name}`);
  }
}

/** `convert <value> <from> <to>` → the formatted number. */
export function convertValue(valueText: string, fromSymbol: string, toSymbol: string): string {
  const from = findUnit(fromSymbol);
  const to = findUnit(toSymbol);
  const v = parseValue(valueText);
  requireSameCategory(from, to);
  return formatNumber(convertNumber(v, from, to));
}

/**
 * `convert <value> <from> all` → `symbol: value` per unit, table order, source
 * included (R18). Everything is computed first, so an error prints no partial lines.
 */
export function convertAll(valueText: string, fromSymbol: string): string[] {
  const from = findUnit(fromSymbol);
  const v = parseValue(valueText);
  return from.category.units.map(
    (unit) => `${unit.symbol}: ${formatNumber(convertNumber(v, from, { unit, category: from.category }))}`,
  );
}

export function listCategories(): string {
  return CATEGORIES.map((c) => c.name).join(', ');
}

export function listUnits(categoryName: string): string {
  const category = CATEGORIES.find((c) => c.name === categoryName.toLowerCase());
  if (!category) fail('UNKNOWN_COMMAND', `'${categoryName}' is not a category. Try: list`);
  return category.units.map((x) => x.symbol).join(', ');
}

/** One-line command: `convert …`, `<value> <from> <to|all>`, `list`, `list <category>`. */
export function convertLine(line: string): string[] {
  const words = line.trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) fail('UNKNOWN_COMMAND', 'Type a value, e.g. 100');
  const first = words[0].toLowerCase();

  if (first === 'list') {
    if (words.length === 1) return [listCategories()];
    if (words.length === 2) return [listUnits(words[1])];
    fail('UNKNOWN_COMMAND', 'Use: list  or  list <category>');
  }

  let args = words;
  if (first === 'convert') {
    args = words.slice(1);
    if (args.length !== 3) fail('UNKNOWN_COMMAND', 'Use: convert <value> <from> <to>');
  } else if (words.length !== 3) {
    fail('UNKNOWN_COMMAND', 'Not a command. Try: convert 100 cm in');
  }

  const [value, from, to] = args;
  return to.toLowerCase() === 'all' ? convertAll(value, from) : [convertValue(value, from, to)];
}