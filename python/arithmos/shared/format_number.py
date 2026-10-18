"""Display rules (spec 2.3): 12 significant digits, half away from zero, trailing
zeros trimmed, plain notation for 1e-6 <= |x| < 1e15, else <m>e<sign><exp>."""
import math
from decimal import ROUND_HALF_UP, Decimal, localcontext

from .errors import fail


def format_number(value: float) -> str:
    if math.isnan(value):
        fail("INVALID_EXPRESSION", "Result is not a number")
    if math.isinf(value):
        fail("OVERFLOW", "Result is too large to represent")
    if value == 0:
        return "0"  # also covers -0.0

    sign = "-" if value < 0 else ""
    # Decimal(float) is the exact binary value, so ROUND_HALF_UP really is
    # "half away from zero" on the magnitude (Python's own float formatting
    # rounds exact ties to even, which the spec does not allow).
    with localcontext() as ctx:
        ctx.prec = 80
        exact = Decimal(abs(value))
        rounded = exact.quantize(Decimal(1).scaleb(exact.adjusted() - 11), rounding=ROUND_HALF_UP)
    exponent = rounded.adjusted()  # taken AFTER rounding: 999999999999999 -> 1e+15
    digits = "".join(map(str, rounded.as_tuple().digits)).rstrip("0") or "0"

    if exponent >= 15 or exponent < -6:
        mantissa = digits[0] + ("." + digits[1:] if len(digits) > 1 else "")
        return f"{sign}{mantissa}e{'-' if exponent < 0 else '+'}{abs(exponent)}"
    if exponent >= 0:
        size = exponent + 1
        whole = digits[:size].ljust(size, "0")
        frac = digits[size:]
        return f"{sign}{whole}{'.' + frac if frac else ''}"
    return f"{sign}0.{'0' * (-exponent - 1)}{digits}"