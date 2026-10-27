package arithmos.shared

/** The 14 error codes of spec §2.2. Tests assert the code, never the message. */
enum class Code {
    INVALID_EXPRESSION, INVALID_NUMBER, DIV_BY_ZERO, DOMAIN_ERROR, UNDEFINED, OVERFLOW,
    INVALID_DIGIT, INVALID_BASE, OUT_OF_RANGE, INVALID_SHIFT, UNKNOWN_UNIT,
    INCOMPATIBLE_UNITS, BELOW_ABSOLUTE_ZERO, UNKNOWN_COMMAND
}

/** Engines throw this; only the cli layer turns it into "Error [CODE]: message". */
class ArithmosError(val code: Code, message: String) : Exception(message)

/** Shorthand: throw an ArithmosError (return type Nothing lets it be used in expressions). */
fun fail(code: Code, message: String): Nothing = throw ArithmosError(code, message)