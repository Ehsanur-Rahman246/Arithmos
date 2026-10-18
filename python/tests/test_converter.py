"""Data-driven runner for the shared converter cases (spec Section 8)."""
import unittest

from tests.helpers import load_cases, run_converter_case


class TestConverterCases(unittest.TestCase):
    def test_shared_cases(self):
        cases = load_cases("converter")
        self.assertGreater(len(cases), 0)
        for case in cases:
            with self.subTest(case=case["id"]):
                run_converter_case(self, case)


if __name__ == "__main__":
    unittest.main()