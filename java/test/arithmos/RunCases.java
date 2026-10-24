package arithmos;

import arithmos.calculator.Calculator;
import arithmos.cli.Cli;
import arithmos.converter.Converter;
import arithmos.programmer.Base;
import arithmos.programmer.Programmer;
import arithmos.shared.ArithmosError;
import arithmos.shared.FormatNumber;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Runs the 175 shared cases from docs/release-1-cases.json, then the Java extras:
 * formatting boundaries, settled amendments, garbage input, scripted CLI sessions.
 * Asserts results and error CODES, never message text.
 * Usage: java -cp out:out-test arithmos.RunCases ../docs/release-1-cases.json
 */
public final class RunCases {
    private static int passed;
    private static int failed;

    private static void ok(boolean condition, String name) {
        if (condition) {
            passed++;
        } else {
            failed++;
            System.out.println("FAIL " + name);
        }
    }

    // ───────────── one tool session, like one run of the real prompt ─────────────

    private static final class Session {
        record Res(String code, String text, Map<String, String> fields, List<String> lines) {}

        private final String tool;
        private final Calculator calc = new Calculator();
        private final Programmer prog = new Programmer();
        private final Converter conv = new Converter();

        Session(String tool) {
            this.tool = tool;
        }

        Res run(String line) {
            try {
                return switch (tool) {
                    case "standard" -> {
                        String t = FormatNumber.format(calc.evaluate(line));
                        yield new Res(null, t, null, List.of(t));
                    }
                    case "programmer" -> switch (prog.run(line)) {
                        case Programmer.Outcome.Value v -> new Res(null, null, fields(v.value()), List.of());
                        case Programmer.Outcome.Converted c -> new Res(null, c.text(), null, List.of(c.text()));
                        case Programmer.Outcome.BaseChanged b -> new Res(null, b.base().id, null, List.of());
                    };
                    default -> {
                        List<String> ls = conv.run(line);
                        yield new Res(null, ls.size() == 1 ? ls.get(0) : null, null, ls);
                    }
                };
            } catch (ArithmosError e) {
                return new Res(e.code().name(), e.getMessage(), null, List.of());
            }
        }

        private static Map<String, String> fields(long v) {
            Map<String, String> m = new LinkedHashMap<>();
            m.put("HEX", Base.HEX.render(v));
            m.put("DEC", Base.DEC.render(v));
            m.put("OCT", Base.OCT.render(v));
            m.put("BIN", Base.BIN.render(v));
            return m;
        }
    }

    // ───────────── shared cases ─────────────

    public static void main(String[] args) throws Exception {
        String path = args.length > 0 ? args[0] : "../docs/release-1-cases.json";
        List<?> cases = (List<?>) Json.parse(Files.readString(Path.of(path)));
        ok(cases.size() == 175, "175 shared cases loaded, got " + cases.size());
        for (Object c : cases) runCase((Map<?, ?>) c);
        System.out.println("shared cases: " + passed + " checks passed, " + failed + " failed");

        extras();
        System.out.println("total: " + passed + " passed, " + failed + " failed");
        if (failed > 0) System.exit(1);
    }

    private static void runCase(Map<?, ?> c) {
        String id = (String) c.get("id");
        Session s = new Session((String) c.get("tool"));
        if (c.get("setup") instanceof List<?> setup) {            // lines run first, same session
            for (Object line : setup) s.run((String) line);
        }
        if (c.get("steps") instanceof List<?> steps) {            // multi-line session (S32, S33)
            int k = 1;
            for (Object o : steps) {
                Map<?, ?> step = (Map<?, ?>) o;
                check(id + "#" + k++, s.run((String) step.get("input")), step);
            }
        } else {
            check(id, s.run((String) c.get("input")), c);
        }
    }

