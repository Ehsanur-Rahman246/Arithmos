"""Main menu (spec 2.1): 1 Standard, 2 Programmer, 3 Converter, 0 Exit."""
from .pick import Option, pick
from .repl import run_repl
from .tools.converter import run_guided_converter
from .tools.programmer import programmer_tool
from .tools.standard import standard_tool

TITLE = "Arithmos 1.0 — Core CLI"

_MENU = [
    Option("1", "Standard Calculator", "standard"),
    Option("2", "Programmer Calculator", "programmer"),
    Option("3", "Unit Converter", "converter"),
    Option("0", "Exit", "exit"),
]


def _run_tool(name: str, io) -> str:
    if name == "converter":
        return run_guided_converter(io)
    return run_repl(io, standard_tool() if name == "standard" else programmer_tool())


def run_menu(io) -> str:
    while True:
        r = pick(io, TITLE, _MENU)
        if r.status == "eof":
            return "eof"
        if r.status != "selected" or r.option.value == "exit":
            return "exit"
        outcome = _run_tool(r.option.value, io)
        if outcome in ("quit", "eof"):
            return outcome