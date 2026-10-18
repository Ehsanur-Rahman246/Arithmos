"""Output (spec 4.4): HEX (uppercase), DEC (signed), OCT, BIN. Negative values show
the full 64-bit pattern in HEX/OCT/BIN. No grouping, no padding."""
from .int64 import to_uint64

_FORMATS = {"bin": "b", "oct": "o", "dec": "d", "hex": "X"}


def format_in_base(value: int, base: str) -> str:
    if base == "dec":
        return str(value)
    return format(to_uint64(value) if value < 0 else value, _FORMATS[base])


def format_all_bases(value: int) -> dict:
    return {
        "HEX": format_in_base(value, "hex"),
        "DEC": format_in_base(value, "dec"),
        "OCT": format_in_base(value, "oct"),
        "BIN": format_in_base(value, "bin"),
    }