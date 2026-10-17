// Spec Section 2.3 — display rules shared by the Standard Calculator and Converter.
//   1. round to 12 significant digits, half away from zero
//   2. trim trailing zeros / trailing point
//   3. plain notation for 1e-6 <= |x| < 1e15, otherwise <mantissa>e<sign><exponent>
//   4. negative zero -> "0"
//   5. +/-Infinity -> OVERFLOW; NaN must never reach here
import { fail } from './errors.js';

export function formatNumber(value) {
  if (Number.isNaN(value)) fail('INVALID_EXPRESSION', 'Result is not a number');
  if (!Number.isFinite(value)) fail('OVERFLOW', 'Result is too large to represent');
  if (value === 0) return '0';

  // toExponential(11) -> 12 significant digits, rounded on the exact binary
  // value (ties go away from zero because we work on the magnitude).
  const [mantissa, expText] = Math.abs(value).toExponential(11).split('e');
  const exponent = parseInt(expText, 10);
  const digits = mantissa.replace('.', '').replace(/0+$/, '') || '0';
  const sign = value < 0 ? '-' : '';

  // The threshold test uses the *rounded* exponent, so 999999999999999.9
  // (which rounds up to 1e15) is shown in scientific notation.
  if (exponent >= 15 || exponent < -6) {
    const m = digits.length > 1 ? `${digits[0]}.${digits.slice(1)}` : digits;
    return `${sign}${m}e${exponent < 0 ? '-' : '+'}${Math.abs(exponent)}`;
  }
  if (exponent >= 0) {
    const intLen = exponent + 1;
    const intPart = digits.length > intLen ? digits.slice(0, intLen) : digits.padEnd(intLen, '0');
    const frac = digits.length > intLen ? digits.slice(intLen) : '';
    return `${sign}${intPart}${frac ? `.${frac}` : ''}`;
  }
  return `${sign}0.${'0'.repeat(-exponent - 1)}${digits}`;
}
