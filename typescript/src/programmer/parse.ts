import { fail } from '../shared/errors';
import { INT64_MAX, RADIX, TWO_63, TWO_64, toInt64, type BaseName } from './int64';

const PREFIX: Record<string, BaseName> = { b: 'bin', o: 'oct', d: 'dec', x: 'hex' };

/**
 * Parse one integer literal (spec §4.3). Order: prefix, digit validation, range.
 * Nothing goes through `number`, and the BigInt accumulates digit by digit.
 */
export function parseLiteral(raw: string, inputBase: BaseName): bigint {
  const original = raw.trim();
  let s = original;
  let negative = false;
  if (s.startsWith('-')) { negative = true; s = s.slice(1); }

  // A prefix counts only when digits follow it (R30): `0B` in hex mode is the
  // number 11, but `0B1` is binary 1 (R11, case P32).
  let base = inputBase;
  const prefixed = /^0([bodxBODX])(.+)$/.exec(s);
  if (prefixed) {
    base = PREFIX[prefixed[1].toLowerCase()];
    s = prefixed[2];
  }

  if (s === '' || !/^[0-9A-Za-z]+$/.test(s)) fail('INVALID_NUMBER', `'${original}' is not a number`);

  const radix = RADIX[base];
  for (const ch of s) {
    if (parseInt(ch, 36) >= radix) fail('INVALID_DIGIT', `'${ch.toUpperCase()}' is not a ${base} digit`);
  }

  const R = BigInt(radix);
  let magnitude = 0n;
  for (const ch of s) magnitude = magnitude * R + BigInt(parseInt(ch, 36));

  // Decimal, or anything with a minus sign: a plain signed value that must fit.
  if (base === 'dec' || negative) {
    if (magnitude > (negative ? TWO_63 : INT64_MAX)) fail('OUT_OF_RANGE', 'That number does not fit in 64 bits');
    return negative ? -magnitude : magnitude;
  }

  // bin/oct/hex without a minus: a raw bit pattern of up to 64 bits, read as signed.
  if (magnitude >= TWO_64) fail('OUT_OF_RANGE', 'That number needs more than 64 bits');
  return toInt64(magnitude);
}