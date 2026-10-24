package arithmos.programmer;

import arithmos.shared.ArithmosError;
import arithmos.shared.ArithmosError.Code;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Programmer Calculator session. Every value is Java's native signed 64-bit {@code long}:
 * {@code <<} drops overflow bits, {@code >>} is arithmetic, {@code >>>} is logical.
 * The engine returns outcomes; the CLI turns them into text. The session holds the input base.
 */
public final class Programmer {

    /** What a line produced. */
    public sealed interface Outcome {
        /** A value to show in all four bases (plain value or bitwise/shift result). */
        record Value(long value) implements Outcome {}
        /** The single converted number of a convert command, already in the target base. */
        record Converted(String text) implements Outcome {}
        /** The input base was changed. */
        record BaseChanged(Base base) implements Outcome {}
    }

    // "1<<3", "1 << 3", "-8 >>> 1": spaces are optional around the shift operators (R29).
    private static final Pattern SHIFT = Pattern.compile("^(\\S+?)\\s*(>>>|>>|<<)\\s*(\\S+)$");

    private Base inputBase = Base.DEC;

    public Base inputBase() {
        return inputBase;
    }

    public Outcome run(String line) {
        String text = line == null ? "" : line.trim();
        if (text.isEmpty()) {
            throw new ArithmosError(Code.UNKNOWN_COMMAND, "Type a number or a command. Try help");
        }

        // Shifts first: they may have no spaces at all.
        if (text.contains("<<") || text.contains(">>")) {
            Matcher m = SHIFT.matcher(text);
            if (!m.matches()) {
                throw new ArithmosError(Code.UNKNOWN_COMMAND, "Not a command. Try help");
            }
            return shift(m.group(1), m.group(2), m.group(3));
        }

        String[] t = text.split("\\s+");
        String first = t[0].toLowerCase(java.util.Locale.ROOT);

        if (first.equals("base")) {
            if (t.length != 2) {
                throw new ArithmosError(Code.INVALID_BASE, "Use: base bin | oct | dec | hex");
            }
            inputBase = Base.fromName(t[1]);
            return new Outcome.BaseChanged(inputBase);
        }
        if (first.equals("convert")) {
            if (t.length != 4) {
                throw new ArithmosError(Code.UNKNOWN_COMMAND, "Use: convert <value> <from> <to>");
            }
            return convert(t[1], t[2], t[3]);
        }
        if (first.equals("not")) {
            if (t.length != 2) {
                throw new ArithmosError(Code.UNKNOWN_COMMAND, "Use: NOT <value>");
            }
            return new Outcome.Value(~Literal.parse(t[1], inputBase));
        }
        if (t.length == 3) {
            // R11: the operator is always the MIDDLE word, so in hex mode "FACE XOR BEEF" works.
            String op = t[1].toLowerCase(java.util.Locale.ROOT);
            if (op.equals("and") || op.equals("or") || op.equals("xor")) {
                long a = Literal.parse(t[0], inputBase);
                long b = Literal.parse(t[2], inputBase);
                return new Outcome.Value(switch (op) {
                    case "and" -> a & b;
                    case "or" -> a | b;
                    default -> a ^ b;
                });
            }
            // "255 dec hex": the word "convert" is optional (R24).
            if (Base.isName(t[1]) && Base.isName(t[2])) {
                return convert(t[0], t[1], t[2]);
            }
        }
        if (t.length == 1) {
            return new Outcome.Value(Literal.parse(t[0], inputBase));
        }
        throw new ArithmosError(Code.UNKNOWN_COMMAND, "Not a command. Try help");
    }

    private Outcome convert(String value, String fromName, String toName) {
        Base from = Base.fromName(fromName);
        Base to = Base.fromName(toName);
        // The explicit "from" base reads the value, independent of the session input base.
        long v = Literal.parse(value, from);
        return new Outcome.Converted(to.render(v));
    }

    private Outcome shift(String left, String op, String count) {
        long a = Literal.parse(left, inputBase);
        // The count is always a plain DECIMAL number from 0 to 63 (R13: "0x3" and "2.5" are rejected).
        if (!count.matches("[0-9]{1,3}") || Integer.parseInt(count) > 63) {
            throw new ArithmosError(Code.INVALID_SHIFT, "A shift count must be a whole number from 0 to 63");
        }
        int n = Integer.parseInt(count);
        return new Outcome.Value(switch (op) {
            case "<<" -> a << n;   // bits shifted past bit 63 are discarded, no error
            case ">>" -> a >> n;   // arithmetic, sign-extending
            default -> a >>> n;    // logical, zero-filling
        });
    }
}