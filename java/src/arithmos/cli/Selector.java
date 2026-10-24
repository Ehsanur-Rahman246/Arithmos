package arithmos.cli;

import java.util.ArrayList;
import java.util.List;

/**
 * The arrow-key selector, in the four layers of ARCHITECTURE.md:
 * 1. key handling (pure)   2. drawing (pure)   3. a draw/read loop over an injectable
 * keyboard and screen   4. pick() (see Pick.java) over an injectable Io.
 * Tests SL1–SL21 exercise these layers without a real terminal.
 */
public final class Selector {
    private Selector() {}

    // ───────────── Layer 1: keys (pure) ─────────────

    public enum Kind { UP, DOWN, HOME, END, PGUP, PGDN, ENTER, ESC, CTRL_C, CTRL_D, CHAR, OTHER }

    /** {@code ch} is the code point for CHAR keys, 0 otherwise. OTHER = ignored control keys. */
    public record Key(Kind kind, int ch) {
        public static Key of(Kind kind) { return new Key(kind, 0); }
        public static Key ch(int codePoint) { return new Key(Kind.CHAR, codePoint); }
    }

    /** Which extra keys are on offer for this question. */
    public record Options(boolean back, boolean quit, boolean typing) {}

    /** What the selector ended with. */
    public sealed interface Result {}
    public record Picked(int index) implements Result {}
    public record Back() implements Result {}
    public record Quit() implements Result {}
    /** Ctrl-C / Ctrl-D: end of input. */
    public record Abort() implements Result {}
    /** A printable key that starts a typed line; carries the character. */
    public record Typed(int ch) implements Result {}

    /** Mutable cursor: selected row and first visible row. */
    public static final class State {
        public int index;
        public int top;
    }

    public static final int MAX_WINDOW = 10;

    /** Rows shown at once: at most 10, never more than fits (title + hint + one spare line). */
    public static int windowSize(int count, int terminalHeight) {
        return Math.max(1, Math.min(Math.min(MAX_WINDOW, count), terminalHeight - 3));
    }

    /**
     * Applies one key. Moves the cursor (↑↓ wrap, Home/End, PgUp/PgDn) or returns the ending Result;
     * null means "keep going". Esc, b and q only act when offered. Any other printable key (not
     * space, not a control key) ends the selector as Typed when typing is on.
     */
    public static Result handle(State st, Key key, Options o, int count, int window) {
        switch (key.kind()) {
            case UP -> st.index = (st.index + count - 1) % count;
            case DOWN -> st.index = (st.index + 1) % count;
            case HOME -> st.index = 0;
            case END -> st.index = count - 1;
            case PGUP -> st.index = Math.max(0, st.index - window);
            case PGDN -> st.index = Math.min(count - 1, st.index + window);
            case ENTER -> { return new Picked(st.index); }
            case ESC -> { if (o.back()) return new Back(); }
            case CTRL_C, CTRL_D -> { return new Abort(); }
            case CHAR -> {
                int c = key.ch();
                if (c == 'b' && o.back()) return new Back();
                if (c == 'q' && o.quit()) return new Quit();
                if (o.typing() && c > ' ' && !Character.isISOControl(c)) return new Typed(c);
            }
            default -> { } // OTHER: ignored
        }
        return null;
    }

    /** Keeps the selected row inside the visible window. */
    public static void scroll(State st, int count, int window) {
        if (st.index < st.top) st.top = st.index;
        if (st.index >= st.top + window) st.top = st.index - window + 1;
        st.top = Math.max(0, Math.min(st.top, count - window));
    }

    // ───────────── Layer 2: drawing (pure) ─────────────

    /** The hint line lists only the keys on offer. */
    public static String hint(Options o) {
        StringBuilder h = new StringBuilder("↑↓ move · Enter select");
        if (o.back()) h.append(" · Esc/b back");
        if (o.quit()) h.append(" · q quit");
        if (o.typing()) h.append(" · or type");
        return h.toString();
    }

    /**
     * Draws the block as lines. Rule 6: one logical line is one screen line, so every line is at most
     * (width − 1) columns and longer ones end with "…". The selected row is a full reverse-video bar
     * with "❯"; without colour it is still marked by the pointer.
     */
    public static List<String> render(String title, List<String> labels, State st, Options o,
                                      int width, int window, Style style) {
        List<String> out = new ArrayList<>();
        out.add(style.bold(fit(title, width)));
        int longest = 0;
        for (String l : labels) longest = Math.max(longest, l.codePointCount(0, l.length()));
        int bar = Math.min(Math.max(1, width - 1), longest + 4);
        for (int i = st.top; i < st.top + window && i < labels.size(); i++) {
            boolean selected = i == st.index;
            String text = fit((selected ? "❯ " : "  ") + labels.get(i), width);
            out.add(selected ? style.reverse(pad(text, bar)) : text);
        }
        out.add(style.dim(fit(hint(o), width)));
        return out;
    }

    /** Cuts a line to at most width − 1 columns, ending with "…" when it was cut. */
    static String fit(String s, int width) {
        int max = width - 1;
        if (max < 1) return "";
        int n = s.codePointCount(0, s.length());
        if (n <= max) return s;
        return s.substring(0, s.offsetByCodePoints(0, max - 1)) + "…";
    }

    private static String pad(String s, int cols) {
        int n = s.codePointCount(0, s.length());
        return n >= cols ? s : s + " ".repeat(cols - n);
    }

    public static final String HIDE = "\u001b[?25l";
    public static final String SHOW = "\u001b[?25h";

    /** Moves the cursor up by the number of lines drawn and clears from there down. */
    public static String erase(int lines) {
        return "\u001b[" + lines + "A\r\u001b[J";
    }

    // ───────────── Layer 3: the draw/read loop ─────────────

    @FunctionalInterface
    public interface Keyboard {
        Key read();
    }

    public interface Screen {
        void write(String text);
        int width();
        int height();
    }

    /**
     * Draw, read a key, repeat. Size is measured on every redraw, so resizing works. When it ends,
     * the block is erased, a chosen row leaves "✔ title: label" behind, and the cursor is restored.
     */
    public static Result run(Keyboard kb, Screen scr, String title, List<String> labels,
                             Options o, Style style) {
        int count = labels.size();
        State st = new State();
        int drawn = 0;
        scr.write(HIDE);
        try {
            while (true) {
                int window = windowSize(count, scr.height());
                scroll(st, count, window);
                if (drawn > 0) scr.write(erase(drawn));
                List<String> lines = render(title, labels, st, o, scr.width(), window, style);
                StringBuilder block = new StringBuilder();
                for (String line : lines) block.append(line).append('\n');
                scr.write(block.toString());
                drawn = lines.size();

                Result r = handle(st, kb.read(), o, count, window);
                if (r != null) {
                    scr.write(erase(drawn));
                    if (r instanceof Picked p) {
                        scr.write(style.green("✔") + " " + title + ": " + labels.get(p.index()) + "\n");
                    }
                    return r;
                }
            }
        } finally {
            scr.write(SHOW); // the cursor always comes back
        }
    }
}