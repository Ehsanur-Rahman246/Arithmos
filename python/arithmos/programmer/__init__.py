"""Programmer Calculator engine (no I/O).

ProgrammerSession.run(line) returns one of:
  {"type": "value",   "value": int}
  {"type": "convert", "text": str}
  {"type": "base",    "base": str}
"""
import re

from arithmos.shared import fail

from .format import format_all_bases, format_in_base
from .operations import OPERATIONS
from .parse import BASES, parse_literal, parse_shift_count, resolve_base

_BITWISE = {"and": "and", "or": "or", "xor": "xor"}
_SHIFTS = {"<<": "shl", ">>": "sar", ">>>": "shr"}


class ProgrammerSession:
    def __init__(self):
        self.input_base = "dec"

    def run(self, line: str) -> dict:
        # Allow `1<<3` as well as `1 << 3`.
        spaced = re.sub(r"(>>>|>>|<<)", r" \1 ", str(line))
        parts = spaced.split()
        if not parts:
            fail("UNKNOWN_COMMAND", "Type a number or a command. Try help")
        head = parts[0].lower()

        if head == "base":
            if len(parts) != 2:
                fail("INVALID_BASE", "Use: base bin | oct | dec | hex")
            self.input_base = resolve_base(parts[1])
            return {"type": "base", "base": self.input_base}

        # `convert 255 dec hex`, or just `255 dec hex` (the word convert is optional).
        if head == "convert" or (
            len(parts) == 3 and parts[1].lower() in BASES and parts[2].lower() in BASES
        ):
            args = parts[1:] if head == "convert" else parts
            if len(args) != 3:
                fail("UNKNOWN_COMMAND", "Use: convert <value> <from> <to>")
            source, target = resolve_base(args[1]), resolve_base(args[2])
            return {"type": "convert", "text": format_in_base(parse_literal(args[0], source), target)}

        if head == "not":
            if len(parts) != 2:
                fail("UNKNOWN_COMMAND", "Use: NOT <value>")
            return {"type": "value", "value": OPERATIONS["not"](parse_literal(parts[1], self.input_base))}

        if len(parts) == 1:
            return {"type": "value", "value": parse_literal(parts[0], self.input_base)}

        if len(parts) == 3:
            op = parts[1].lower()
            if op in _BITWISE:
                a = parse_literal(parts[0], self.input_base)
                b = parse_literal(parts[2], self.input_base)
                return {"type": "value", "value": OPERATIONS[_BITWISE[op]](a, b)}
            if op in _SHIFTS:
                a = parse_literal(parts[0], self.input_base)
                n = parse_shift_count(parts[2])
                return {"type": "value", "value": OPERATIONS[_SHIFTS[op]](a, n)}
        return fail("UNKNOWN_COMMAND", "Not a command. Try help")


__all__ = ["ProgrammerSession", "format_all_bases", "format_in_base", "parse_literal", "OPERATIONS"]