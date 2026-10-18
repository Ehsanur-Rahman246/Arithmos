"""AST -> float. Percent rules (spec 3.4), power and sqrt rules (spec 3.5).
Raises ArithmosError; never returns NaN or infinity."""
import math

from arithmos.shared import fail


def _guard(x: float) -> float:
    if math.isnan(x):
        fail("DOMAIN_ERROR", "The result is not a number")
    if math.isinf(x):
        fail("OVERFLOW", "The result is too large")
    return x


def _power(base: float, exp: float) -> float:
    if base == 0 and exp == 0:
        fail("UNDEFINED", "0^0 is undefined")
    if base == 0 and exp < 0:
        fail("DIV_BY_ZERO", "Zero cannot be raised to a negative power")
    if base < 0 and not float(exp).is_integer():
        fail("DOMAIN_ERROR", "A negative number cannot have a fractional power")
    try:
        return _guard(base ** exp)
    except OverflowError:
        fail("OVERFLOW", "The result is too large")


def evaluate_ast(tree, ans: float = 0.0) -> float:
    def ev(node):
        kind = node[0]
        if kind == "num":
            return _guard(node[1])
        if kind == "ans":
            return ans
        if kind == "group":
            return ev(node[1])
        if kind == "pct":
            return _guard(ev(node[1]) / 100)
        if kind == "unary":
            value = ev(node[2])
            return -value if node[1] == "-" else value
        if kind == "call":
            value = ev(node[2])
            if node[1] == "sqrt":
                if value < 0:
                    fail("DOMAIN_ERROR", "Cannot take the square root of a negative number")
                return math.sqrt(value)
            return abs(value)
        _, op, left_node, right_node = node
        left = ev(left_node)
        # A % directly after + or - is relative to the left side (spec 3.4).
        if op in "+-" and right_node[0] == "pct":
            delta = _guard(left * (ev(right_node[1]) / 100))
            return _guard(left + delta if op == "+" else left - delta)
        right = ev(right_node)
        if op == "+":
            return _guard(left + right)
        if op == "-":
            return _guard(left - right)
        if op == "*":
            return _guard(left * right)
        if op == "/":
            if right == 0:
                fail("DIV_BY_ZERO", "Cannot divide by zero")
            return _guard(left / right)
        return _power(left, right)

    return _guard(ev(tree))