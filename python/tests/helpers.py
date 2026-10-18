"""Loads the shared cases (repo-root docs/release-1-cases.json) and runs one case.
Asserts results and error CODES only, never message text."""
import json
import unittest
from pathlib import Path

from arithmos.calculator import StandardSession
from arithmos.converter import ConverterSession
from arithmos.programmer import ProgrammerSession, format_all_bases
from arithmos.shared import ArithmosError

CASES_FILE = Path(__file__).resolve().parents[2] / "docs" / "release-1-cases.json"


def load_cases(tool: str) -> list:
    with open(CASES_FILE, encoding="utf-8") as f:
        return [c for c in json.load(f) if c["tool"] == tool]


def expect_error(test: unittest.TestCase, fn, code: str) -> None:
    with test.assertRaises(ArithmosError) as ctx:
        fn()
    test.assertEqual(ctx.exception.code, code)


def run_standard_case(test, case) -> None:
    session = StandardSession()
    steps = case.get("steps") or [{"input": case["input"], "expected": case.get("expected"), "error": case.get("error")}]
    for step in steps:
        if step.get("error"):
            expect_error(test, lambda s=step: session.run(s["input"]), step["error"])
        else:
            test.assertEqual(session.run(step["input"]), step["expected"], step["input"])


def run_programmer_case(test, case) -> None:
    session = ProgrammerSession()
    for line in case.get("setup", []):
        session.run(line)
    if case.get("error"):
        return expect_error(test, lambda: session.run(case["input"]), case["error"])
    result = session.run(case["input"])
    expected = case["expected"]
    if isinstance(expected, str):
        test.assertEqual(result["type"], "convert")
        return test.assertEqual(result["text"], expected)
    test.assertEqual(result["type"], "value")
    shown = format_all_bases(result["value"])
    for key, want in expected.items():
        test.assertEqual(shown[key], want, key)


def run_converter_case(test, case) -> None:
    session = ConverterSession()
    if case.get("error"):
        return expect_error(test, lambda: session.run(case["input"]), case["error"])
    out = session.run(case["input"])
    if case.get("expectedContains"):
        lines = out.split("\n")
        for want in case["expectedContains"]:
            test.assertIn(want, lines)
        return None
    return test.assertEqual(out, case["expected"])