    /** Exactly one of error / expected (string or object) / expectedContains is present. */
    private static void check(String name, Session.Res r, Map<?, ?> want) {
        if (want.get("error") != null) {
            ok(want.get("error").equals(r.code()), name + ": want error " + want.get("error") + ", got " + r.code());
            return;
        }
        if (r.code() != null) {
            ok(false, name + ": unexpected error " + r.code() + " (" + r.text() + ")");
            return;
        }
        Object expected = want.get("expected");
        if (expected instanceof String s) {
            ok(s.equals(r.text()), name + ": want " + s + ", got " + r.text());
        } else if (expected instanceof Map<?, ?> m) {
            boolean good = r.fields() != null;
            if (good) {
                for (Map.Entry<?, ?> e : m.entrySet()) {
                    if (!e.getValue().equals(r.fields().get(e.getKey()))) good = false;
                }
            }
            ok(good, name + ": want " + m + ", got " + r.fields());
        } else if (want.get("expectedContains") instanceof List<?> need) {
            ok(r.lines().containsAll(need), name + ": want lines " + need + ", got " + r.lines());
        } else {
            ok(false, name + ": case has no outcome");
        }
    }

    // ───────────── Java extras ─────────────

    private static void fmt(double x, String want) {
        String got;
        try { got = FormatNumber.format(x); } catch (ArithmosError e) { got = e.code().name(); }
        ok(want.equals(got), "format " + x + ": want " + want + ", got " + got);
    }

    private static void std(String input, String want) {
        Session.Res r = new Session("standard").run(input);
        ok(want.equals(r.code() != null ? r.code() : r.text()), "std '" + input + "': want " + want + ", got "
                + (r.code() != null ? r.code() : r.text()));
    }

    private static void prog(String input, String want, String... setup) {
        Session s = new Session("programmer");
        for (String line : setup) s.run(line);
        Session.Res r = s.run(input);
        String got = r.code() != null ? r.code() : r.fields() != null ? r.fields().get("DEC") : r.text();
        ok(want.equals(got), "prog '" + input + "': want " + want + ", got " + got);
    }

    private static void conv(String input, String want) {
        Session.Res r = new Session("converter").run(input);
        ok(want.equals(r.code() != null ? r.code() : r.text()), "conv '" + input + "': want " + want + ", got "
                + (r.code() != null ? r.code() : r.text()));
    }

    private static void extras() {
        // Number formatting boundaries (spec §2.3)
        fmt(1e15, "1e+15");
        fmt(999999999999999.0, "1e+15");            // rounds to 12 digits first, so 1e15 is scientific
        fmt(123456789012345.0, "123456789012000");
        fmt(1e-6, "0.000001");
        fmt(1e-7, "1e-7");
        fmt(100000000000.5, "100000000001");        // half away from zero (R10)
        fmt(-0.0, "0");
        fmt(0.1 + 0.2, "0.3");
        fmt(123456789012345678.0, "1.23456789012e+17");
        fmt(1.5e20, "1.5e+20");
        fmt(-1234.5, "-1234.5");
        fmt(Double.POSITIVE_INFINITY, "OVERFLOW");
        fmt(Double.NaN, "INVALID_EXPRESSION");

        // Settled amendments (docs/spec-amendments.md)
        std("200 + (10%)", "200.1");                // R1
        std("200 + 5 * 10%", "200.5");              // R2
        std("2^50%", "1.41421356237");              // R3
        std("50%%", "0.005");                       // R4
        std("5 of 10", "50");                       // R5
        std("ANS", "0");                            // R6
        std("1e5", "INVALID_EXPRESSION");           // R7
        std(".", "INVALID_EXPRESSION");             // R8
        std("5.5.5", "INVALID_EXPRESSION");         // R8
        std("10^-400", "0");                        // R9
        std("-0", "0");
        prog("NOT 0xFF", "-256");                   // R12
        prog("NOT -1", "0");                        // R12
        prog("1 << 0x3", "INVALID_SHIFT");          // R13
        prog("1 << 2.5", "INVALID_SHIFT");          // R13
        prog("-0x80", "-128");                      // R14
        prog("1<<3", "8");                          // R29
        prog("-8>>>1", "9223372036854775804");      // R29
        prog("0B", "11", "base hex");               // R30
        prog("0x", "INVALID_DIGIT");                // R30
        prog("A AND F", "10", "base hex");          // R11
        prog("DEC", "3564", "base hex");            // R11
        conv("convert 1e3 m cm", "INVALID_NUMBER"); // R16
        conv("convert " + "9".repeat(400) + " m cm", "OVERFLOW"); // R17
        conv("list foo", "UNKNOWN_COMMAND");        // R19
        for (String t : new String[] {"convert 0 k all", "convert -273.15 c all", "convert -459.67 f all"}) {
            ok(new Session("converter").run(t).code() == null, "R20 " + t); // exactly at the limit is allowed
        }
        conv("convert -459.67 f k", "0");           // the limit converts to exactly 0 K

        garbage();
        sessions();
    }

