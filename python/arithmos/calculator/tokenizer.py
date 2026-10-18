"""Expression text -> tokens (type, value). Unknown input -> INVALID_EXPRESSION."""
import re

from arithmos.shared import fail

_NUMBER = re.compile(r"[0-9]+\.?[0-9]*|\.[0-9]+")
_WORD = re.compile(r"[A-Za-z][A-Za-z0-9_]*")
_KEYWORDS = {"sqrt", "abs", "ans", "of"}


def tokenize(text: str) -> list:
    tokens = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch.isspace():
            i += 1
            continue
        m = _NUMBER.match(text, i)
        if m:
            tokens.append(("num", float(m.group())))
            i = m.end()
            continue
        m = _WORD.match(text, i)
        if m:
            word = m.group().lower()
            if word not in _KEYWORDS:
                fail("INVALID_EXPRESSION", f"Unknown word '{m.group()}'")
            tokens.append(("word", word))
            i = m.end()
            continue
        if ch in "+-*/^":
            tokens.append(("op", ch))
        elif ch == "(":
            tokens.append(("lparen", ch))
        elif ch == ")":
            tokens.append(("rparen", ch))
        elif ch == "%":
            tokens.append(("percent", ch))
        else:
            fail("INVALID_EXPRESSION", f"Unexpected character '{ch}'")
        i += 1
    return tokens