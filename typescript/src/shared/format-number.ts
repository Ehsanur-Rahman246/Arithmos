import { fail } from './errors';

/**
 * Spec §2.3, used by the Standard Calculator and the Converter:
 *  1. 12 significant digits, half away from zero
 *  2. trailing zeros and a trailing '.' removed
 *  3. plain notation for 1e-6 <= |x| < 1e15, else <mantissa>e<sign><exponent>
 *  4. -0 shows as 0
 *  5. Infinity is OVERFLOW; NaN never reaches the user
 *
 * Rounding: toExponential(11) rounds exact ties to the larger magnitude. We
 * format Math.abs(x), so that is "half away from zero".
 */
export function formatNumber(x: number): string {
  if (Number.isNaN(x)) fail('INVALID_EXPRESSION', 'Result is not a number');
  if (!Number.isFinite(x)) fail('OVERFLOW', 'Result is too large to represent');
  if (x === 0) return '0'; // also covers -0

  const m = /^(\d)(?:\.(\d+))?e([+-]\d+)$/.exec(Math.abs(x).toExponential(11));
  if (!m) fail('INVALID_EXPRESSION', 'Result is not a number');

  // Significant digits with trailing zeros trimmed, and the decimal exponent.
  // The exponent is read AFTER rounding, so 999999999999.9999 becomes 1e+12.
  const digits = (m[1] + (m[2] ?? '')).replace(/0+$/, '') || '0';
  const exp = parseInt(m[3], 10);
  const sign = x < 0 ? '-' : '';

  if (exp >= -6 && exp < 15) {
    if (exp >= 0) {
      // Pad with zeros, or insert the decimal point inside the digit string.
      if (digits.length <= exp + 1) return sign + digits + '0'.repeat(exp + 1 - digits.length);
      return sign + digits.slice(0, exp + 1) + '.' + digits.slice(exp + 1);
    }
    return sign + '0.' + '0'.repeat(-exp - 1) + digits;
  }

  const mantissa = digits[0] + (digits.length > 1 ? '.' + digits.slice(1) : '');
  return `${sign}${mantissa}e${exp < 0 ? '-' : '+'}${Math.abs(exp)}`;
}