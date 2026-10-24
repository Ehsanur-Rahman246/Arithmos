package arithmos.cli;

import java.util.List;

/**
 * The only door to the terminal. Everything above the CLI layer is pure; everything in the CLI talks
 * through this small interface, so tests can script it.
 */
public interface Io {
    void write(String text);

    /** Prints the prompt and reads one line; null at end of input. */
    String readLine(String prompt);

    Style style();

    /** Non-null on a real terminal only: runs the arrow-key selector for one question. */
    SelectFn select();

    @FunctionalInterface
    interface SelectFn {
        Selector.Result select(String title, List<String> labels, Selector.Options options);
    }
}