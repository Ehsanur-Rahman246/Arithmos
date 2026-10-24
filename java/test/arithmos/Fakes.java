package arithmos;

import arithmos.cli.Io;
import arithmos.cli.Selector;
import arithmos.cli.Style;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Iterator;
import java.util.List;

/** Fake keyboard, screen and Io for the selector tests and the scripted CLI sessions. */
final class Fakes {
    private Fakes() {}

    /** Keys in order; the keyboard runs dry only if a test is wrong. */
    static Selector.Keyboard keyboard(Selector.Key... keys) {
        Iterator<Selector.Key> it = List.of(keys).iterator();
        return it::next;
    }

    static final class FakeScreen implements Selector.Screen {
        final StringBuilder out = new StringBuilder();
        final int width;
        final int height;

        FakeScreen(int width, int height) {
            this.width = width;
            this.height = height;
        }

        @Override public void write(String text) { out.append(text); }
        @Override public int width() { return width; }
        @Override public int height() { return height; }
    }

    /**
     * Scripted Io. {@code picks == null} → no selector (the numbered list). Otherwise each selector
     * call returns the next scripted result. Typed lines come from {@code lines}. readLine appends
     * the prompt to the output but does not echo the scripted answer.
     */
    static final class FakeIo implements Io {
        final Deque<String> lines = new ArrayDeque<>();
        final Deque<Selector.Result> picks;
        final StringBuilder out = new StringBuilder();
        int readCalls;
        int selectCalls;

        FakeIo(List<String> lines, List<Selector.Result> picks) {
            this.lines.addAll(lines);
            this.picks = picks == null ? null : new ArrayDeque<>(picks);
        }

        @Override public void write(String text) { out.append(text); }

        @Override public String readLine(String prompt) {
            readCalls++;
            out.append(prompt);
            return lines.pollFirst(); // null at the end = EOF
        }

        @Override public Style style() { return Style.PLAIN; }

        @Override public SelectFn select() {
            if (picks == null) return null;
            return (title, labels, options) -> {
                selectCalls++;
                return picks.removeFirst();
            };
        }
    }
}