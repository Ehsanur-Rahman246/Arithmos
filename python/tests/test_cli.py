"""CLI tests (typed mode): menu, guided converter, help/back/quit, EOF, UNKNOWN_COMMAND,
one-shot mode, and "invalid input never crashes"."""
import unittest

from arithmos.cli.app import main
from arithmos.cli.style import PLAIN


class ScriptedIO:
    """Like a terminal: read_line records the prompt, then returns the next scripted line."""

    style = PLAIN

    def __init__(self, lines):
        self.queue, self.chunks = list(lines), []

    def read_line(self, prompt=""):
        self.chunks.append(prompt)
        return self.queue.pop(0) if self.queue else None

    def write(self, text):
        self.chunks.append(text)

    def text(self):
        return "".join(self.chunks)


def session(lines):
    io = ScriptedIO(lines)
    return main([], io), io.text()


MENU = "Arithmos 1.0 — Core CLI"
CONVERTER_VALUES = ["3", "12", "1", "2"]  # menu -> temperature -> c -> f, ready for values


class TestMenuAndTools(unittest.TestCase):
    def test_menu_lists_tools_and_exits_on_zero(self):
        code, out = session(["0"])
        self.assertEqual(code, 0)
        for piece in (MENU, "1) Standard Calculator", "2) Programmer Calculator", "3) Unit Converter", "0) Exit"):
            self.assertIn(piece, out)

    def test_each_tool_runs_and_back_returns_to_the_menu(self):
        _, out = session(["1", "25 + 17", "back", "2", "5 AND 3", "back", *CONVERTER_VALUES, "100", *["back"] * 4, "0"])
        self.assertIn("standard> 42\n", out)
        self.assertIn("DEC: 1\n", out)
        self.assertIn("100 c = 212 f\n", out)
        self.assertEqual(out.count(MENU), 4)  # first screen + after three tools

    def test_every_tool_says_what_to_type(self):
        self.assertIn("(help · back · quit)", session(["1", "quit"])[1])
        self.assertIn("Try: 2 + 3 * 4", session(["1", "quit"])[1])
        self.assertIn("Try: 255    5 AND 3", session(["2", "quit"])[1])
        self.assertIn("Type a number", session([*CONVERTER_VALUES, "quit"])[1])

    def test_help_and_question_mark_print_a_short_command_list(self):
        for flow in (["1"], ["2"], CONVERTER_VALUES):
            for word in ("help", "HELP", "?"):
                _, out = session([*flow, word, "quit"])
                self.assertIn("quit  exit", out)
                self.assertIn("back  ", out)

    def test_back_and_quit_in_any_case(self):
        for flow, backs in ((["1"], 1), (["2"], 1), (CONVERTER_VALUES, 4)):
            _, out = session([*flow, *["Back"] * backs, "0"])
            self.assertEqual(out.count(MENU), 2, flow)
            code, out = session([*flow, "QuIt", "1", "never reached"])
            self.assertEqual(code, 0)
            self.assertEqual(out.count(MENU), 1, flow)  # quit exits, no menu again

    def test_end_of_input_exits_cleanly_everywhere(self):
        for flow in ([], ["1"], ["3"], ["3", "1"], ["3", "1", "1"], ["3", "1", "1", "1"]):
            self.assertEqual(session(flow)[0], 0)

    def test_blank_lines_and_spaces_are_ignored(self):
        _, out = session(["1", "", "   ", "  2 + 2  ", "quit"])
        self.assertIn("standard> 4\n", out)
        self.assertNotIn("Error", out)

    def test_unknown_command_everywhere(self):
        _, out = session(["9", "2", "hello world foo", "back", "3", "blah", "back", "0"])
        self.assertEqual(out.count("Error [UNKNOWN_COMMAND]"), 3)

    def test_errors_print_in_one_line_and_ans_survives(self):
        _, out = session(["1", "7", "10 / 0", "ans", "quit"])
        self.assertRegex(out, r"Error \[DIV_BY_ZERO\]: .+")
        self.assertTrue(out.endswith("7\nstandard> "))

    def test_invalid_input_never_crashes_any_tool(self):
        junk = ["(((", ")", "%", "1e5", "5.5.5", "$$$", "0x", "-", "1 << ", "convert", "convert 1",
                "list nope", "base", "\t", "999999999999999999999999 + 1"]
        code, out = session(["1", *junk, "back", "2", *junk, "back", "3", *junk, "back",
                             "3", "1", "1", "2", *junk, "quit"])
        self.assertEqual(code, 0)
        self.assertNotIn("INTERNAL", out)


