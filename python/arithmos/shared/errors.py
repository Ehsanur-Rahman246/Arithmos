"""Error codes (spec 2.2). Tests check the CODE, never the message text."""

ERROR_CODES = (
    "INVALID_EXPRESSION", "INVALID_NUMBER", "DIV_BY_ZERO", "DOMAIN_ERROR", "UNDEFINED",
    "OVERFLOW", "INVALID_DIGIT", "INVALID_BASE", "OUT_OF_RANGE", "INVALID_SHIFT",
    "UNKNOWN_UNIT", "INCOMPATIBLE_UNITS", "BELOW_ABSOLUTE_ZERO", "UNKNOWN_COMMAND",
)


class ArithmosError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def fail(code: str, message: str):
    raise ArithmosError(code, message)


def format_error(err: ArithmosError) -> str:
    return f"Error [{err.code}]: {err.message}"