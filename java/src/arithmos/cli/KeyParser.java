package arithmos.cli;

import arithmos.cli.Selector.Key;
import arithmos.cli.Selector.Kind;

/** Turns raw terminal bytes (POSIX) into keys. Pure, so it is tested with plain byte arrays (X3). */
public final class KeyParser {
    private KeyParser() {}

    /** Supplies follow-up bytes of one key; returns -1 when nothing more arrives. */
    @FunctionalInterface
    public interface Source {
        int next();
    }

    public static Key parse(int b, Source src) {
        if (b < 0) return Key.of(Kind.CTRL_D);           // end of input
        if (b == 0x1B) return escape(src);
        if (b == 3) return Key.of(Kind.CTRL_C);
        if (b == 4) return Key.of(Kind.CTRL_D);
        if (b == 13 || b == 10) return Key.of(Kind.ENTER);
        if (b < 32 || b == 127) return Key.of(Kind.OTHER); // other control keys, Backspace
        if (b < 0x80) return Key.ch(b);

        // UTF-8: the lead byte says how many continuation bytes follow.
        int extra = b >= 0xF0 ? 3 : b >= 0xE0 ? 2 : b >= 0xC0 ? 1 : -1;
        if (extra < 0) return Key.of(Kind.OTHER);
        int cp = b & (0x3F >> extra);
        for (int i = 0; i < extra; i++) {
            int c = src.next();
            if (c < 0 || (c & 0xC0) != 0x80) return Key.of(Kind.OTHER);
            cp = (cp << 6) | (c & 0x3F);
        }
        return Key.ch(cp);
    }

    private static Key escape(Source src) {
        int c = src.next();
        if (c < 0) return Key.of(Kind.ESC);                // a lone Esc
        if (c != '[' && c != 'O') return Key.of(Kind.OTHER); // Alt+key
        StringBuilder params = new StringBuilder();
        int f = src.next();
        while (f >= 0x30 && f <= 0x3F) {                    // parameter bytes: digits and ';'
            params.append((char) f);
            f = src.next();
        }
        return switch (f) {
            case 'A' -> Key.of(Kind.UP);
            case 'B' -> Key.of(Kind.DOWN);
            case 'H' -> Key.of(Kind.HOME);
            case 'F' -> Key.of(Kind.END);
            case '~' -> switch (params.toString()) {
                case "1", "7" -> Key.of(Kind.HOME);
                case "4", "8" -> Key.of(Kind.END);
                case "5" -> Key.of(Kind.PGUP);
                case "6" -> Key.of(Kind.PGDN);
                default -> Key.of(Kind.OTHER);
            };
            default -> Key.of(Kind.OTHER);
        };
    }
}