class TestProgrammerShortForms(unittest.TestCase):
    def test_convert_word_is_optional(self):
        _, out = session(["2", "255 dec hex", "convert 255 dec hex", "ff hex bin", "quit"])
        self.assertEqual(out.count("programmer> FF\n"), 2)
        self.assertIn("programmer> 11111111\n", out)

    def test_base_command_changes_how_numbers_are_read(self):
        _, out = session(["2", "base hex", "-FF", "quit"])
        self.assertIn("DEC: -255\n", out)


class TestGuidedConverter(unittest.TestCase):
    def test_all_twelve_categories_then_only_that_categorys_units(self):
        _, out = session(["3", "12", "quit"])
        names = ["length", "mass", "area", "volume", "time", "speed", "digital", "energy",
                 "power", "pressure", "angle", "temperature"]
        for i, name in enumerate(names, 1):
            self.assertIn(f"  {i}) {name}\n", out)
        after = out[out.index("Temperature — convert from"):]
        self.assertIn("kelvin", after)
        self.assertNotIn("centimetre", after)
        self.assertNotIn("inch", after)

    def test_names_and_symbols_work_as_well_as_numbers(self):
        self.assertIn("0 c = 32 f\n", session(["3", "temperature", "c", "f", "0", "quit"])[1])

    def test_values_repeat_and_errors_do_not_end_the_loop(self):
        _, out = session([*CONVERTER_VALUES, "100", "-40", "abc", "-300", "0", "quit"])
        for line in ("100 c = 212 f\n", "-40 c = -40 f\n", "0 c = 32 f\n"):
            self.assertIn(line, out)
        self.assertIn("Error [INVALID_NUMBER]", out)
        self.assertIn("Error [BELOW_ABSOLUTE_ZERO]", out)

    def test_back_goes_one_screen_at_a_time(self):
        _, out = session(["3", "1", "6", "7", "1", "back", "7", "1", "back", "back", "back", "quit"])
        # target screen: shown once, then again after each of the two `back`s from the values screen
        self.assertEqual(out.count("Length — convert from cm to"), 3)
        self.assertEqual(out.count("1 cm = 0.01 m\n"), 2)
        self.assertEqual(out.count("Unit Converter — choose a category"), 2)

    def test_one_line_commands_still_work(self):
        _, out = session(["3", "100 cm in", "list length", "1", "1", "1", "convert 1 km all", "quit"])
        self.assertIn("39.3700787402\n", out)
        self.assertIn("pm, ang, nm, um, mm, cm, m, km, in, ft, yd, mi, nmi, au, ly\n", out)
        self.assertIn("km: 1\n", out)
        self.assertIn("mi: 0.621371192237\n", out)

    def test_list_works_at_the_values_prompt(self):
        _, out = session([*CONVERTER_VALUES, "list", "quit"])
        self.assertIn("length, mass, area", out)

    def test_typed_back_and_quit_on_pick_screens(self):
        self.assertEqual(session(["3", "Back", "0"])[1].count(MENU), 2)
        self.assertEqual(session(["3", "1", "Back", "Back", "0"])[1].count(MENU), 2)
        self.assertEqual(session(["3", "1", "1", "QUIT", "0"])[1].count(MENU), 1)

    def test_a_bad_unit_pick_is_an_error_and_asks_again(self):
        _, out = session(["3", "12", "inch", "c", "f", "quit"])
        self.assertIn("Error [UNKNOWN_COMMAND]", out)
        self.assertIn("convert from c to", out)


class TestOneShot(unittest.TestCase):
    def run_one(self, *args):
        io = ScriptedIO([])
        return main(list(args), io), io.text()

    def test_convert(self):
        self.assertEqual(self.run_one("convert", "100", "cm", "in"), (0, "39.3700787402\n"))

    def test_std_prog_and_error_status(self):
        self.assertEqual(self.run_one("std", "25 + 17"), (0, "42\n"))
        self.assertEqual(self.run_one("prog", "convert 255 dec hex"), (0, "FF\n"))
        code, out = self.run_one("std", "10 / 0")
        self.assertEqual(code, 1)
        self.assertTrue(out.startswith("Error [DIV_BY_ZERO]"))

    def test_bad_usage(self):
        code, out = self.run_one("bogus")
        self.assertEqual(code, 2)
        self.assertIn("Usage:", out)


if __name__ == "__main__":
    unittest.main()