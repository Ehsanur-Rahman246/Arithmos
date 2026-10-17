// 64-bit signed two's-complement model on top of BigInt (spec 4.1).
export const INT64_MIN = -(2n ** 63n);
export const INT64_MAX = 2n ** 63n - 1n;
export const toInt64 = (n) => BigInt.asIntN(64, n);
export const toUint64 = (n) => BigInt.asUintN(64, n);
