package arithmos.cli;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;

/** The real Io: UTF-8 stdout, stdin lines, and the selector when a Terminal is present. */
public final class ConsoleIo implements Io {
    private final PrintStream out;
    private final Style style;
    private final Terminal terminal; // null → numbered lists

    public ConsoleIo(PrintStream out, Style style, Terminal terminal) {
        this.out = out;
        this.style = style;
        this.terminal = terminal;
    }

    @Override
    public void write(String text) {
        out.print(text);
        out.flush();
    }

    @Override
    public String readLine(String prompt) {
        write(prompt);
        return readLine(System.in);
    }

    @Override
    public Style style() {
        return style;
    }

    @Override
    public SelectFn select() {
        if (terminal == null) return null;
        Selector.Screen screen = terminal.screen(out);
        return (title, labels, options) -> {
            terminal.rawOn();
            try {
                return Selector.run(terminal.keyboard(), screen, title, labels, options, style);
            } finally {
                terminal.rawOff(); // the terminal is never left raw
            }
        };
    }

    /**
     * Reads bytes up to a newline and decodes them as UTF-8. One reader on System.in only, so raw key
     * reads and line reads never fight over a second buffer. Null at end of input.
     */
    static String readLine(InputStream in) {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        try {
            int b;
            while ((b = in.read()) != -1) {
                if (b == '\n') return decode(buf);
                buf.write(b);
            }
        } catch (IOException e) {
            // treat as end of input
        }
        return buf.size() == 0 ? null : decode(buf);
    }

    private static String decode(ByteArrayOutputStream buf) {
        String s = new String(buf.toByteArray(), StandardCharsets.UTF_8);
        return s.endsWith("\r") ? s.substring(0, s.length() - 1) : s;
    }
}