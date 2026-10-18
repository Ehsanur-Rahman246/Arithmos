"""The real keyboard and screen. The rest of the CLI only uses the small interface
every console object has: write(text), read_line(prompt) -> str | None (None = end
of input), style, and, on real terminals only, select(...)."""
import os
import sys
from contextlib import contextmanager

from .selector import select_from_list
from .style import PLAIN, Style

try:  # line editing and history for input() on Linux/macOS
    import readline  # noqa: F401
except ImportError:
    pass


class PipedConsole:
    """Pipes, files, tests: plain text, no colours, no arrow-key selector."""

    style = PLAIN

    def __init__(self, stdin, stdout):
        self._in, self._out = stdin, stdout

    def write(self, text: str) -> None:
        self._out.write(text)
        self._out.flush()

    def read_line(self, prompt: str = ""):
        self.write(prompt)
        line = self._in.readline()
        return None if line == "" else line.rstrip("\r\n")


class TerminalConsole:
    """A real terminal: colours, line editing, arrow-key selector."""

    def __init__(self, stdin, stdout, style):
        self._in, self._out, self.style = stdin, stdout, style

    def write(self, text: str) -> None:
        self._out.write(text)
        self._out.flush()

    def read_line(self, prompt: str = ""):
        try:
            return input(prompt)
        except (EOFError, KeyboardInterrupt):
            return None

    def select(self, title, labels, back=False, quit_=False):
        with _raw_keys() as read_key:
            return select_from_list(
                title, labels, out=self._out, read_key=read_key,
                style=self.style, back=back, quit_=quit_,
            )


@contextmanager
def _raw_keys():
    """Yields read_key() -> key name, with the terminal in single-key mode."""
    if os.name == "nt":
        import msvcrt

        def read_key():
            ch = msvcrt.getwch()
            if ch in ("\x00", "\xe0"):  # arrow / function keys come as two characters
                return {"H": "up", "P": "down", "G": "home", "O": "end"}.get(msvcrt.getwch(), "other")
            named = {"\r": "enter", "\x1b": "esc", "\x03": "abort", "\x04": "abort"}
            if ch in named:
                return named[ch]
            return {"b": "b", "q": "q"}.get(ch.lower(), "other")

        yield read_key
        return

    import select as _select
    import termios
    import tty

    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    tty.setcbreak(fd)

    def read_key():
        data = os.read(fd, 1)
        if data == b"\x1b":
            if not _select.select([fd], [], [], 0.05)[0]:
                return "esc"  # a lone Esc press
            data += os.read(fd, 8)
        if data in (b"\r", b"\n"):
            return "enter"
        if data in (b"\x03", b"\x04"):
            return "abort"
        if data[:1] == b"\x1b":
            if data[-1:] == b"A":
                return "up"
            if data[-1:] == b"B":
                return "down"
            if data[-1:] == b"H" or data in (b"\x1b[1~", b"\x1b[7~"):
                return "home"
            if data[-1:] == b"F" or data in (b"\x1b[4~", b"\x1b[8~"):
                return "end"
            return "other"
        return {b"b": "b", b"B": "b", b"q": "q", b"Q": "q"}.get(data, "other")

    try:
        yield read_key
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)


def create_console(stdin=None, stdout=None):
    stdin, stdout = stdin or sys.stdin, stdout or sys.stdout
    for stream in (stdin, stdout, sys.stderr):  # so ❯ ✔ → — never crash on Windows code pages
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8", errors="replace")
            except (ValueError, OSError):
                pass
    if stdin.isatty() and stdout.isatty():
        if os.name == "nt":
            os.system("")  # switches on ANSI escape codes in the Windows console
        colour = not os.environ.get("NO_COLOR") and os.environ.get("TERM") != "dumb"
        return TerminalConsole(stdin, stdout, Style(colour))
    return PipedConsole(stdin, stdout)