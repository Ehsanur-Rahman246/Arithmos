package arithmos.shared;

/**
 * The one exception every engine throws. It carries a spec §2.2 code.
 * Tests assert the code, never the message.
 */
public final class ArithmosError extends RuntimeException {
    private static final long serialVersionUID = 1L;

    /** The 14 error codes of spec §2.2. */
    public enum Code {
        INVALID_EXPRESSION, INVALID_NUMBER, DIV_BY_ZERO, DOMAIN_ERROR, UNDEFINED, OVERFLOW,
        INVALID_DIGIT, INVALID_BASE, OUT_OF_RANGE, INVALID_SHIFT, UNKNOWN_UNIT,
        INCOMPATIBLE_UNITS, BELOW_ABSOLUTE_ZERO, UNKNOWN_COMMAND
    }

    private final Code code;

    public ArithmosError(Code code, String message) {
        // No stack trace: this is ordinary control flow for bad input, not a bug.
        super(message, null, false, false);
        this.code = code;
    }

    public Code code() {
        return code;
    }
}