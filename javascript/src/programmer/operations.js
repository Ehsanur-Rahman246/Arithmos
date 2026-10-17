// AND, OR, XOR, NOT, <<, >>, >>> on int64 (spec 4.5). `n` for shifts is a BigInt
// already validated to 0–63. << discards overflow bits silently.
import { toInt64, toUint64 } from './int64.js';

export const operations = Object.freeze({
  and: (a, b) => toInt64(a & b),
  or: (a, b) => toInt64(a | b),
  xor: (a, b) => toInt64(a ^ b),
  not: (a) => toInt64(~a),
  shl: (a, n) => toInt64(a << n),
  sar: (a, n) => toInt64(a >> n),                 // arithmetic: sign-extending
  shr: (a, n) => toInt64(toUint64(a) >> n),       // logical: zero-filling
});
