package arithmos.converter;

import arithmos.converter.Units.Category;
import arithmos.converter.Units.Found;
import arithmos.converter.Units.Unit;
import arithmos.shared.ArithmosError;
import arithmos.shared.ArithmosError.Code;
import arithmos.shared.FormatNumber;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

/**
 * Unit Converter engine. Pure logic: a line goes in, the lines to print come out.
 * Conversion is value × from.factor ÷ to.factor (IEEE double). Temperature is formula-based.
 */
public final class Converter {

    /** True when a line is a one-line command (so the CLI can tell it from a plain value). */
    public static boolean looksLikeCommand(String line) {
        String[] t = line.trim().split("\\s+");
        String first = t[0].toLowerCase(Locale.ROOT);
        return first.equals("list") || first.equals("convert") || t.length == 3;
    }

    /** Runs one line: {@code [convert] <value> <from> <to|all>}, {@code list}, {@code list <category>}. */
    public List<String> run(String line) {
        String trimmed = line == null ? "" : line.trim();
        if (trimmed.isEmpty()) {
            throw new ArithmosError(Code.UNKNOWN_COMMAND, "Type a value, e.g. 100");
        }
        String[] t = trimmed.split("\\s+");
        String first = t[0].toLowerCase(Locale.ROOT);
        if (first.equals("list")) {
            return list(t);
        }
        if (first.equals("convert")) {
            if (t.length != 4) {
                throw new ArithmosError(Code.UNKNOWN_COMMAND, "Use: convert <value> <from> <to>");
            }
            return convert(t[1], t[2], t[3]);
        }
        if (t.length == 3) { // shorthand without the word "convert"
            return convert(t[0], t[1], t[2]);
        }
        throw new ArithmosError(Code.UNKNOWN_COMMAND, "Not a command. Try: convert 100 cm in");
    }

    /** Guided flow: units already chosen, the line is just a value → "100 m = 109.361329834 yd". */
    public String guided(String valueText, Found from, Found to) {
        double v = parseValue(valueText);
        double r = convertValue(v, from, to);
        return FormatNumber.format(v) + " " + from.unit().symbol() + " = "
                + FormatNumber.format(r) + " " + to.unit().symbol();
    }

    private List<String> convert(String valueText, String fromSymbol, String toSymbol) {
        double v = parseValue(valueText);
        Found from = Units.find(fromSymbol);

        if (toSymbol.equalsIgnoreCase("all")) {
            // Every unit of the source's category, in table order, source included.
            // Lines are built first, so any failure (overflow, below zero) prints nothing at all.
            List<String> lines = new ArrayList<>();
            for (Unit u : from.category().units()) {
                lines.add(u.symbol() + ": "
                        + FormatNumber.format(convertValue(v, from, new Found(from.category(), u))));
            }
            return lines;
        }

        Found to = Units.find(toSymbol);
        if (from.category() != to.category()) {
            throw new ArithmosError(Code.INCOMPATIBLE_UNITS,
                    "Cannot convert " + from.category().name() + " to " + to.category().name());
        }
        return List.of(FormatNumber.format(convertValue(v, from, to)));
    }

    /** A plain decimal only: "1e3" and "1,000" are INVALID_NUMBER (R16). */
    private static double parseValue(String text) {
        // Possessive quantifiers keep this linear on very long garbage.
        if (!text.matches("[+-]?(?:\\d++\\.?+\\d*+|\\.\\d++)")) {
            throw new ArithmosError(Code.INVALID_NUMBER, "'" + text + "' is not a number");
        }
        double v = Double.parseDouble(text);
        if (Double.isInfinite(v)) {
            throw new ArithmosError(Code.OVERFLOW, "That number is too large");
        }
        return v;
    }

    private static double convertValue(double v, Found from, Found to) {
        if (from.category().name().equals("temperature")) {
            return temperature(v, from.unit().symbol(), to.unit().symbol());
        }
        double r = v * from.unit().factor() / to.unit().factor();
        if (Double.isInfinite(r) || Double.isNaN(r)) {
            throw new ArithmosError(Code.OVERFLOW, "Result is too large to represent");
        }
        return r;
    }

    /**
     * Temperature goes through the physics, not factors. The limit is checked on the INPUT in its own
     * unit (0 K, -273.15 °C, -459.67 °F are allowed). The formulas run directly between each pair,
     * so a value exactly at absolute zero converts to exactly 0 K, not -5e-14.
     */
    private static double temperature(double v, String from, String to) {
        boolean below = switch (from) {
            case "c" -> v < -273.15;
            case "f" -> v < -459.67;
            default -> v < 0.0; // "k"
        };
        if (below) {
            throw new ArithmosError(Code.BELOW_ABSOLUTE_ZERO, "That is below absolute zero");
        }
        if (from.equals(to)) return v;
        return switch (from + to) {
            case "cf" -> v * 9.0 / 5.0 + 32.0;
            case "ck" -> v + 273.15;
            case "fc" -> (v - 32.0) * 5.0 / 9.0;
            case "fk" -> (v + 459.67) * 5.0 / 9.0;
            case "kc" -> v - 273.15;
            default -> v * 9.0 / 5.0 - 459.67; // "kf"
        };
    }

    private List<String> list(String[] t) {
        if (t.length == 1) {
            return List.of(Units.CATEGORIES.stream().map(Category::name).collect(Collectors.joining(", ")));
        }
        if (t.length == 2) {
            Category c = Units.category(t[1]);
            if (c == null) {
                throw new ArithmosError(Code.UNKNOWN_COMMAND, "'" + t[1] + "' is not a category. Try: list");
            }
            return List.of(c.units().stream().map(Unit::symbol).collect(Collectors.joining(", ")));
        }
        throw new ArithmosError(Code.UNKNOWN_COMMAND, "Use: list  or  list <category>"); // two spaces are literal
    }
}