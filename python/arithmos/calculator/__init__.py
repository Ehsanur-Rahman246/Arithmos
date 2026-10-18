"""Standard Calculator engine (no I/O)."""
from arithmos.shared import format_number

from .evaluator import evaluate_ast
from .parser import parse
from .tokenizer import tokenize


class StandardSession:
    """`ans` only changes after a successful evaluation (spec 3.1)."""

    def __init__(self):
        self.ans = 0.0

    def evaluate(self, line: str) -> float:
        result = evaluate_ast(parse(tokenize(line)), self.ans)
        format_number(result)  # raises if it cannot be shown; ans stays unchanged
        self.ans = result
        return result

    def run(self, line: str) -> str:
        return format_number(self.evaluate(line))


__all__ = ["StandardSession", "tokenize", "parse", "evaluate_ast"]