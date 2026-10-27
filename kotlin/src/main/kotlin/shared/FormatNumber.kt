package arithmos.shared

import java.math.BigDecimal
import java.math.MathContext
import java.math.RoundingMode
import kotlin.math.abs

/**
 * Spec §2.3: 12 significant digits, half away from zero, trailing zeros trimmed,
 * plain notation for 1e-6 <= |x| < 1e15, otherwise <mantissa>e<sign><exponent>.
 *
 * BigDecimal(double) is the EXACT binary value, and HALF_UP on a BigDecimal rounds ties
 * away from zero, so 100000000000.5 gives 100000000001 (no half-even surprise).
 */
fun formatNumber(x: Double): String {
    if (x.isNaN()) fail(Code.INVALID_EXPRESSION, "Result is not a number")
    if (x.isInfinite()) fail(Code.OVERFLOW, "Result is too large to represent")
    if (x == 0.0) return "0"                                   // also turns -0.0 into 0

    val rounded = BigDecimal(x).round(MathContext(12, RoundingMode.HALF_UP))
    val sign = if (rounded.signum() < 0) "-" else ""
    val a = rounded.abs().stripTrailingZeros()
    val digits = a.unscaledValue().toString()                  // significant digits, no trailing zeros
    val exp10 = digits.length - 1 - a.scale()                  // exponent of the leading digit

    if (exp10 in -6..14) return sign + a.toPlainString()       // plain notation range

    val mantissa = if (digits.length == 1) digits else "${digits[0]}.${digits.substring(1)}"
    return sign + mantissa + "e" + (if (exp10 < 0) "-" else "+") + abs(exp10)
}