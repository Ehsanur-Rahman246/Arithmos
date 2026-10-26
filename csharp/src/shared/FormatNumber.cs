using System.Globalization;
using System.Numerics;

namespace Arithmos.Shared;

/// <summary>
/// Spec §2.3 display rules, one implementation for Standard Calculator and Converter:
/// 12 significant digits, half away from zero, trailing zeros trimmed, "-0" -> "0",
/// plain notation for 1e-6 <= |x| < 1e15, otherwise "<mantissa>e<sign><exponent>".
///
/// .NET's own double formatting is not used. Instead the EXACT decimal expansion of the
/// double is built with BigInteger (value = mantissa * 2^e, and for e < 0 that equals
/// mantissa * 5^-e / 10^-e), then rounded half-up by hand on the digit string.
/// </summary>
public static class FormatNumber
{
    public static string Format(double value)
    {
        // NaN and Infinity never reach the user (spec §2.3 rule 5).
        if (double.IsNaN(value)) throw new ArithmosError("INVALID_EXPRESSION", "Result is not a number");
        if (double.IsInfinity(value)) throw new ArithmosError("OVERFLOW", "Result is too large to represent");
        if (value == 0) return "0"; // also covers negative zero

        bool negative = value < 0;

        // Split the IEEE-754 bits into mantissa * 2^exp2.
        long bits = BitConverter.DoubleToInt64Bits(Math.Abs(value));
        int biased = (int)((bits >> 52) & 0x7FF);
        long fraction = bits & 0xFFFFFFFFFFFFFL; // low 52 bits
        BigInteger mantissa;
        int exp2;
        if (biased == 0) { mantissa = fraction; exp2 = -1074; }                // subnormal
        else { mantissa = fraction | (1L << 52); exp2 = biased - 1075; }       // normal

        // Exact digits: "digits" read as an integer, with "fractionDigits" of them after the point.
        string digits;
        int fractionDigits;
        if (exp2 >= 0)
        {
            digits = (mantissa << exp2).ToString(CultureInfo.InvariantCulture);
            fractionDigits = 0;
        }
        else
        {
            digits = (mantissa * BigInteger.Pow(5, -exp2)).ToString(CultureInfo.InvariantCulture);
            fractionDigits = -exp2;
        }

        // Decimal exponent of the first digit (value = d.ddd × 10^sciExp).
        int sciExp = digits.Length - 1 - fractionDigits;

        // Round to 12 significant digits, half away from zero (= half up on the magnitude).
        string sig;
        if (digits.Length > 12)
        {
            bool roundUp = digits[12] >= '5';
            ulong head = ulong.Parse(digits.AsSpan(0, 12), NumberStyles.None, CultureInfo.InvariantCulture);
            if (roundUp) head++;
            if (head == 1_000_000_000_000UL) { head = 100_000_000_000UL; sciExp++; } // 9.99..95 -> 10.0
            sig = head.ToString(CultureInfo.InvariantCulture);
        }
        else
        {
            sig = digits.PadRight(12, '0');
        }

        string mant = sig.TrimEnd('0'); // never empty: the first digit is non-zero
        string body;

        if (sciExp >= -6 && sciExp < 15)
        {
            // Plain decimal notation.
            if (sciExp >= 0)
            {
                int intLen = sciExp + 1;
                string intPart = mant.Length > intLen ? mant[..intLen] : mant.PadRight(intLen, '0');
                string frac = mant.Length > intLen ? mant[intLen..] : "";
                body = frac.Length > 0 ? intPart + "." + frac : intPart;
            }
            else
            {
                body = "0." + new string('0', -sciExp - 1) + mant;
            }
        }
        else
        {
            // Scientific notation: 1.5e+20, 2e-7.
            string m = mant.Length > 1 ? mant[..1] + "." + mant[1..] : mant;
            body = m + "e" + (sciExp < 0 ? "-" : "+") + Math.Abs(sciExp).ToString(CultureInfo.InvariantCulture);
        }

        return negative ? "-" + body : body;
    }
}