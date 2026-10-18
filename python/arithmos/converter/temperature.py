"""c / f / k via Celsius (spec 5.3). Anything below absolute zero is rejected."""
from arithmos.shared import fail

_ABSOLUTE_ZERO = {"c": -273.15, "f": -459.67, "k": 0.0}
_TO_C = {"c": lambda v: v, "f": lambda v: (v - 32) * 5 / 9, "k": lambda v: v - 273.15}
_FROM_C = {"c": lambda v: v, "f": lambda v: v * 9 / 5 + 32, "k": lambda v: v + 273.15}


def check_temperature(value: float, unit: str) -> None:
    if value < _ABSOLUTE_ZERO[unit]:
        fail("BELOW_ABSOLUTE_ZERO", "That is below absolute zero")


def convert_temperature(value: float, source: str, target: str) -> float:
    check_temperature(value, source)
    if source == target:
        return value
    result = _FROM_C[target](_TO_C[source](value))
    return max(result, _ABSOLUTE_ZERO[target])  # clamp float noise at the edge