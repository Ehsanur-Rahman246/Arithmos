package arithmos.cli;

import java.util.List;

/**
 * pick(): one question, many answers. On a real terminal it is the arrow-key selector; everywhere
 * else it is a numbered list answered by typing a number, a name or a symbol (spec §2.1).
 */
public final class Pick {
    private Pick() {}

    /** A row: the label shown, plus the extra words that select it (a symbol, a short name). */
    public record Option(String label, List<String> keys) {
        public static Option of(String label, String... keys) {
            return new Option(label, List.of(keys));
        }
    }

    public sealed interface Result {}
    public record Chosen(int index) implements Result {}
    public record Back() implements Result {}
    public record Quit() implements Result {}
    public record Eof() implements Result {}

    /** Runs a typed line as a one-line command. Returns false when the line is not one. */
    @FunctionalInterface
    public interface LineHandler {
        boolean handle(String line);
    }

    /**
     * @param back     whether going back is offered (Esc / b at the selector, "back" when typed)
     * @param quit     whether q is offered at the selector ("quit" typed is always accepted)
     * @param zeroLast the last option is numbered 0 in the plain list (the main menu's "0) Exit")
     * @param handler  runs one-line commands typed instead of an answer; may be null
     */
    public static Result pick(Io io, String title, List<Option> options, boolean back, boolean quit,
                              boolean zeroLast, LineHandler handler) {
        List<String> labels = options.stream().map(Option::label).toList();
        boolean showList = true;
        while (true) {
            String line;
            Io.SelectFn selector = io.select();
            if (selector != null) {
                // Real terminal: b, q and Esc act at once, with no prompt line.
                Selector.Result r = selector.select(title, labels, new Selector.Options(back, quit, true));
                if (r instanceof Selector.Picked p) return new Chosen(p.index());
                if (r instanceof Selector.Back) return new Back();
                if (r instanceof Selector.Quit) return new Quit();
                if (r instanceof Selector.Abort) return new Eof();
                // Any other printable key: the prompt shows the key, the rest of the line is read.
                String key = new String(Character.toChars(((Selector.Typed) r).ch()));
                String rest = io.readLine("> " + key);
                if (rest == null) return new Eof();
                line = key + rest;
            } else {
                // Pipes, files, tests, ARITHMOS_PLAIN=1: the numbered list.
                if (showList) {
                    io.write(plainList(title, labels, zeroLast));
                    showList = false;
                }
                line = io.readLine("> ");
                if (line == null) {
                    io.write("\n");
                    return new Eof();
                }
            }

            line = line.trim();
            if (line.isEmpty()) continue;                       // blank lines are ignored
            String lower = line.toLowerCase(java.util.Locale.ROOT);
            if (lower.equals("help") || lower.equals("?")) {
                io.write("Type a number, a name or a symbol from the list" + (back ? ", back" : "")
                        + " or quit.\n");
                continue;
            }
            if (lower.equals("quit")) return new Quit();
            if (lower.equals("back") && back) return new Back();

            int index = match(options, line, zeroLast);
            if (index >= 0) return new Chosen(index);

            showList = true; // after an error or a one-line command the list comes back
            if (handler != null && handler.handle(line)) continue;
            io.write(io.style().red("Error [UNKNOWN_COMMAND]: Pick one from the list") + "\n");
        }
    }

    /** Plain list rows: two spaces, the number, ")", a space, the label (R28). */
    static String plainList(String title, List<String> labels, boolean zeroLast) {
        StringBuilder sb = new StringBuilder(title).append('\n');
        for (int i = 0; i < labels.size(); i++) {
            sb.append("  ").append(numberOf(i, labels.size(), zeroLast)).append(") ")
              .append(labels.get(i)).append('\n');
        }
        return sb.toString();
    }

    private static int numberOf(int i, int count, boolean zeroLast) {
        return zeroLast && i == count - 1 ? 0 : i + 1;
    }

    /** A typed number, label, or key (symbol/name), case-insensitive. -1 if nothing matches. */
    private static int match(List<Option> options, String line, boolean zeroLast) {
        if (line.length() <= 6 && line.chars().allMatch(Character::isDigit)) {
            int n = Integer.parseInt(line);
            for (int i = 0; i < options.size(); i++) {
                if (numberOf(i, options.size(), zeroLast) == n) return i;
            }
            return -1;
        }
        for (int i = 0; i < options.size(); i++) {
            Option o = options.get(i);
            if (o.label().equalsIgnoreCase(line)) return i;
            for (String k : o.keys()) {
                if (k.equalsIgnoreCase(line)) return i;
            }
        }
        return -1;
    }
}