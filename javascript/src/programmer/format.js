// Output per spec 4.4: HEX (uppercase), DEC (signed), OCT, BIN.
// Negative values show the full 64-bit pattern in HEX/OCT/BIN; no grouping, no padding.
import { toUint64 } from './int64.js';
import { BASES } from './parse.js';

export function formatInBase(value, base) {
  const { radix } = BASES[base];
  if (radix === 10) return value.toString();
  const pattern = value < 0n ? toUint64(value) : value;
  return pattern.toString(radix).toUpperCase();
}

export function formatAllBases(value) {
  return {
    HEX: formatInBase(value, 'hex'),
    DEC: formatInBase(value, 'dec'),
    OCT: formatInBase(value, 'oct'),
    BIN: formatInBase(value, 'bin'),
  };
}