    /** Invalid input never crashes: only ArithmosError may come out of an engine. */
    private static void garbage() {
        String[] junk = {"", " ", "(((", ")))", "%", "sqrt", "sqrt(", "ans ans", "\u0000", "💥", "1 << ",
                "<< 1", "NOT", "NOT NOT", "convert", "convert 1", "list list list", "base", "- -", "..", "1 2 3 4 5",
                "9".repeat(5000), "(".repeat(100000), "-".repeat(100000) + "1", "0x" + "F".repeat(1000)};
        for (String tool : new String[] {"standard", "programmer", "converter"}) {
            for (String line : junk) {
                Session s = new Session(tool);
                try {
                    s.run(line);
                    ok(true, "");
                } catch (RuntimeException | StackOverflowError e) {
                    ok(false, "garbage crashed " + tool + " on '" + (line.length() > 20 ? line.substring(0, 20) : line)
                            + "': " + e);
                }
            }
        }
    }

    /** Whole sessions through the real menu and prompt loops, in numbered-list mode. */
    private static void sessions() {
        // Standard and programmer, with ans, help, back and quit.
        Fakes.FakeIo io1 = new Fakes.FakeIo(List.of("1", "2 + 3", "ans * 2", "10 / 0", "help", "back",
                "2", "5 AND 3", "base hex", "FF", "quit"), null);
        int status = Cli.interactive(io1);
        String o = io1.out.toString();
        ok(status == 0 && o.contains("5\n") && o.contains("10\n"), "session: standard");
        ok(o.contains("Error [DIV_BY_ZERO]"), "session: error line");
        ok(o.contains("DEC: 1\n") && o.contains("Input base: hex\n") && o.contains("DEC: 255\n"), "session: programmer");

        // Guided converter: category → from → to → value, then back, then a quit.
        Fakes.FakeIo io2 = new Fakes.FakeIo(List.of("3", "length", "m", "yd", "100", "back", "quit"), null);
        Cli.interactive(io2);
        ok(io2.out.toString().contains("100 m = 109.361329834 yd"), "session: guided converter");
        ok(io2.out.toString().contains("converter (m → yd)>"), "session: values prompt shows the units");

        // A one-line command typed at a picker runs, and the list comes back.
        Fakes.FakeIo io3 = new Fakes.FakeIo(List.of("3", "100 cm in", "foo", "0"), null);
        Cli.interactive(io3);
        ok(io3.out.toString().contains("39.3700787402"), "session: one-line command at a picker");
        ok(io3.out.toString().contains("Error [UNKNOWN_COMMAND]: Pick one from the list"), "session: pick error");

        // End of input exits cleanly.
        ok(Cli.interactive(new Fakes.FakeIo(List.of(), null)) == 0, "session: EOF at the menu");
        ok(Cli.interactive(new Fakes.FakeIo(List.of("2"), null)) == 0, "session: EOF in a tool");
    }
}