"""Arrow-key selector: key handling, drawing (highlight), the draw/read loop, pick().

SL1-SL21 are the same 21 behaviours, with the same numbers and names, in the JavaScript
(test/select.test.js) and C (test/run_selector.c) editions; see docs/test-cases.md.
"""
import io
import unittest

from arithmos.cli.pick import Option, pick
from arithmos.cli.selector import apply_key, initial_state, render, select_from_list
from arithmos.cli.style import PLAIN, Style


def press(state, key, **extras):
    return apply_key(state, key, **extras)


# ---------- keys (pure) ----------

class TestKeys(unittest.TestCase):
    def test_sl01_up_down_wrap_home_end(self):
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

    def test_sl02_long_lists_scroll_in_a_window_of_10(self):
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

    def test_sl03_enter_selects_esc_b_q_only_work_when_offered(self):
        s = initial_state(3)
        self.assertEqual(press(s, "enter")[1], "selected")
        self.assertIsNone(press(s, "esc")[1])
        self.assertEqual(press(s, "esc", back=True)[1], "back")
        self.assertEqual(press(s, "b", back=True)[1], "back")
        self.assertIsNone(press(s, "q")[1])
        self.assertEqual(press(s, "q", quit_=True)[1], "quit")
        self.assertIsNone(press(s, "char:x", back=True, quit_=True)[1])

    def test_sl04_ctrl_c_ctrl_d_abort_other_control_keys_ignored(self):
        s = initial_state(3)
        self.assertEqual(press(s, "abort")[1], "abort")
        self.assertEqual(press(s, "abort", back=True, typing=True)[1], "abort")
        self.assertIsNone(press(s, "other", back=True, quit_=True, typing=True)[1])

    def test_sl05_typing_on_a_printable_key_ends_the_selector(self):
        s = initial_state(3)
        self.assertEqual(press(s, "char:x", typing=True)[1], "typed")
        self.assertEqual(press(s, "char:1", typing=True)[1], "typed")

    def test_sl06_typing_off_printable_keys_are_ignored(self):
        s = initial_state(3)
        self.assertIsNone(press(s, "char:x")[1])
        self.assertIsNone(press(s, "char:1", back=True, quit_=True)[1])

    def test_sl07_typing_on_esc_b_q_arrows_enter_keep_their_meaning(self):
        on = dict(back=True, quit_=True, typing=True)
        s = initial_state(3)
        self.assertEqual(press(s, "esc", **on)[1], "back")
        self.assertEqual(press(s, "b", **on)[1], "back")
        self.assertEqual(press(s, "q", **on)[1], "quit")
        self.assertEqual(press(s, "down", **on)[0].index, 1)
        self.assertEqual(press(s, "enter", **on)[1], "selected")
        self.assertIsNone(press(s, "b", typing=True)[1])  # back not offered: not a typed key either

    def test_sl08_typing_on_space_and_control_keys_do_not_start_a_line(self):
        s = initial_state(3)
        self.assertIsNone(press(s, "other", typing=True)[1])  # a space or a control key reads as "other"
        self.assertIsNone(press(s, "space", typing=True)[1])


# ---------- drawing (pure) ----------

class TestDrawing(unittest.TestCase):
    def test_sl09_selected_row_is_highlighted_as_a_full_bar(self):
        state, _ = press(initial_state(3), "down")
        lines = render("Pick", ["aa", "bbbb", "c"], state, Style(True))
        self.assertIn("\x1b[7m", lines[2])             # row 1 is the highlighted one
        self.assertIn("❯ bbbb", lines[2])
        self.assertNotIn("\x1b[7m", lines[1] + lines[3])
        self.assertEqual(len(lines), 5)                # title + 3 rows + hint

    def test_sl10_plain_mode_still_marks_the_row_with_the_pointer(self):
        lines = render("Pick", ["aa", "bb"], initial_state(2), PLAIN)
        self.assertTrue(lines[1].startswith(" ❯ aa"))
        self.assertTrue(lines[2].startswith("   bb"))

    def test_sl11_hint_lists_only_the_keys_on_offer(self):
        hint = lambda **k: render("T", ["a", "b"], initial_state(2), PLAIN, **k)[-1]  # noqa: E731
        self.assertIn("Enter select", hint())
        self.assertNotIn("Esc", hint())
        self.assertIn("Esc back", hint(back=True))
        self.assertIn("q quit", hint(quit_=True))

    def test_sl12_hint_shows_esc_b_back_and_or_type_when_typing_is_on(self):
        hint = render("T", ["a", "b"], initial_state(2), PLAIN, back=True, quit_=True, typing=True)[-1]
        self.assertIn("Esc/b back", hint)
        self.assertIn("q quit", hint)
        self.assertIn("or type", hint)


