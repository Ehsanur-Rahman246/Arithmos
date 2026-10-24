package arithmos.cli;

import arithmos.cli.Selector.Key;
import arithmos.cli.Selector.Kind;
import java.io.Console;
import java.io.IOException;
import java.io.PrintStream;
import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.SymbolLookup;
import java.lang.foreign.ValueLayout;
import java.lang.invoke.MethodHandle;
import java.nio.charset.StandardCharsets;

/**
 * A real terminal: detection, raw key reading, size. Java has no raw-mode API, so:
 * - POSIX: {@code stty} on /dev/tty (raw only while the selector is on screen).
 * - Windows: the foreign-function API calls kernel32 (VT mode, UTF-8, window size) and
 *   ucrtbase {@code _getwch} (one key at a time). Needs --enable-native-access=ALL-UNNAMED.
 * {@link #open()} returns null when anything is missing; the caller then uses numbered lists.
 */
public final class Terminal {
    private final Win win;            // null on POSIX
    private String savedStty;         // POSIX: settings to restore; null while not raw
    private int[] sizeCache;
    private long sizeStamp;

    private Terminal(Win win) {
        this.win = win;
    }

    /** Null unless stdin and stdout are a terminal and ARITHMOS_PLAIN is not 1 (spec §2.1). */
    public static Terminal open() {
        if ("1".equals(System.getenv("ARITHMOS_PLAIN"))) return null;
        Console console = System.console();
        if (console == null || !console.isTerminal()) return null;
        try {
            Terminal t;
            if (System.getProperty("os.name", "").toLowerCase().contains("win")) {
                t = new Terminal(new Win());
            } else {
                if ("dumb".equals(System.getenv("TERM")) || stty("-g") == null) return null;
                t = new Terminal(null);
            }
            Runtime.getRuntime().addShutdownHook(new Thread(t::close)); // never leave the tty raw
            return t;
        } catch (Throwable e) {
            return null;
        }
    }

    // ───────────── raw mode ─────────────

    /** Raw is on only while the selector is on screen and is restored in a finally (and a hook). */
    public void rawOn() {
        if (win != null) return; // _getwch needs no mode change
        savedStty = stty("-g");
        stty("-icanon -echo -isig min 1 time 0"); // Ctrl-C then arrives as byte 3
    }

    public void rawOff() {
        if (win == null && savedStty != null) {
            stty(savedStty);
            savedStty = null;
        }
    }

    /** Idempotent: restores the terminal (and, on Windows, the console mode and code pages). */
    public void close() {
        rawOff();
        if (win != null) win.restore();
    }

