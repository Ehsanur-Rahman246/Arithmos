"""The shared prompt loop for the two calculators: help, back, quit (any case),
blank lines ignored, end of input exits cleanly, errors never end the loop.
Returns 'back' | 'quit' | 'eof'."""
from arithmos.shared import ArithmosError, format_error


def print_error(io, err) -> None:
    if isinstance(err, ArithmosError):
        io.write(io.style.red(format_error(err)) + "\n")
    else:  # a bug, but the loop survives
        io.write(io.style.red(f"Error [INTERNAL]: {err}") + "\n")


def run_repl(io, tool) -> str:
    io.write(tool.intro + "\n")
    while True:
        raw = io.read_line(tool.prompt)
        if raw is None:
            io.write("\n")
            return "eof"
        line = raw.strip()
        if not line:
            continue
        word = line.lower()
        if word == "back":
            return "back"
        if word == "quit":
            return "quit"
        if word in ("help", "?"):
            io.write(tool.help + "\n")
            continue
        try:
            out = tool.handle(line)
            if out:
                io.write(out + "\n")
        except Exception as err:  # noqa: BLE001 - see print_error
            print_error(io, err)