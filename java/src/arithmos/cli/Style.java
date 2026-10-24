package arithmos.cli;

/** Colours. Plain for pipes and tests, off with NO_COLOR=1. The "❯" pointer is never colour-only. */
public record Style(boolean color) {
    public static final Style PLAIN = new Style(false);

    public String bold(String s) { return wrap("1", s); }
    public String dim(String s) { return wrap("2", s); }
    public String reverse(String s) { return wrap("7", s); }
    public String green(String s) { return wrap("32", s); }
    public String red(String s) { return wrap("31", s); }

    private String wrap(String code, String s) {
        return color ? "\u001b[" + code + "m" + s + "\u001b[0m" : s;
    }
}