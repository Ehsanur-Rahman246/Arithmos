// Unit tests for src/shared (number formatting, spec 2.3; error codes, spec 2.2)
// plus unit-table integrity.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatNumber, ERROR_CODES, ArithmosError } from '../src/shared/index.js';
import { CATEGORIES, SYMBOL_INDEX } from '../src/converter/index.js';

const fmt = (n) => formatNumber(n);

test('formatNumber: 12 significant digits, trailing zeros trimmed', () => {
  assert.equal(fmt(0.1 + 0.2), '0.3');
  assert.equal(fmt(1 / 3), '0.333333333333');
  assert.equal(fmt(2 / 3), '0.666666666667');
  assert.equal(fmt(2.5), '2.5');
  assert.equal(fmt(3), '3');
  assert.equal(fmt(-2.54), '-2.54');
  assert.equal(fmt(123456789.123456789), '123456789.123');
});

test('formatNumber: 1e15 and 1e-6 boundaries', () => {
  assert.equal(fmt(1e15), '1e+15');
  assert.equal(fmt(999999999999), '999999999999');          // 12 digits: plain
  assert.equal(fmt(999999999999999), '1e+15');             // rounds up to 1e15 first, then scientific
  assert.equal(fmt(123456789012345), '123456789012000');   // plain, 12 significant digits kept
  assert.equal(fmt(1e-6), '0.000001');
  assert.equal(fmt(1e-7), '1e-7');
  assert.equal(fmt(1.5e20), '1.5e+20');
  assert.equal(fmt(-2e-7), '-2e-7');
  assert.equal(fmt(1e-9), '1e-9');
});

test('formatNumber: ties round half away from zero', () => {
  assert.equal(fmt(100000000000.5), '100000000001');
  assert.equal(fmt(-100000000000.5), '-100000000001');
});

test('formatNumber: negative zero prints 0', () => {
  assert.equal(fmt(-0), '0');
  assert.equal(fmt(0), '0');
});

test('formatNumber: Infinity -> OVERFLOW, NaN never shown', () => {
  for (const bad of [Infinity, -Infinity]) {
    assert.throws(() => fmt(bad), (e) => e instanceof ArithmosError && e.code === 'OVERFLOW');
  }
  assert.throws(() => fmt(NaN), (e) => e instanceof ArithmosError);
});

test('ERROR_CODES matches spec 2.2 exactly', () => {
  assert.deepEqual([...ERROR_CODES].sort(), [
    'BELOW_ABSOLUTE_ZERO', 'DIV_BY_ZERO', 'DOMAIN_ERROR', 'INCOMPATIBLE_UNITS', 'INVALID_BASE',
    'INVALID_DIGIT', 'INVALID_EXPRESSION', 'INVALID_NUMBER', 'INVALID_SHIFT', 'OUT_OF_RANGE',
    'OVERFLOW', 'UNDEFINED', 'UNKNOWN_COMMAND', 'UNKNOWN_UNIT',
  ]);
});

test('unit tables: twelve categories, unique symbols, finite positive factors', () => {
  assert.equal(CATEGORIES.length, 12);
  const total = CATEGORIES.reduce((n, c) => n + c.units.length, 0);
  assert.equal(SYMBOL_INDEX.size, total);
  for (const c of CATEGORIES.filter((x) => !x.formula)) {
    assert.ok(c.units.some((u) => u.factor === 1), `${c.name} has a base unit with factor 1`);
    for (const u of c.units) assert.ok(Number.isFinite(u.factor) && u.factor > 0, u.symbol);
  }
});
