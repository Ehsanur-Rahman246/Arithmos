// Literal parsing per spec 4.2–4.3: prefixes 0b/0o/0d/0x, input base, leading '-',
// raw bit patterns for bin/oct/hex, INVALID_DIGIT / INVALID_NUMBER / OUT_OF_RANGE.
import { fail } from '../shared/index.js';
import { INT64_MIN, INT64_MAX, toInt64 } from './int64.js';

export const BASES = Object.freeze({
  bin: { radix: 2, prefix: 'b' },
  oct: { radix: 8, prefix: 'o' },
  dec: { radix: 10, prefix: 'd' },
  hex: { radix: 16, prefix: 'x' },
});
const PREFIX_TO_BASE = { b: 'bin', o: 'oct', d: 'dec', x: 'hex' };
const DIGITS = '0123456789abcdef';

export function resolveBase(name) {
  const key = String(name ?? '').toLowerCase();
  if (!Object.hasOwn(BASES, key)) fail('INVALID_BASE', `'${name}' is not a base. Use bin, oct, dec or hex`);
  return key;
}

export function parseLiteral(text, inputBase = 'dec') {
  let s = String(text).trim();
  let negative = false;
  if (s.startsWith('-')) { negative = true; s = s.slice(1); }

  // A prefix wins over the input base. It only counts as a prefix when digits
  // follow it, so a bare `0B` or `0D` in hex mode is still the hex number.
  let base = inputBase;
  const pm = /^0([bodx])(.+)$/i.exec(s);
  if (pm) { base = PREFIX_TO_BASE[pm[1].toLowerCase()]; s = pm[2]; }

  if (s === '' || /[^0-9A-Za-z]/.test(s)) fail('INVALID_NUMBER', `'${text}' is not a number`);

  const { radix, prefix } = BASES[base];
  const valid = DIGITS.slice(0, radix);
  for (const ch of s.toLowerCase()) {
    if (!valid.includes(ch)) fail('INVALID_DIGIT', `'${ch.toUpperCase()}' is not a ${base} digit`);
  }

  const magnitude = BigInt(radix === 10 ? s : `0${prefix}${s}`);

  if (negative) {
    if (magnitude > -INT64_MIN) fail('OUT_OF_RANGE', 'That number does not fit in 64 bits');
    return -magnitude;
  }
  if (radix === 10) {
    if (magnitude > INT64_MAX) fail('OUT_OF_RANGE', 'That number does not fit in 64 bits');
    return magnitude;
  }
  // bin/oct/hex: raw bit pattern, up to 64 bits, reinterpreted as signed.
  if (magnitude >= 2n ** 64n) fail('OUT_OF_RANGE', 'That number needs more than 64 bits');
  return toInt64(magnitude);
}

// Shift counts are always plain decimal integers 0–63 (spec 4.5).
export function parseShiftCount(text) {
  const s = String(text).trim();
  if (!/^\d+$/.test(s)) fail('INVALID_SHIFT', 'A shift count must be a whole number from 0 to 63');
  const n = BigInt(s);
  if (n > 63n) fail('INVALID_SHIFT', 'A shift count must be a whole number from 0 to 63');
  return n;
}
