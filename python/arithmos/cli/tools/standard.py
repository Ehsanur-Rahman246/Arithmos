from arithmos.calculator import StandardSession

from . import Tool


def standard_tool() -> Tool:
    session = StandardSession()
    return Tool(
        name="Standard Calculator",
        prompt="standard> ",
        intro=(
            "Standard Calculator   (help · back · quit)\n"
            "Try: 2 + 3 * 4    sqrt(16)    20% of 150    ans * 2"
        ),
        help=(
            "  2 + 3 * 4        + - * / ^ and ( )\n"
            "  sqrt(x) abs(x)   functions\n"
            "  20% of 150       percent;  200 + 10% adds 10% of 200\n"
            "  ans              the last result\n"
            "  back  main menu     quit  exit"
        ),
        handle=session.run,
    )