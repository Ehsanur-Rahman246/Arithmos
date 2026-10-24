package arithmos.shared;

import arithmos.shared.ArithmosError.Code;
import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;

/**
 * Number formatting, spec §2.3. Used by the Standard Calculator and the Converter.
 *
 * <p>How half-away-from-zero is achieved: {@code new BigDecimal(double)} is the exact binary
 * value, and {@code RoundingMode.HALF_UP} on BigDecimal rounds ties away from zero.
 */
public final class FormatNumber {
    private FormatNumber() {}

    public static String format(double x) {
        if (Double.isNaN(x)) {
            throw new ArithmosError(Code.INVALID_EXPRESSION, "Result is not a number");
        }
        if (Double.isInfinite(x)) {
            throw new ArithmosError(Code.OVERFLOW, "Result is too large to represent");
        }
        if (x == 0.0) {
            return "0"; // also catches -0.0
        }

        // Rule 1: 12 significant digits, half away from zero.
        BigDecimal rounded = new BigDecimal(x).round(new MathContext(12, RoundingMode.HALF_UP));
        String digits = rounded.unscaledValue().abs().toString();
        // Decimal exponent of the leading digit: value = d.ddd × 10^exp
        int exp = digits.length() - 1 - rounded.scale();

        // Rule 2: trim trailing zeros (the value is non-zero, so a digit always remains).
        int end = digits.length();
        while (end > 1 && digits.charAt(end - 1) == '0') {
            end--;
        }
        digits = digits.substring(0, end);
        String sign = rounded.signum() < 0 ? "-" : "";

        // Rule 3: plain notation for 1e-6 <= |x| < 1e15 (judged after rounding), else scientific.
        if (exp >= -6 && exp < 15) {
            if (exp >= 0) {
                if (digits.length() <= exp + 1) {
                    return sign + digits + "0".repeat(exp + 1 - digits.length());
                }
                return sign + digits.substring(0, exp + 1) + "." + digits.substring(exp + 1);
            }
            return sign + "0." + "0".repeat(-exp - 1) + digits;
        }
        String mantissa = digits.length() > 1
                ? digits.charAt(0) + "." + digits.substring(1)
                : digits;
        return sign + mantissa + "e" + (exp < 0 ? "-" : "+") + Math.abs(exp);
    }
}
