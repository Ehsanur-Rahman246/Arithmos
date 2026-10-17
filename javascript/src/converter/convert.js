// value -> base -> target using the exact factors/ratios from the spec.
// Also implements `convert <value> <from> all` and `list [category]`.
import { fail } from '../shared/index.js';
import { CATEGORIES, SYMBOL_INDEX } from './units.js';
import { convertTemperature, checkTemperature } from './temperature.js';

function lookup(symbol) {
  const hit = SYMBOL_INDEX.get(String(symbol).toLowerCase());
  if (!hit) fail('UNKNOWN_UNIT', `Unknown unit '${symbol}'`);
  return hit;
}

function convertResolved(value, from, to) {
  if (from.category.formula) return convertTemperature(value, from.unit.symbol, to.unit.symbol);
  return (value * from.unit.factor) / to.unit.factor;
}

export function convert(value, from, to) {
  const a = lookup(from);
  const b = lookup(to);
  if (a.category !== b.category) fail('INCOMPATIBLE_UNITS', `${a.category.name} and ${b.category.name} cannot be converted`);
  return convertResolved(value, a, b);
}

// Every unit of the source's category, in table order, source unit included.
export function convertAll(value, from) {
  const a = lookup(from);
  if (a.category.formula) checkTemperature(value, a.unit.symbol);
  return a.category.units.map((unit) => ({
    symbol: unit.symbol,
    value: convertResolved(value, a, { category: a.category, unit }),
  }));
}

export function listCategories() {
  return CATEGORIES.map((c) => c.name);
}

export function listUnits(category) {
  const found = CATEGORIES.find((c) => c.name === String(category).toLowerCase());
  if (!found) fail('UNKNOWN_COMMAND', `Unknown category '${category}'`);
  return found.units.map((u) => u.symbol);
}
