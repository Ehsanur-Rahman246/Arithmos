"""Data-driven runner for the shared programmer cases (spec Section 8)."""
import unittest

from tests.helpers import load_cases, run_programmer_case


class TestProgrammerCases(unittest.TestCase):
    def test_shared_cases(self):
        cases = load_cases("programmer")
        self.assertGreater(len(cases), 0)
        for case in cases:
            with self.subTest(case=case["id"]):
                run_programmer_case(self, case)


if __name__ == "__main__":
    unittest.main()