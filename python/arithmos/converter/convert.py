"""value -> base -> target using the spec's exact factors; `all` and `list` helpers."""
from arithmos.shared import fail

from .temperature import check_temperature, convert_temperature
from .units import CATEGORIES, SYMBOL_INDEX


def _lookup(symbol: str):
    hit = SYMBOL_INDEX.get(str(symbol).lower())
    if hit is None:
        fail("UNKNOWN_UNIT", f"'{symbol}' is not a known unit. Try: list")
    return hit


def _convert(value, src, dst):
    if src[0].formula:
        return convert_temperature(value, src[1].symbol, dst[1].symbol)
    return value * src[1].factor / dst[1].factor


def convert(value: float, source: str, target: str) -> float:
    src, dst = _lookup(source), _lookup(target)
    if src[0] is not dst[0]:
        fail("INCOMPATIBLE_UNITS", f"Cannot convert {src[0].name} to {dst[0].name}")
    return _convert(value, src, dst)


def convert_all(value: float, source: str) -> list:
    """The value in every unit of the source's category (table order, source included)."""
    src = _lookup(source)
    if src[0].formula:
        check_temperature(value, src[1].symbol)
    return [(u.symbol, _convert(value, src, (src[0], u))) for u in src[0].units]


def list_categories() -> list:
    return [c.name for c in CATEGORIES]


def list_units(category: str) -> list:
    for c in CATEGORIES:
        if c.name == str(category).lower():
            return [u.symbol for u in c.units]
    return fail("UNKNOWN_COMMAND", f"'{category}' is not a category. Try: list")