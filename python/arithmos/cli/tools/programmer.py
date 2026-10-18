from arithmos.programmer import ProgrammerSession, format_all_bases

from . import Tool


def programmer_tool() -> Tool:
    session = ProgrammerSession()

    def handle(line: str) -> str:
        result = session.run(line)
        if result["type"] == "base":
            return ""
        if result["type"] == "convert":
            return result["text"]
        shown = format_all_bases(result["value"])
        return "\n".join(f"{key}: {shown[key]}" for key in ("HEX", "DEC", "OCT", "BIN"))

    return Tool(
        name="Programmer Calculator",
        prompt="programmer> ",
        intro=(
            "Programmer Calculator · 64-bit integers   (help · back · quit)\n"
            "Try: 255    5 AND 3    1 << 3    255 dec hex"
        ),
        help=(
            "  255  0xFF  0b101    show a number in HEX DEC OCT BIN\n"
            "  5 AND 3             also OR, XOR;  NOT 5\n"
            "  1 << 3              shifts: << left, >> arithmetic, >>> logical\n"
            "  255 dec hex         convert between bin, oct, dec, hex\n"
            "  base hex            type numbers in hex from now on\n"
            "  back  main menu     quit  exit"
        ),
        handle=handle,
    )