package arithmos.programmer;

import arithmos.shared.ArithmosError;
import arithmos.shared.ArithmosError.Code;
import java.math.BigInteger;

/**
 * Literal parsing, in the order of ARCHITECTURE.md:
 * prefix (overrides the input base) → digit validation (INVALID_DIGIT) → range (OUT_OF_RANGE).
 * Bin/oct/hex without a minus are raw bit patterns reinterpreted as signed.
 */


public class Literal {
    private static final BigInteger TWO_63 = BigInteger.ONE.shiftLeft(63);

    private Literal() {}

    static long parse(String text, Base inputBase) {
        String s = text;
        boolean negative = false;
        if (s.startsWith("-")) { // a leading minus is allowed in any base, also with a prefix
            negative = true;
            s = s.substring(1);
        }

        // R30: a prefix counts only when something follows it. "0B" in hex mode is the number 11,
        // "0B1" is binary 1, and a bare "0x" in dec mode is INVALID_DIGIT.
        Base base = inputBase;
        if (s.length() > 2 && s.charAt(0) == '0') {
            Base prefixed = Base.fromPrefixChar(s.charAt(1));
            if (prefixed != null) {
                base = prefixed;
                s = s.substring(2);
            }
        }

        // Empty or non-alphanumeric garbage: INVALID_NUMBER.
        if (s.isEmpty()) {
            throw new ArithmosError(Code.INVALID_NUMBER, "'" + text + "' is not a number");
        }
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            boolean alnum = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
            if (!alnum) {
                throw new ArithmosError(Code.INVALID_NUMBER, "'" + text + "' is not a number");
            }
        }

        // Digit validation for the base in force.
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            int d = Character.digit(c, 36); // 0-9, then a/A = 10 … z/Z = 35
            if (d >= base.radix) {
                throw new ArithmosError(Code.INVALID_DIGIT,
                        "'" + Character.toUpperCase(c) + "' is not a " + base.id + " digit");
            }
        }

        // Range.
        BigInteger magnitude = new BigInteger(s, base.radix);
        if (negative) { // magnitude must not exceed 2^63
            if (magnitude.compareTo(TWO_63) > 0) {
                throw new ArithmosError(Code.OUT_OF_RANGE, "That number does not fit in 64 bits");
            }
            return magnitude.negate().longValue();
        }
        if (base == Base.DEC) { // decimal must fit the signed range
            if (magnitude.compareTo(TWO_63) >= 0) {
                throw new ArithmosError(Code.OUT_OF_RANGE, "That number does not fit in 64 bits");
            }
            return magnitude.longValue();
        }
        if (magnitude.bitLength() > 64) { // bit pattern wider than 64 bits
            throw new ArithmosError(Code.OUT_OF_RANGE, "That number needs more than 64 bits");
        }
        return magnitude.longValue(); // low 64 bits, read as signed: 0xFFFFFFFFFFFFFFFF → -1
    }
}
