"""Tiny ANSI styling. Disabled (plain text) for pipes, tests and NO_COLOR."""


class Style:
    def __init__(self, enabled: bool = False):
        self.enabled = enabled

    def _wrap(self, code: str, text: str) -> str:
        return f"\x1b[{code}m{text}\x1b[0m" if self.enabled else text

    def bold(self, text):
        return self._wrap("1", text)

    def dim(self, text):
        return self._wrap("2", text)

    def red(self, text):
        return self._wrap("31", text)

    def green(self, text):
        return self._wrap("32", text)

    def inverse(self, text):
        return self._wrap("7", text)  # the highlight bar of the selector


PLAIN = Style(False)