"""Number formatting (spec 2.3), error codes (spec 2.2), unit-table integrity."""
import unittest

from arithmos.converter import CATEGORIES, SYMBOL_INDEX
from arithmos.shared import ERROR_CODES, ArithmosError, format_number


class TestFormatNumber(unittest.TestCase):
    def test_twelve_significant_digits_and_trimming(self):
        for value, text in [
            (0.1 + 0.2, "0.3"), (1 / 3, "0.333333333333"), (2 / 3, "0.666666666667"),
            (2.5, "2.5"), (3.0, "3"), (-2.54, "-2.54"), (123456789.123456789, "123456789.123"),
        ]:
            self.assertEqual(format_number(value), text)

    def test_boundaries_1e15_and_1e_minus_6(self):
        for value, text in [
            (1e15, "1e+15"), (999999999999.0, "999999999999"),
            (999999999999999.0, "1e+15"),            # rounds up to 1e15 first, then scientific
            (123456789012345.0, "123456789012000"),
            (1e-6, "0.000001"), (1e-7, "1e-7"), (1.5e20, "1.5e+20"), (-2e-7, "-2e-7"), (1e-9, "1e-9"),
        ]:
            self.assertEqual(format_number(value), text)

    def test_ties_round_half_away_from_zero(self):
        self.assertEqual(format_number(100000000000.5), "100000000001")
        self.assertEqual(format_number(-100000000000.5), "-100000000001")

    def test_negative_zero(self):
        self.assertEqual(format_number(-0.0), "0")

    def test_infinity_is_overflow_and_nan_is_never_shown(self):
        for bad in (float("inf"), float("-inf")):
            with self.assertRaises(ArithmosError) as ctx:
                format_number(bad)
            self.assertEqual(ctx.exception.code, "OVERFLOW")
        with self.assertRaises(ArithmosError):
            format_number(float("nan"))


class TestTables(unittest.TestCase):
    def test_error_codes_match_spec(self):
        self.assertEqual(sorted(ERROR_CODES), sorted([
            "BELOW_ABSOLUTE_ZERO", "DIV_BY_ZERO", "DOMAIN_ERROR", "INCOMPATIBLE_UNITS", "INVALID_BASE",
            "INVALID_DIGIT", "INVALID_EXPRESSION", "INVALID_NUMBER", "INVALID_SHIFT", "OUT_OF_RANGE",
            "OVERFLOW", "UNDEFINED", "UNKNOWN_COMMAND", "UNKNOWN_UNIT",
        ]))

    def test_twelve_categories_unique_symbols_positive_factors(self):
        self.assertEqual(len(CATEGORIES), 12)
        self.assertEqual(len(SYMBOL_INDEX), sum(len(c.units) for c in CATEGORIES))
        for category in (c for c in CATEGORIES if not c.formula):
            self.assertTrue(any(u.factor == 1.0 for u in category.units), category.name)
            for unit in category.units:
                self.assertGreater(unit.factor, 0, unit.symbol)


if __name__ == "__main__":
    unittest.main()