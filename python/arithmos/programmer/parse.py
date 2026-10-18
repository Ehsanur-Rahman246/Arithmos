"""Literal parsing (spec 4.2-4.3): prefixes 0b/0o/0d/0x, input base, leading '-',
raw bit patterns for bin/oct/hex, INVALID_DIGIT / INVALID_NUMBER / OUT_OF_RANGE."""
import re

from arithmos.shared import fail

from .int64 import INT64_MAX, INT64_MIN, to_int64

BASES = {"bin": 2, "oct": 8, "dec": 10, "hex": 16}
_PREFIX_TO_BASE = {"b": "bin", "o": "oct", "d": "dec", "x": "hex"}
_DIGITS = "0123456789abcdef"
_PREFIXED = re.compile(r"0([bodx])(.+)", re.IGNORECASE | re.DOTALL)


def resolve_base(name) -> str:
    key = str(name or "").lower()
    if key not in BASES:
        fail("INVALID_BASE", f"'{name}' is not a base. Use bin, oct, dec or hex")
    return key


def parse_literal(text: str, input_base: str = "dec") -> int:
    s = str(text).strip()
    negative = s.startswith("-")
    if negative:
        s = s[1:]

    # A prefix wins over the input base, but only when digits follow it, so a bare
    # `0B` or `0D` in hex mode is still the hex number.
    base = input_base
    m = _PREFIXED.fullmatch(s)
    if m:
        base = _PREFIX_TO_BASE[m.group(1).lower()]
        s = m.group(2)

    if s == "" or re.search(r"[^0-9A-Za-z]", s):
        fail("INVALID_NUMBER", f"'{text}' is not a number")
    radix = BASES[base]
    for ch in s.lower():
        if ch not in _DIGITS[:radix]:
            fail("INVALID_DIGIT", f"'{ch.upper()}' is not a {base} digit")
    magnitude = int(s, radix)

    if negative:
        if magnitude > -INT64_MIN:
            fail("OUT_OF_RANGE", "That number does not fit in 64 bits")
        return -magnitude
    if radix == 10:
        if magnitude > INT64_MAX:
            fail("OUT_OF_RANGE", "That number does not fit in 64 bits")
        return magnitude
    if magnitude >= 2**64:  # bin/oct/hex are raw bit patterns of up to 64 bits
        fail("OUT_OF_RANGE", "That number needs more than 64 bits")
    return to_int64(magnitude)


def parse_shift_count(text: str) -> int:
    """Shift counts are plain decimal integers 0-63 (spec 4.5)."""
    s = str(text).strip()
    if not re.fullmatch(r"[0-9]+", s) or int(s) > 63:
        fail("INVALID_SHIFT", "A shift count must be a whole number from 0 to 63")
    return int(s)