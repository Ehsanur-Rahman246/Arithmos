"""Recursive-descent parser (spec 3.3). Precedence, high -> low:
( ) and calls > postfix % > ^ (right-assoc) > unary +/- > * / of > + -.
AST nodes are tuples: ('num', v) ('ans',) ('group', n) ('pct', n)
('unary', op, n) ('call', fn, n) ('bin', op, left, right).
`group` marks parentheses so `200 + (10%)` is not a relative percent."""
from arithmos.shared import fail


def parse(tokens: list):
    pos = 0

    def peek():
        return tokens[pos] if pos < len(tokens) else None

    def take():
        nonlocal pos
        tok = peek()
        pos += 1
        return tok

    def is_op(tok, *ops):
        return tok is not None and tok[0] == "op" and tok[1] in ops

    def is_word(tok, word):
        return tok is not None and tok[0] == "word" and tok[1] == word

    def bad(message):
        fail("INVALID_EXPRESSION", message)

    def expression():
        left = term()
        while is_op(peek(), "+", "-"):
            op = take()[1]
            left = ("bin", op, left, term())
        return left

    def term():
        left = unary()
        while True:
            tok = peek()
            if is_op(tok, "*", "/"):
                take()
                left = ("bin", tok[1], left, unary())
            elif is_word(tok, "of"):
                take()
                left = ("bin", "*", left, unary())
            else:
                return left

    def unary():
        if is_op(peek(), "+", "-"):
            op = take()[1]
            return ("unary", op, unary())
        return power()

    def power():
        base = postfix()
        if is_op(peek(), "^"):
            take()
            return ("bin", "^", base, unary())
        return base

    def postfix():
        node = primary()
        while peek() is not None and peek()[0] == "percent":
            take()
            node = ("pct", node)
        return node

    def primary():
        tok = take()
        if tok is None:
            bad("The expression ends too early")
        kind, value = tok
        if kind == "num":
            return ("num", value)
        if kind == "word":
            if value == "ans":
                return ("ans",)
            if value in ("sqrt", "abs"):
                opener = take()
                if opener is None or opener[0] != "lparen":
                    bad(f"{value} needs parentheses, like {value}(4)")
                arg = expression()
                closer = take()
                if closer is None or closer[0] != "rparen":
                    bad("Missing closing parenthesis")
                return ("call", value, arg)
            bad(f"Unexpected '{value}'")
        if kind == "lparen":
            inner = expression()
            closer = take()
            if closer is None or closer[0] != "rparen":
                bad("Missing closing parenthesis")
            return ("group", inner)
        return bad("Unexpected symbol")

    if not tokens:
        bad("Nothing to calculate")
    tree = expression()
    if pos < len(tokens):
        bad("Unexpected symbol")
    return tree