// Spec 2.3: 12 significant digits, half away from zero, trailing zeros trimmed,
// plain notation for 1e-6 <= |x| < 1e15, otherwise <mantissa>e<sign><exp>.
//
// Dart's own double formatting is not used. The exact decimal expansion of the
// double is built with BigInt, then rounded by hand, so exact ties round up
// (100000000000.5 -> 100000000001).
import 'dart:typed_data';

import 'errors.dart';

String formatNumber(double x) {
  if (x.isNaN) {
    throw const ArithmosError('INVALID_EXPRESSION', 'Result is not a number');
  }
  if (x.isInfinite) {
    throw const ArithmosError('OVERFLOW', 'Result is too large to represent');
  }
  if (x == 0) return '0'; // also catches -0.0
  final neg = x < 0;

  // Split |x| into mantissa * 2^exp2 (sign bit is 0, so getUint64 is safe).
  final bd = ByteData(8)..setFloat64(0, x.abs());
  final bits = bd.getUint64(0);
  final expBits = (bits >> 52) & 0x7FF;
  final frac = bits & 0xFFFFFFFFFFFFF;
  final BigInt mant;
  final int exp2;
  if (expBits == 0) {
    mant = BigInt.from(frac); // subnormal
    exp2 = -1074;
  } else {
    mant = BigInt.from(frac | (1 << 52));
    exp2 = expBits - 1075;
  }

  // Exact value = d * 10^-scale.
  final BigInt d;
  final int scale;
  if (exp2 >= 0) {
    d = mant << exp2;
    scale = 0;
  } else {
    // m / 2^k = m * 5^k / 10^k
    d = mant * BigInt.from(5).pow(-exp2);
    scale = -exp2;
  }

  final ds = d.toString();
  var e10 = ds.length - 1 - scale; // decimal exponent of the first digit
  const sig = 12;
  String digits;
  if (ds.length <= sig) {
    digits = ds.padRight(sig, '0');
  } else {
    var head = BigInt.parse(ds.substring(0, sig));
    // The value is exact, so "13th digit >= 5" means at or above the half way
    // point: round up (half away from zero).
    if (ds.codeUnitAt(sig) >= 0x35) head += BigInt.one;
    var hs = head.toString();
    if (hs.length > sig) {
      hs = hs.substring(0, sig); // 999999999999 + 1 -> 1000000000000
      e10 += 1;
    }
    digits = hs;
  }

  var t = digits.replaceFirst(RegExp(r'0+$'), '');
  if (t.isEmpty) t = '0';

  String body;
  if (e10 >= -6 && e10 < 15) {
    if (e10 >= 0) {
      final intLen = e10 + 1;
      final ip = t.length >= intLen ? t.substring(0, intLen) : t.padRight(intLen, '0');
      final fp = t.length > intLen ? t.substring(intLen) : '';
      body = fp.isEmpty ? ip : '$ip.$fp';
    } else {
      body = '0.${'0' * (-e10 - 1)}$t';
    }
  } else {
    final m = t.length > 1 ? '${t[0]}.${t.substring(1)}' : t;
    body = '${m}e${e10 < 0 ? '-' : '+'}${e10.abs()}';
  }
  return neg ? '-$body' : body;
}