# ---------- the loop, over a fake keyboard and screen ----------

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

    def test_sl13_loop_keys_in_index_out_summary_cursor_restored(self):
        (status, index), text = self.run_keys(["down", "down", "enter"], back=True)
        self.assertEqual((status, index), ("selected", 2))
        self.assertIn("✔ Pick: c", text)
        self.assertTrue(text.startswith("\x1b[?25l"))  # cursor hidden...
        self.assertTrue(text.endswith("\x1b[?25h"))    # ...then restored

    def test_sl14_loop_esc_ignored_keys_ctrl_c(self):
        self.assertEqual(self.run_keys(["esc"], back=True)[0], ("back", None))
        self.assertEqual(self.run_keys(["other", "esc", "enter"])[0], ("selected", 0))  # Esc not offered
        self.assertEqual(self.run_keys([KeyboardInterrupt()])[0], ("abort", None))

    def test_sl15_loop_a_typed_key_returns_its_character_and_restores_cursor(self):
        (status, value), text = self.run_keys(["char:x"], back=True, typing=True)
        self.assertEqual((status, value), ("typed", "x"))
        self.assertTrue(text.rfind("\x1b[?25h") > text.rfind("\x1b[?25l"))
        self.assertTrue(text.endswith("\x1b[?25h"))


# ---------- pick(), over a scripted environment ----------

class ScriptedIO:
    """keys: what the user presses at the selector; lines: the rest of each typed line (after
    the typed key), or whole lines in plain mode. with_select=False is a pipe."""
    style = PLAIN

    def __init__(self, keys=(), lines=(), with_select=True):
        self.keys, self.lines = list(keys), list(lines)
        self.buf, self.prompts = "", []
        if with_select:
            self.select = self._select

    def _select(self, title, labels, back=False, quit_=False, typing=False):
        return select_from_list(
            title, labels, out=self, read_key=lambda: self.keys.pop(0) if self.keys else "abort",
            style=PLAIN, back=back, quit_=quit_, typing=typing)

    def write(self, text):
        self.buf += text

    def flush(self):
        pass

    def read_line(self, prompt=""):
        self.prompts.append(prompt)
        return self.lines.pop(0) if self.lines else None


class RecordingIO:
    """A selector that returns a canned result and remembers how it was called."""
    style = PLAIN

    def __init__(self, result):
        self.result, self.seen = result, None

    def select(self, title, labels, back=False, quit_=False, typing=False):
        self.seen = (title, labels, back, quit_, typing)
        return self.result

    def write(self, text):
        pass


OPTIONS = [Option(str(i + 1), name, name, (name,)) for i, name in enumerate(["length", "mass", "area"])]


def passthrough(line):
    return f"ran:{line}"


class TestPick(unittest.TestCase):
    def test_sl16_uses_the_selector_when_present_and_maps_its_results(self):
        options = [Option("1", "x", "X"), Option("2", "y", "Y")]
        fake = RecordingIO(("selected", 1))
        r = pick(fake, "t", options, back=True)
        self.assertEqual((r.status, r.option.value), ("selected", "Y"))
        self.assertEqual(fake.seen, ("t", ["x", "y"], True, True, True))
        self.assertEqual(pick(RecordingIO(("back", None)), "t", options).status, "back")
        self.assertEqual(pick(RecordingIO(("quit", None)), "t", options).status, "quit")
        self.assertEqual(pick(RecordingIO(("abort", None)), "t", options).status, "eof")

    def test_sl17_a_typed_name_or_number_selects_it(self):
        fake = ScriptedIO(keys=["char:m"], lines=["ass"])
        r = pick(fake, "Cat", OPTIONS, back=True, passthrough=passthrough)
        self.assertEqual(r.option.value, "mass")
        self.assertEqual(fake.prompts[0], "> m")  # the typed key is shown after the prompt
        fake = ScriptedIO(keys=["char:3"], lines=[""])
        r = pick(fake, "Cat", OPTIONS, back=True, passthrough=passthrough)
        self.assertEqual(r.option.value, "area")

    def test_sl18_a_typed_one_line_command_runs_and_the_list_comes_back(self):
        fake = ScriptedIO(keys=["char:l", "enter"], lines=["ist"])
        r = pick(fake, "Cat", OPTIONS, back=True, passthrough=passthrough)
        self.assertIn("ran:list\n", fake.buf)  # the command ran, then the list came back
        self.assertEqual(r.option.value, "length")

    def test_sl19_an_unknown_typed_word_is_an_error_and_the_list_comes_back(self):
        fake = ScriptedIO(keys=["char:x", "esc"], lines=["yz"])
        r = pick(fake, "Cat", OPTIONS, back=True)
        self.assertIn("Error [UNKNOWN_COMMAND]: Pick one from the list", fake.buf)
        self.assertEqual(r.status, "back")  # then Esc goes back

    def test_sl20_b_q_and_esc_act_at_once_with_no_prompt_line(self):
        for key, status in [("b", "back"), ("q", "quit"), ("esc", "back"), ("abort", "eof")]:
            fake = ScriptedIO(keys=[key])
            r = pick(fake, "Cat", OPTIONS, back=True)
            self.assertEqual(r.status, status)
            self.assertEqual(fake.prompts, [])

    def test_sl21_without_a_selector_the_numbered_list_works_as_before(self):
        fake = ScriptedIO(lines=["mass"], with_select=False)
        r = pick(fake, "Cat", OPTIONS, back=True)
        self.assertEqual(r.option.value, "mass")
        self.assertIn("  1) length", fake.buf)  # the numbered list is shown
        self.assertIn("  3) area", fake.buf)
        self.assertEqual(fake.prompts[0], "> ")


if __name__ == "__main__":
    unittest.main()