    private static String stty(String args) {
        try {
            Process p = new ProcessBuilder("sh", "-c", "stty " + args + " < /dev/tty")
                    .redirectErrorStream(true).start();
            String out = new String(p.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
            return p.waitFor() == 0 ? out : null;
        } catch (IOException e) {
            return null;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return null;
        }
    }

    // ───────────── keys ─────────────

    public Selector.Keyboard keyboard() {
        if (win != null) return win::readKey;
        return () -> KeyParser.parse(readByte(), Terminal::pollByte);
    }

    private static int readByte() {
        try {
            return System.in.read();
        } catch (IOException e) {
            return -1;
        }
    }

    /** A follow-up byte of an escape sequence: waits up to 50 ms, else -1 (so a lone Esc is Esc). */
    private static int pollByte() {
        try {
            for (int i = 0; i < 10; i++) {
                if (System.in.available() > 0) return System.in.read();
                Thread.sleep(5);
            }
        } catch (IOException e) {
            // fall through
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        return -1;
    }

    // ───────────── screen ─────────────

    public Selector.Screen screen(PrintStream out) {
        return new Selector.Screen() {
            @Override public void write(String text) { out.print(text); out.flush(); }
            @Override public int width() { return size()[0]; }
            @Override public int height() { return size()[1]; }
        };
    }

    /** Measured on a redraw; cached for 150 ms so one redraw is one measurement. */
    private int[] size() {
        long now = System.nanoTime();
        if (sizeCache == null || now - sizeStamp > 150_000_000L) {
            sizeCache = win != null ? win.size() : posixSize();
            sizeStamp = now;
        }
        return sizeCache;
    }

    private static int[] posixSize() {
        String s = stty("size"); // "rows cols"
        if (s != null) {
            String[] p = s.split("\\s+");
            try {
                if (p.length == 2) return new int[] {Integer.parseInt(p[1]), Integer.parseInt(p[0])};
            } catch (NumberFormatException e) {
                // fall through
            }
        }
        return new int[] {80, 24};
    }

    // ───────────── Windows ─────────────

    private static final class Win {
        private final MethodHandle getMode, setMode, getInfo, setOutCp, setInCp, getwch;
        private final MemorySegment hOut;
        private final int oldMode, oldOutCp, oldInCp;
        private boolean restored;

        Win() throws Throwable {
            Linker linker = Linker.nativeLinker();
            SymbolLookup k32 = SymbolLookup.libraryLookup("kernel32", Arena.global());
            SymbolLookup crt = SymbolLookup.libraryLookup("ucrtbase", Arena.global());
            var I = ValueLayout.JAVA_INT;
            var A = ValueLayout.ADDRESS;

            MethodHandle getStdHandle = linker.downcallHandle(
                    k32.find("GetStdHandle").orElseThrow(), FunctionDescriptor.of(A, I));
            getMode = linker.downcallHandle(
                    k32.find("GetConsoleMode").orElseThrow(), FunctionDescriptor.of(I, A, A));
            setMode = linker.downcallHandle(
                    k32.find("SetConsoleMode").orElseThrow(), FunctionDescriptor.of(I, A, I));
            getInfo = linker.downcallHandle(
                    k32.find("GetConsoleScreenBufferInfo").orElseThrow(), FunctionDescriptor.of(I, A, A));
            MethodHandle getOutCp = linker.downcallHandle(
                    k32.find("GetConsoleOutputCP").orElseThrow(), FunctionDescriptor.of(I));
            setOutCp = linker.downcallHandle(
                    k32.find("SetConsoleOutputCP").orElseThrow(), FunctionDescriptor.of(I, I));
            MethodHandle getInCp = linker.downcallHandle(
                    k32.find("GetConsoleCP").orElseThrow(), FunctionDescriptor.of(I));
            setInCp = linker.downcallHandle(
                    k32.find("SetConsoleCP").orElseThrow(), FunctionDescriptor.of(I, I));
            getwch = linker.downcallHandle(
                    crt.find("_getwch").orElseThrow(), FunctionDescriptor.of(I));

            hOut = (MemorySegment) getStdHandle.invoke(-11); // STD_OUTPUT_HANDLE
            int mode;
            try (Arena a = Arena.ofConfined()) {
                MemorySegment p = a.allocate(I);
                if ((int) getMode.invoke(hOut, p) == 0) throw new IllegalStateException("not a console");
                mode = p.get(I, 0);
            }
            oldMode = mode;
            // ENABLE_PROCESSED_OUTPUT (1) | ENABLE_VIRTUAL_TERMINAL_PROCESSING (4): ANSI escapes.
            if ((int) setMode.invoke(hOut, mode | 5) == 0) throw new IllegalStateException("no VT mode");
            oldOutCp = (int) getOutCp.invoke();
            oldInCp = (int) getInCp.invoke();
            setOutCp.invoke(65001); // UTF-8 for ❯ ✔ → —
            setInCp.invoke(65001);
        }

        void restore() {
            if (restored) return;
            restored = true;
            try {
                setMode.invoke(hOut, oldMode);
                setOutCp.invoke(oldOutCp);
                setInCp.invoke(oldInCp);
            } catch (Throwable e) {
                // nothing more can be done at exit
            }
        }

        /** The visible window (not the buffer), from CONSOLE_SCREEN_BUFFER_INFO.srWindow. */
        int[] size() {
            try (Arena a = Arena.ofConfined()) {
                MemorySegment info = a.allocate(22, 2);
                if ((int) getInfo.invoke(hOut, info) != 0) {
                    int w = info.get(ValueLayout.JAVA_SHORT, 14) - info.get(ValueLayout.JAVA_SHORT, 10) + 1;
                    int h = info.get(ValueLayout.JAVA_SHORT, 16) - info.get(ValueLayout.JAVA_SHORT, 12) + 1;
                    return new int[] {w, h};
                }
            } catch (Throwable e) {
                // fall through
            }
            return new int[] {80, 24};
        }

        private int wch() {
            try {
                return (int) getwch.invoke();
            } catch (Throwable e) {
                return -1;
            }
        }

        Key readKey() {
            int c = wch();
            if (c < 0) return Key.of(Kind.CTRL_D);
            if (c == 0 || c == 0xE0) { // extended key: a second code follows
                return switch (wch()) {
                    case 72 -> Key.of(Kind.UP);
                    case 80 -> Key.of(Kind.DOWN);
                    case 71 -> Key.of(Kind.HOME);
                    case 79 -> Key.of(Kind.END);
                    case 73 -> Key.of(Kind.PGUP);
                    case 81 -> Key.of(Kind.PGDN);
                    default -> Key.of(Kind.OTHER);
                };
            }
            return switch (c) {
                case 3 -> Key.of(Kind.CTRL_C);
                case 4, 26 -> Key.of(Kind.CTRL_D); // Ctrl-D / Ctrl-Z
                case 13 -> Key.of(Kind.ENTER);
                case 27 -> Key.of(Kind.ESC);
                default -> c < 32 ? Key.of(Kind.OTHER) : Key.ch(c);
            };
        }
    }
}