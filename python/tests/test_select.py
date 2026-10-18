"""Arrow-key selector: key handling, drawing (highlight), the draw/read loop, pick()."""
import io
import unittest

from arithmos.cli.pick import Option, pick
from arithmos.cli.selector import apply_key, initial_state, render, select_from_list
from arithmos.cli.style import PLAIN, Style


def press(state, key, **extras):
    return apply_key(state, key, **extras)


class TestKeys(unittest.TestCase):
    def test_up_down_wrap_home_end(self):
        s = initial_state(3)
        s, _ = press(s, "down")
        self.assertEqual(s.index, 1)
        s, _ = press(s, "down")
        s, _ = press(s, "down")
        self.assertEqual(s.index, 0)  # wrapped
        s, _ = press(s, "up")
        self.assertEqual(s.index, 2)
        s, _ = press(s, "home")
        self.assertEqual(s.index, 0)
        s, _ = press(s, "end")
        self.assertEqual(s.index, 2)

    def test_long_lists_scroll_in_a_window_of_ten(self):
        s = initial_state(18)
        self.assertEqual(s.size, 10)
        for _ in range(12):
            s, _ = press(s, "down")
        self.assertTrue(s.offset <= s.index < s.offset + s.size)
        s, _ = press(s, "end")
        self.assertEqual(s.offset, 8)
        text = "\n".join(render("T", [f"u{i}" for i in range(18)], s))
        self.assertIn("18 of 18", text)
        self.assertIn("❯ u17", text)

    def test_enter_selects_and_other_keys_only_work_when_offered(self):
        s = initial_state(3)
        self.assertEqual(press(s, "enter")[1], "selected")
        self.assertIsNone(press(s, "esc")[1])
        self.assertEqual(press(s, "esc", back=True)[1], "back")
        self.assertEqual(press(s, "b", back=True)[1], "back")
        self.assertIsNone(press(s, "q")[1])
        self.assertEqual(press(s, "q", quit_=True)[1], "quit")
        self.assertEqual(press(s, "abort")[1], "abort")
        self.assertIsNone(press(s, "other")[1])


class TestDrawing(unittest.TestCase):
    def test_selected_row_is_highlighted(self):
        state, _ = press(initial_state(3), "down")
        lines = render("Pick", ["aa", "bbbb", "c"], state, Style(True))
        self.assertIn("\x1b[7m", lines[2])             # row 1 is the highlighted one
        self.assertIn("❯ bbbb", lines[2])
        self.assertNotIn("\x1b[7m", lines[1] + lines[3])
        self.assertEqual(len(lines), 5)                # title + 3 rows + hint

    def test_plain_mode_still_marks_the_row(self):
        lines = render("Pick", ["aa", "bb"], initial_state(2), PLAIN)
        self.assertTrue(lines[1].startswith(" ❯ aa"))
        self.assertTrue(lines[2].startswith("   bb"))

    def test_hint_lists_only_keys_on_offer(self):
        hint = lambda **k: render("T", ["a", "b"], initial_state(2), PLAIN, **k)[-1]  # noqa: E731
        self.assertIn("Enter select", hint())
        self.assertNotIn("Esc", hint())
        self.assertIn("Esc back", hint(back=True))
        self.assertIn("q quit", hint(quit_=True))


class TestLoop(unittest.TestCase):
    def run_keys(self, keys, **extras):
        out, feed = io.StringIO(), iter(keys)

        def read_key():
            key = next(feed)
            if isinstance(key, BaseException):
                raise key
            return key

        result = select_from_list("Pick", ["a", "b", "c"], out=out, read_key=read_key, **extras)
        return result, out.getvalue()

    def test_keys_in_index_out_summary_left_behind(self):
        (status, index), text = self.run_keys(["down", "down", "enter"])
        self.assertEqual((status, index), ("selected", 2))
        self.assertIn("✔ Pick: c", text)

    def test_cursor_is_hidden_then_restored(self):
        _, text = self.run_keys(["enter"])
        self.assertTrue(text.startswith("\x1b[?25l"))
        self.assertTrue(text.endswith("\x1b[?25h"))

    def test_esc_ctrl_c_and_ignored_keys(self):
        self.assertEqual(self.run_keys(["esc"], back=True)[0], ("back", None))
        self.assertEqual(self.run_keys(["other", "esc", "enter"])[0], ("selected", 0))  # Esc not offered
        self.assertEqual(self.run_keys([KeyboardInterrupt()])[0], ("abort", None))


class FakeIO:
    style = PLAIN

    def __init__(self, result):
        self.result = result
        self.seen = None

    def select(self, title, labels, back=False, quit_=False):
        self.seen = (title, labels, back, quit_)
        return self.result

    def write(self, text):
        pass


class TestPick(unittest.TestCase):
    options = [Option("1", "x", "X"), Option("2", "y", "Y")]

    def test_uses_io_select_when_present_and_maps_results(self):
        fake = FakeIO(("selected", 1))
        r = pick(fake, "t", self.options, back=True)
        self.assertEqual((r.status, r.option.value), ("selected", "Y"))
        self.assertEqual(fake.seen, ("t", ["x", "y"], True, True))
        self.assertEqual(pick(FakeIO(("back", None)), "t", self.options).status, "back")
        self.assertEqual(pick(FakeIO(("abort", None)), "t", self.options).status, "eof")


if __name__ == "__main__":
    unittest.main()