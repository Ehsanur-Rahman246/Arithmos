"""Unit Converter screens: category -> from -> to -> values. Only units of the chosen
category are ever offered, so inches -> kelvin cannot be picked. `back` (or Esc) goes
one screen back; from the category list it returns to the main menu."""
from arithmos.converter import CATEGORIES, ConverterSession

from ..pick import Option, pick
from ..repl import print_error
from . import Tool

HELP = (
    "  100            convert that number\n"
    "  100 cm in      or the full form:  convert 100 cm in\n"
    "  1 km all       the value in every unit\n"
    "  list           categories;   list length   its units\n"
    "  back  previous screen     quit  exit"
)


def converter_tool() -> Tool:
    """One-line form, used by `python -m arithmos convert 100 cm in`."""
    session = ConverterSession()
    return Tool("Unit Converter", "converter> ", "", HELP, session.run)


_CATEGORY_OPTIONS = [
    Option(str(i + 1), c.name, c, (c.name,)) for i, c in enumerate(CATEGORIES)
]


def _unit_options(category) -> list:
    return [
        Option(str(i + 1), f"{u.symbol:<8}{u.name}", u.symbol, (u.symbol,))
        for i, u in enumerate(category.units)
    ]


def run_guided_converter(io) -> str:
    """Returns 'back' | 'quit' | 'eof'."""
    session = ConverterSession()
    stage, category, source, target = 0, None, None, None
    while True:
        if stage == 0:
            r = pick(io, "Unit Converter — choose a category", _CATEGORY_OPTIONS,
                     back=True, passthrough=session.run)
            if r.status != "selected":
                return r.status
            category, stage = r.option.value, 1
        elif stage == 1:
            r = pick(io, f"{category.name.capitalize()} — convert from", _unit_options(category),
                     back=True, passthrough=session.run)
            if r.status == "back":
                stage = 0
            elif r.status != "selected":
                return r.status
            else:
                source, stage = r.option.value, 2
        elif stage == 2:
            r = pick(io, f"{category.name.capitalize()} — convert from {source} to",
                     _unit_options(category), back=True, passthrough=session.run)
            if r.status == "back":
                stage = 1
            elif r.status != "selected":
                return r.status
            else:
                target, stage = r.option.value, 3
        else:
            outcome = _convert_values(io, session, category.name.capitalize(), source, target)
            if outcome != "back":
                return outcome
            stage = 2


def _convert_values(io, session, name, source, target) -> str:
    io.write(f"\n{io.style.bold(f'{name}: {source} → {target}')}\n")
    io.write(io.style.dim("Type a number or a full command.   (help · back · quit)") + "\n")
    prompt = f"converter ({source} → {target})> "
    while True:
        raw = io.read_line(prompt)
        if raw is None:
            io.write("\n")
            return "eof"
        line = raw.strip()
        if not line:
            continue
        word = line.lower()
        if word in ("back", "quit"):
            return word
        if word in ("help", "?"):
            io.write(HELP + "\n")
            continue
        try:
            if " " in line or word == "list":  # a full one-line command
                io.write(session.run(line) + "\n")
            else:
                io.write(f"{line} {source} = {session.run(f'convert {line} {source} {target}')} {target}\n")
        except Exception as err:  # noqa: BLE001
            print_error(io, err)