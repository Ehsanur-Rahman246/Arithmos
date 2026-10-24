package arithmos;

import arithmos.cli.KeyParser;
import arithmos.cli.Pick;
import arithmos.cli.Selector;
import arithmos.cli.Selector.Key;
import arithmos.cli.Selector.Kind;
import arithmos.cli.Selector.Options;
import arithmos.cli.Selector.State;
import arithmos.cli.Style;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

/**
 * Selector tests SL1–SL21 (the same numbers as every edition, see docs/test-cases.md),
 * plus X2 (line widths, window shrink, erase count) and X3 (raw bytes become keys).
 * Usage: java -cp out:out-test arithmos.RunSelector
 */
public final class RunSelector {
    private static final Set<String> ran = new TreeSet<>();
    private static int failed;

    private static void check(String id, boolean condition) {
        ran.add(id);
        if (!condition) {
            failed++;
            System.out.println("FAIL " + id);
        }
    }

    private static final Options NONE = new Options(false, false, false);
    private static final Options BACK_QUIT = new Options(true, true, false);
    private static final Options TYPING = new Options(false, false, true);
    private static final Options ALL = new Options(true, true, true);

    private static final Key UP = Key.of(Kind.UP);
    private static final Key DOWN = Key.of(Kind.DOWN);
    private static final Key HOME = Key.of(Kind.HOME);
    private static final Key END = Key.of(Kind.END);
    private static final Key ENTER = Key.of(Kind.ENTER);
    private static final Key ESC = Key.of(Kind.ESC);
    private static final Key CTRL_C = Key.of(Kind.CTRL_C);
    private static final Key CTRL_D = Key.of(Kind.CTRL_D);
    private static final Key OTHER = Key.of(Kind.OTHER);

    private static Key c(char ch) { return Key.ch(ch); }

    private static State at(int index) {
        State s = new State();
        s.index = index;
        return s;
    }

    private static Selector.Result handle(State s, Key k, Options o) {
        return Selector.handle(s, k, o, 3, 3);
    }

    private static boolean has(String s, String part) { return s.contains(part); }

