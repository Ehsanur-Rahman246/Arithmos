"""Data-driven runner for the shared standard cases (spec Section 8)."""
import unittest

from tests.helpers import load_cases, run_standard_case


class TestStandardCases(unittest.TestCase):
    def test_shared_cases(self):
        cases = load_cases("standard")
        self.assertGreater(len(cases), 0)
        for case in cases:
            with self.subTest(case=case["id"]):
                run_standard_case(self, case)


if __name__ == "__main__":
    unittest.main()