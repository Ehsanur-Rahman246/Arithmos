import { fail } from '../shared/errors';

// Every value is a signed 64-bit two's-complement integer held in a BigInt.
export const INT64_MAX = (1n << 63n) - 1n;
export const TWO_63 = 1n << 63n;
export const TWO_64 = 1n << 64n;

/** Wrap to the signed 64-bit range. */
export const toInt64 = (v: bigint): bigint => BigInt.asIntN(64, v);
/** The unsigned 64-bit bit pattern of v (what HEX/OCT/BIN show). */
export const toUint64 = (v: bigint): bigint => BigInt.asUintN(64, v);

export type BaseName = 'bin' | 'oct' | 'dec' | 'hex';
export const RADIX: Record<BaseName, number> = { bin: 2, oct: 8, dec: 10, hex: 16 };

export function isBaseName(word: string): boolean {
  return word.toLowerCase() in RADIX;
}

/** Base names are case-insensitive; anything else is INVALID_BASE. */
export function parseBaseName(input: string): BaseName {
  const name = input.toLowerCase();
  if (!(name in RADIX)) fail('INVALID_BASE', `'${input}' is not a base. Use bin, oct, dec or hex`);
  return name as BaseName;
}

/**
 * Print v in a base. DEC is signed. HEX/OCT/BIN print the full unsigned
 * 64-bit pattern, so -1 is FFFFFFFFFFFFFFFF (spec §4.4).
 */
export function formatInBase(v: bigint, base: BaseName): string {
  if (base === 'dec') return v.toString();
  return toUint64(v).toString(RADIX[base]).toUpperCase();
}

export interface Display { HEX: string; DEC: string; OCT: string; BIN: string }

export function formatAll(v: bigint): Display {
  return {
    HEX: formatInBase(v, 'hex'),
    DEC: formatInBase(v, 'dec'),
    OCT: formatInBase(v, 'oct'),
    BIN: formatInBase(v, 'bin'),
  };
}