"""Command layer (no I/O): convert <v> <from> <to> | <v> <from> <to> | ... all | list [category]."""
import math
import re

from arithmos.shared import fail, format_number

from .convert import convert, convert_all, list_categories, list_units

_VALUE = re.compile(r"[+-]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)")


def parse_value(text: str) -> float:
    if not _VALUE.fullmatch(text):
        fail("INVALID_NUMBER", f"'{text}' is not a number")
    number = float(text)
    if math.isinf(number):
        fail("OVERFLOW", "That number is too large")
    return number


class ConverterSession:
    def run(self, line: str) -> str:
        parts = str(line).split()
        if not parts:
            fail("UNKNOWN_COMMAND", "Type a value, e.g. 100")
        head = parts[0].lower()

        if head == "list":
            if len(parts) == 1:
                return ", ".join(list_categories())
            if len(parts) == 2:
                return ", ".join(list_units(parts[1]))
            fail("UNKNOWN_COMMAND", "Use: list  or  list <category>")

        if head == "convert":
            if len(parts) != 4:
                fail("UNKNOWN_COMMAND", "Use: convert <value> <from> <to>")
            args = parts[1:]
        else:
            if len(parts) != 3:
                fail("UNKNOWN_COMMAND", "Not a command. Try: convert 100 cm in")
            args = parts
        text, source, target = args
        value = parse_value(text)

        if target.lower() == "all":
            rows = convert_all(value, source)  # format everything first: any overflow fails the command
            return "\n".join(f"{symbol}: {format_number(v)}" for symbol, v in rows)
        return format_number(convert(value, source, target))