"""AND OR XOR NOT << >> >>> on int64 (spec 4.5). n is already validated to 0-63."""
from .int64 import to_int64, to_uint64

OPERATIONS = {
    "and": lambda a, b: to_int64(a & b),
    "or": lambda a, b: to_int64(a | b),
    "xor": lambda a, b: to_int64(a ^ b),
    "not": lambda a: to_int64(~a),
    "shl": lambda a, n: to_int64(a << n),            # bits past 63 are discarded
    "sar": lambda a, n: a >> n,                       # arithmetic: sign-extending
    "shr": lambda a, n: to_int64(to_uint64(a) >> n),  # logical: zero-filling
}