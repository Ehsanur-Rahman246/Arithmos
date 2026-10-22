"""Entry point. No arguments -> interactive menu. One-shot forms:
  python -m arithmos std "2 + 3 * 4"      python -m arithmos prog "5 AND 3"
  python -m arithmos convert 100 cm in    (also: list, convert 1 km all)
Exit status: 0 ok, 1 the line produced Error [CODE], 2 bad usage."""
import sys

from arithmos.shared import ArithmosError
from arithmos.cli.style import PLAIN

from .console import create_console
from .menu import run_menu
from .repl import print_error
from .tools.converter import converter_tool
from .tools.programmer import programmer_tool
from .tools.standard import standard_tool

USAGE = (
    "Usage: python -m arithmos [command]\n"
    "  (nothing)              interactive menu\n"
    '  std "2 + 3 * 4"        one calculation\n'
    '  prog "5 AND 3"         one programmer command\n'
    "  convert 100 cm in      one conversion   (also: list, convert 1 km all)"
)

# word -> (tool factory, how many leading words to drop before the line)
_ONE_SHOT = {
    "std": (standard_tool, 1), "standard": (standard_tool, 1),
    "prog": (programmer_tool, 1), "programmer": (programmer_tool, 1),
    "convert": (converter_tool, 0), "list": (converter_tool, 0),
}


class _StderrIO:
    """One-shot errors go to stderr. Plain style so no colour codes leak into logs."""
    style = PLAIN
    def write(self, text: str) -> None:
        sys.stderr.write(text)

def main(argv=None, io=None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    injected = io is not None
    io = io or create_console()
    errio = io if injected else _StderrIO()
    if not args:
        run_menu(io)
        return 0

    head = args[0].lower()
    if head in ("-h", "--help", "help"):
        io.write(USAGE + "\n")
        return 0
    entry = _ONE_SHOT.get(head)
    line = " ".join(args[entry[1]:]) if entry else ""
    if not entry or not line.strip():
        errio.write(USAGE + "\n")
        return 2
    try:
        out = entry[0]().handle(line)
        if out:
            io.write(out + "\n")
        return 0
    except ArithmosError as err:
        print_error(errio, err)
        return 1


def run() -> None:
    sys.exit(main())