    public static void main(String[] args) {
        // SL1: up/down move, wrap around, home/end
        State s1 = new State();
        handle(s1, UP, NONE);
        boolean a = s1.index == 2;
        handle(s1, DOWN, NONE);
        boolean b = s1.index == 0;
        handle(s1, END, NONE);
        boolean c1 = s1.index == 2;
        handle(s1, HOME, NONE);
        check("SL1", a && b && c1 && s1.index == 0);

        // SL2: long lists scroll in a window of 10
        State s2 = at(10);
        Selector.scroll(s2, 25, 10);
        boolean down = s2.top == 1;
        s2.index = 0;
        Selector.scroll(s2, 25, 10);
        check("SL2", Selector.windowSize(25, 40) == 10 && Selector.windowSize(4, 40) == 4 && down && s2.top == 0);

        // SL3: Enter selects; Esc / b / q only work when offered
        check("SL3", handle(at(1), ENTER, NONE).equals(new Selector.Picked(1))
                && handle(at(0), ESC, NONE) == null && handle(at(0), c('b'), NONE) == null
                && handle(at(0), c('q'), NONE) == null
                && handle(at(0), ESC, BACK_QUIT) instanceof Selector.Back
                && handle(at(0), c('b'), BACK_QUIT) instanceof Selector.Back
                && handle(at(0), c('q'), BACK_QUIT) instanceof Selector.Quit);

        // SL4: Ctrl-C / Ctrl-D abort; other control keys are ignored
        check("SL4", handle(at(0), CTRL_C, NONE) instanceof Selector.Abort
                && handle(at(0), CTRL_D, NONE) instanceof Selector.Abort && handle(at(0), OTHER, NONE) == null);

        // SL5: typing on: a printable key ends the selector and carries the character
        check("SL5", handle(at(0), c('x'), TYPING).equals(new Selector.Typed('x'))
                && handle(at(0), c('7'), TYPING).equals(new Selector.Typed('7'))
                && handle(at(0), Key.ch(0xE9), TYPING).equals(new Selector.Typed(0xE9)));

        // SL6: typing off: printable keys are ignored
        check("SL6", handle(at(0), c('x'), NONE) == null && handle(at(0), c('7'), BACK_QUIT) == null);

        // SL7: typing on: Esc, b, q, arrows and Enter keep their meaning
        State s7 = at(0);
        handle(s7, DOWN, ALL);
        check("SL7", handle(at(0), ESC, ALL) instanceof Selector.Back && handle(at(0), c('b'), ALL) instanceof Selector.Back
                && handle(at(0), c('q'), ALL) instanceof Selector.Quit && s7.index == 1
                && handle(at(2), ENTER, ALL).equals(new Selector.Picked(2)));

        // SL8: typing on: space and control keys do not start a typed line
        check("SL8", handle(at(0), c(' '), TYPING) == null && handle(at(0), OTHER, TYPING) == null
                && handle(at(0), Key.ch(1), TYPING) == null);

        // SL9: the selected row is highlighted as a full bar
        List<String> labels = List.of("one", "two", "three");
        List<String> colored = Selector.render("T", labels, at(1), NONE, 40, 3, new Style(true));
        String bar = colored.get(2); // title, one, [two], three, hint
        check("SL9", bar.startsWith("\u001b[7m") && bar.endsWith("\u001b[0m") && has(bar, "❯ two")
                && !has(colored.get(1), "\u001b[7m"));

        // SL10: plain mode still marks the selected row with the pointer
        List<String> plain = Selector.render("T", labels, at(1), NONE, 40, 3, Style.PLAIN);
        boolean noEsc = plain.stream().noneMatch(l -> l.contains("\u001b"));
        check("SL10", noEsc && plain.get(2).startsWith("❯ two") && plain.get(1).startsWith("  one"));

        // SL11: the hint line lists only the keys on offer
        String h11 = Selector.hint(NONE);
        check("SL11", has(h11, "Enter") && !has(h11, "Esc") && !has(h11, "q quit") && !has(h11, "type"));

        // SL12: the hint shows Esc/b back and "or type" when typing is on
        String h12 = Selector.hint(ALL);
        check("SL12", has(h12, "Esc/b back") && has(h12, "q quit") && has(h12, "or type"));

        // SL13: loop: keys in, index out, summary left behind, cursor restored
        Fakes.FakeScreen scr13 = new Fakes.FakeScreen(80, 24);
        Selector.Result r13 = Selector.run(Fakes.keyboard(DOWN, ENTER), scr13, "T", List.of("a", "b", "c"), NONE, Style.PLAIN);
        String o13 = scr13.out.toString();
        check("SL13", r13.equals(new Selector.Picked(1)) && o13.startsWith(Selector.HIDE) && o13.endsWith(Selector.SHOW)
                && has(o13, "✔ T: b"));

        // SL14: loop: Esc, ignored keys, Ctrl-C
        Fakes.FakeScreen scr14 = new Fakes.FakeScreen(80, 24);
        Selector.Result esc = Selector.run(Fakes.keyboard(ESC), scr14, "T", List.of("a", "b"), BACK_QUIT, Style.PLAIN);
        Selector.Result ignored = Selector.run(Fakes.keyboard(OTHER, c('z'), CTRL_C), new Fakes.FakeScreen(80, 24),
                "T", List.of("a", "b"), NONE, Style.PLAIN);
        check("SL14", esc instanceof Selector.Back && ignored instanceof Selector.Abort
                && scr14.out.toString().endsWith(Selector.SHOW));

        // SL15: loop: a typed key returns its character and restores the cursor
        Fakes.FakeScreen scr15 = new Fakes.FakeScreen(80, 24);
        Selector.Result r15 = Selector.run(Fakes.keyboard(c('m')), scr15, "T", List.of("a", "b"), TYPING, Style.PLAIN);
        check("SL15", r15.equals(new Selector.Typed('m')) && scr15.out.toString().endsWith(Selector.SHOW));

        // SL16: pick() uses the selector when present and maps its results
        List<Pick.Option> opts = List.of(Pick.Option.of("length"), Pick.Option.of("mass"), Pick.Option.of("area"));
        Pick.Result p1 = pick(opts, List.of(), List.of(new Selector.Picked(2)), true, null);
        Pick.Result p2 = pick(opts, List.of(), List.of(new Selector.Back()), true, null);
        Pick.Result p3 = pick(opts, List.of(), List.of(new Selector.Quit()), true, null);
        Pick.Result p4 = pick(opts, List.of(), List.of(new Selector.Abort()), true, null);
        check("SL16", p1.equals(new Pick.Chosen(2)) && p2 instanceof Pick.Back && p3 instanceof Pick.Quit
                && p4 instanceof Pick.Eof);

        // SL17: pick(): a typed name or number selects it
        Pick.Result n17 = pick(opts, List.of(""), List.of(new Selector.Typed('2')), true, null);
        Pick.Result s17 = pick(opts, List.of("ass"), List.of(new Selector.Typed('m')), true, null);
        check("SL17", n17.equals(new Pick.Chosen(1)) && s17.equals(new Pick.Chosen(1)));

        // SL18: pick(): a typed one-line command runs and the list comes back
        List<String> ran18 = new ArrayList<>();
        Fakes.FakeIo io18 = new Fakes.FakeIo(List.of("00 cm in"),
                List.of(new Selector.Typed('1'), new Selector.Picked(0)));
        Pick.Result r18 = Pick.pick(io18, "T", opts, true, true, false, line -> ran18.add(line));
        check("SL18", r18.equals(new Pick.Chosen(0)) && ran18.equals(List.of("100 cm in")) && io18.selectCalls == 2);

        // SL19: pick(): an unknown typed word is an error and the list comes back
        Fakes.FakeIo io19 = new Fakes.FakeIo(List.of("yz"), List.of(new Selector.Typed('x'), new Selector.Picked(0)));
        Pick.Result r19 = Pick.pick(io19, "T", opts, true, true, false, null);
        check("SL19", r19.equals(new Pick.Chosen(0)) && io19.selectCalls == 2
                && has(io19.out.toString(), "Error [UNKNOWN_COMMAND]: Pick one from the list"));

        // SL20: pick(): b, q and Esc act at once, with no prompt line
        Fakes.FakeIo io20a = new Fakes.FakeIo(List.of(), List.of(new Selector.Back()));
        Fakes.FakeIo io20b = new Fakes.FakeIo(List.of(), List.of(new Selector.Quit()));
        check("SL20", Pick.pick(io20a, "T", opts, true, true, false, null) instanceof Pick.Back && io20a.readCalls == 0
                && Pick.pick(io20b, "T", opts, true, true, false, null) instanceof Pick.Quit && io20b.readCalls == 0);

        // SL21: pick(): without a selector (pipes) the numbered list works as before
        Fakes.FakeIo io21 = new Fakes.FakeIo(List.of("2"), null);
        boolean number = Pick.pick(io21, "T", opts, true, true, false, null).equals(new Pick.Chosen(1))
                && has(io21.out.toString(), "  1) length\n  2) mass\n  3) area\n");
        boolean words = pick(opts, List.of("back"), null, true, null) instanceof Pick.Back
                && pick(opts, List.of("QUIT"), null, true, null) instanceof Pick.Quit
                && pick(opts, List.of(), null, true, null) instanceof Pick.Eof
                && pick(opts, List.of("AREA"), null, true, null).equals(new Pick.Chosen(2));
        Fakes.FakeIo io21z = new Fakes.FakeIo(List.of("0"), null);
        boolean zero = Pick.pick(io21z, "Menu", List.of(Pick.Option.of("A"), Pick.Option.of("B"), Pick.Option.of("Exit")),
                false, true, true, null).equals(new Pick.Chosen(2)) && has(io21z.out.toString(), "  0) Exit");
        Fakes.FakeIo io21b = new Fakes.FakeIo(List.of("back", "1"), null); // back not offered: an error, then 1
        boolean noBack = Pick.pick(io21b, "T", opts, false, true, false, null).equals(new Pick.Chosen(0))
                && has(io21b.out.toString(), "Error [UNKNOWN_COMMAND]");
        check("SL21", number && words && zero && noBack);

        // X2: lines never wider than the terminal; the window shrinks; erase moves up by the drawn count
        List<String> many = new ArrayList<>();
        for (int i = 0; i < 30; i++) many.add("label number " + i + " with some quite long text");
        int window = Selector.windowSize(30, 8);
        List<String> lines = Selector.render("A very long title that exceeds the width", many, new State(), ALL, 20, window,
                Style.PLAIN);
        boolean narrow = lines.stream().allMatch(l -> l.codePointCount(0, l.length()) <= 19);
        Fakes.FakeScreen scr = new Fakes.FakeScreen(20, 8);
        Selector.run(Fakes.keyboard(DOWN, ENTER), scr, "T", many, ALL, Style.PLAIN);
        check("X2", narrow && window == 5 && lines.size() == window + 2 && lines.size() < 8
                && Selector.erase(7).startsWith("\u001b[7A") && has(scr.out.toString(), "\u001b[7A"));

        // X3: raw terminal bytes become keys
        check("X3", key(0x1B, '[', 'A') == Kind.UP && key(0x1B, '[', 'B') == Kind.DOWN && key(0x1B) == Kind.ESC
                && key(0x1B, '[', 'H') == Kind.HOME && key(0x1B, 'O', 'F') == Kind.END
                && key(0x1B, '[', '5', '~') == Kind.PGUP && key(0x1B, '[', '6', '~') == Kind.PGDN
                && key(0x1B, '[', '1', ';', '5', 'A') == Kind.UP
                && key(3) == Kind.CTRL_C && key(4) == Kind.CTRL_D && key(13) == Kind.ENTER && key(1) == Kind.OTHER
                && key(-1) == Kind.CTRL_D && key('a') == Kind.CHAR
                && parse(0xC3, 0xA9).equals(Key.ch(0xE9)) && parse(0xE2, 0x9D, 0xAF).equals(Key.ch(0x276F)));

        for (int i = 1; i <= 21; i++) {
            if (!ran.contains("SL" + i)) {
                System.out.println("MISSING SL" + i);
                failed++;
            }
        }
        System.out.println("selector tests: " + ran.size() + " ran (SL1-SL21 + X2 + X3), " + failed + " failed");
        if (failed > 0) System.exit(1);
    }

    /** Runs pick() over a fake Io; selector results are scripted (null → plain numbered list). */
    private static Pick.Result pick(List<Pick.Option> opts, List<String> lines, List<Selector.Result> picks,
                                    boolean back, Pick.LineHandler handler) {
        return Pick.pick(new Fakes.FakeIo(lines, picks), "T", opts, back, true, false, handler);
    }

    private static Key parse(int... bytes) {
        int[] i = {1};
        return KeyParser.parse(bytes[0], () -> i[0] < bytes.length ? bytes[i[0]++] : -1);
    }

    private static Kind key(int... bytes) {
        return parse(bytes).kind();
    }
}