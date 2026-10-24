package arithmos.cli;

import arithmos.calculator.Calculator;
import arithmos.converter.Converter;
import arithmos.programmer.Programmer;
import arithmos.shared.ArithmosError;
import java.io.PrintStream;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

/** The main menu and one-shot mode (the only layer, with Tools, that does I/O). */
public final class Cli {
    private Cli() {}

    private static final String USAGE = """
            Usage: arithmos                          interactive menu
                   arithmos std <expression>         e.g. std "20% of 150"
                   arithmos prog <command>           e.g. prog 0xFF AND 0x0F
                   arithmos convert <value> <from> <to>
                   arithmos list [category]""";

    /** The menu loop. Returns the process exit status (always 0 interactively). */
    public static int interactive(Io io) {
        List<Pick.Option> menu = List.of(
                Pick.Option.of("Standard Calculator", "standard", "std"),
                Pick.Option.of("Programmer Calculator", "programmer", "prog"),
                Pick.Option.of("Unit Converter", "converter", "unit converter"),
                Pick.Option.of("Exit", "exit"));
        while (true) {
            // No back at the main menu; the last row is numbered 0 in the plain list.
            Pick.Result r = Pick.pick(io, "Arithmos 1.0 — Core CLI", menu, false, true, true, null);
            if (!(r instanceof Pick.Chosen c) || c.index() == 3) return 0;
            Tools.Exit ex = switch (c.index()) {
                case 0 -> Tools.standard(io);
                case 1 -> Tools.programmer(io);
                default -> Tools.converter(io);
            };
            if (ex != Tools.Exit.BACK) return 0; // quit or end of input
        }
    }

    /**
     * One-shot mode. Results and --help go to stdout; Error lines and usage after bad input go to
     * stderr. Exit status 0 success, 1 an Error [CODE] result, 2 bad usage (R31).
     */
    public static int oneShot(String[] args, PrintStream out, PrintStream err) {
        String cmd = args[0].toLowerCase(Locale.ROOT); // the command word is case-insensitive
        String rest = String.join(" ", Arrays.copyOfRange(args, 1, args.length)).trim();
        try {
            List<String> lines;
            switch (cmd) {
                case "--help", "-h", "help" -> {
                    out.println(USAGE);
                    return 0;
                }
                case "std", "standard" -> {
                    if (rest.isEmpty()) return usage(err);
                    lines = Tools.standardLines(new Calculator(), rest);
                }
                case "prog", "programmer" -> {
                    if (rest.isEmpty()) return usage(err);
                    lines = Tools.programmerLines(new Programmer(), rest);
                }
                case "convert" -> {
                    if (rest.isEmpty()) return usage(err);
                    lines = new Converter().run("convert " + rest);
                }
                case "list" -> lines = new Converter().run(rest.isEmpty() ? "list" : "list " + rest);
                default -> {
                    return usage(err);
                }
            }
            lines.forEach(out::println);
            return 0;
        } catch (ArithmosError e) {
            err.println(Tools.errorLine(e));
            return 1;
        } catch (RuntimeException | StackOverflowError e) {
            err.println("Error [INTERNAL]: " + e);
            return 1;
        }
    }

    private static int usage(PrintStream err) {
        err.println(USAGE);
        return 2;
    }
}