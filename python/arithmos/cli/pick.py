"""One question, many answers. Real terminal: arrow-key selector with a highlighted
row. Anywhere else: the same list, answered by typing a number, a name or a symbol.

Returns Pick(status, option) with status selected | back | quit | eof."""
from dataclasses import dataclass
from typing import Any, Callable, Optional

from arithmos.shared import ArithmosError

from .repl import print_error


@dataclass(frozen=True)
class Option:
    key: str
    label: str
    value: Any = None
    aliases: tuple = ()


@dataclass(frozen=True)
class Pick:
    status: str
    option: Optional[Option] = None


def pick(io, title: str, options: list, *, back: bool = False, quit_: bool = True,
         passthrough: Optional[Callable[[str], str]] = None,
         error_code: str = "UNKNOWN_COMMAND") -> Pick:
    select = getattr(io, "select", None)
    if select:
        status, index = select(title, [o.label for o in options], back=back, quit_=quit_)
        if status == "selected":
            return Pick("selected", options[index])
        return Pick("eof" if status == "abort" else status)

    def show():
        io.write(title + "\n" + "\n".join(f"  {o.key}) {o.label}" for o in options) + "\n")

    show()
    while True:
        raw = io.read_line("> ")
        if raw is None:
            io.write("\n")
            return Pick("eof")
        text = raw.strip().lower()
        if not text:
            continue
        if text == "quit":
            return Pick("quit")
        if text == "back" and back:
            return Pick("back")
        if text in ("help", "?"):
            show()
            continue
        for o in options:
            if text in (o.key, o.label.lower()) or text in o.aliases:
                return Pick("selected", o)
        if passthrough and (" " in text or text == "list"):  # one-line commands still work
            try:
                out = passthrough(raw.strip())
                if out:
                    io.write(out + "\n")
            except ArithmosError as err:
                print_error(io, err)
            continue
        print_error(io, ArithmosError(error_code, "Pick one from the list"))