"""64-bit signed two's-complement emulation on Python's unbounded ints (spec 4.1)."""
INT64_MIN = -(2**63)
INT64_MAX = 2**63 - 1
_MASK = 2**64 - 1


def to_uint64(value: int) -> int:
    return value & _MASK


def to_int64(value: int) -> int:
    value &= _MASK
    return value - 2**64 if value > INT64_MAX else value