package arithmos.cli;

import arithmos.calculator.Calculator;
import arithmos.converter.Converter;
import arithmos.converter.Units;
import arithmos.programmer.Base;
import arithmos.programmer.Programmer;
import arithmos.shared.ArithmosError;
import arithmos.shared.FormatNumber;
import java.util.List;
import java.util.function.Supplier;

/** Tool bindings and prompt loops. Turns engine values into text and errors into "Error [CODE]: …". */
public final class Tools {
    private Tools() {}

    /** How a prompt loop ended. */
    public enum Exit { BACK, QUIT, EOF }

    @FunctionalInterface
    public interface LineEval {
        List<String> eval(String line);
    }

    // ───────────── engine → text ─────────────

    public static List<String> standardLines(Calculator calc, String line) {
        return List.of(FormatNumber.format(calc.evaluate(line)));
    }

    public static List<String> programmerLines(Programmer prog, String line) {
        return switch (prog.run(line)) {
            case Programmer.Outcome.Value v -> List.of(
                    "HEX: " + Base.HEX.render(v.value()),
                    "DEC: " + Base.DEC.render(v.value()),
                    "OCT: " + Base.OCT.render(v.value()),
                    "BIN: " + Base.BIN.render(v.value()));
            case Programmer.Outcome.Converted c -> List.of(c.text());
            case Programmer.Outcome.BaseChanged b -> List.of("Input base: " + b.base().id); // R32
        };
    }

    public static String errorLine(ArithmosError e) {
        return "Error [" + e.code() + "]: " + e.getMessage();
    }

    // ───────────── prompt loop ─────────────

    /**
     * The calculators' loop: help/?, back, quit, blank lines ignored, EOF exits cleanly, every error
     * printed as "Error [CODE]: message". Unexpected exceptions never crash the program.
     */
    static Exit loop(Io io, String prompt, String help, LineEval eval) {
        while (true) {
            String line = io.readLine(prompt);
            if (line == null) {
                io.write("\n");
                return Exit.EOF;
            }
            line = line.trim();
            if (line.isEmpty()) continue;
            String lower = line.toLowerCase(java.util.Locale.ROOT);
            if (lower.equals("help") || lower.equals("?")) {
                io.write(help);
                continue;
            }
            if (lower.equals("back")) return Exit.BACK;
            if (lower.equals("quit")) return Exit.QUIT;
            final String input = line;
            show(io, () -> eval.eval(input));
        }
    }

    /** Prints the lines an action returns, or its error. */
    static void show(Io io, Supplier<List<String>> action) {
        try {
            for (String l : action.get()) io.write(l + "\n");
        } catch (ArithmosError e) {
            io.write(io.style().red(errorLine(e)) + "\n");
        } catch (RuntimeException | StackOverflowError e) {
            io.write(io.style().red("Error [INTERNAL]: " + e) + "\n");
        }
    }

    // ───────────── the three tools ─────────────

    private static final String STANDARD_HELP = """
            Standard Calculator
              Numbers     12  12.5  .5  5.
              Operators   + - * / ^      (^ is right-associative, -2^2 = -4)
              Percent     50%   200 + 10%   20% of 150
              Functions   sqrt(x)  abs(x)
              Previous    ans
              Commands    help (or ?)  back  quit
            """;

    private static final String PROGRAMMER_HELP = """
            Programmer Calculator (64-bit signed)
              <value>                   show in HEX, DEC, OCT, BIN (prefixes 0b 0o 0d 0x)
              base bin|oct|dec|hex      set the input base
              [convert] <value> <from> <to>    e.g. 255 dec hex
              <a> AND|OR|XOR <b>        NOT <a>
              <a> << <n>   <a> >> <n>   <a> >>> <n>     n is decimal, 0-63
              Commands    help (or ?)  back  quit
            """;

    private static final String CONVERTER_HELP = """
            Unit Converter
              <value>                   convert using the units chosen above
              [convert] <value> <from> <to|all>    e.g. 100 cm in
              list   list <category>
              Commands    help (or ?)  back  quit
            """;

    public static Exit standard(Io io) {
        Calculator calc = new Calculator();
        io.write("Standard Calculator. Type an expression, help for commands, back to return.\n");
        return loop(io, "standard> ", STANDARD_HELP, line -> standardLines(calc, line));
    }

    public static Exit programmer(Io io) {
        Programmer prog = new Programmer();
        io.write("Programmer Calculator. Type a number or a command, help for commands, back to return.\n");
        return loop(io, "programmer> ", PROGRAMMER_HELP, line -> programmerLines(prog, line));
    }

    /** Guided flow: category → from → to → values. back steps back one stage. */
    public static Exit converter(Io io) {
        Converter conv = new Converter();
        // One-line commands are accepted at every stage; the list comes back afterwards.
        Pick.LineHandler cmd = line -> {
            if (!Converter.looksLikeCommand(line)) return false;
            show(io, () -> conv.run(line));
            return true;
        };

        int stage = 0; // 0 category, 1 from, 2 to, 3 values
        Units.Category cat = null;
        Units.Found from = null;
        Units.Found to = null;
        while (true) {
            switch (stage) {
                case 0, 1, 2 -> {
                    Pick.Result r = switch (stage) {
                        case 0 -> Pick.pick(io, "Unit Converter — choose a category",
                                categoryOptions(), true, true, false, cmd);
                        case 1 -> Pick.pick(io, cap(cat.name()) + " — convert from",
                                unitOptions(cat), true, true, false, cmd);
                        default -> Pick.pick(io, cap(cat.name()) + " — convert from "
                                + from.unit().symbol() + " to", unitOptions(cat), true, true, false, cmd);
                    };
                    if (r instanceof Pick.Chosen c) {
                        if (stage == 0) cat = Units.CATEGORIES.get(c.index());
                        else if (stage == 1) from = new Units.Found(cat, cat.units().get(c.index()));
                        else to = new Units.Found(cat, cat.units().get(c.index()));
                        stage++;
                    } else if (r instanceof Pick.Back) {
                        if (stage == 0) return Exit.BACK; // from the first stage: main menu
                        stage--;
                    } else {
                        return r instanceof Pick.Quit ? Exit.QUIT : Exit.EOF;
                    }
                }
                default -> {
                    final Units.Found f = from;
                    final Units.Found t = to;
                    io.write("Type a value (for example 100), a one-line command, back or quit.\n");
                    // The values prompt shows the units: converter (m → yd)>
                    Exit ex = loop(io, "converter (" + f.unit().symbol() + " → " + t.unit().symbol() + ")> ",
                            CONVERTER_HELP,
                            line -> Converter.looksLikeCommand(line)
                                    ? conv.run(line)
                                    : List.of(conv.guided(line, f, t)));
                    if (ex == Exit.BACK) stage = 2; else return ex;
                }
            }
        }
    }

    private static List<Pick.Option> categoryOptions() {
        return Units.CATEGORIES.stream().map(c -> Pick.Option.of(c.name())).toList();
    }

    /** Unit rows read "m — metre"; the symbol or the name selects them. */
    private static List<Pick.Option> unitOptions(Units.Category cat) {
        return cat.units().stream()
                .map(u -> Pick.Option.of(u.symbol() + " — " + u.name(), u.symbol(), u.name()))
                .toList();
    }

    private static String cap(String s) {
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }
}