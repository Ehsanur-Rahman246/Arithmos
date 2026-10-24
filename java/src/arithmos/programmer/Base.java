package arithmos.programmer;

import arithmos.shared.ArithmosError;
import arithmos.shared.ArithmosError.Code;

/** The four bases of spec §4.2. */
public enum Base {
    BIN(2, "bin"), OCT(8, "oct"), DEC(10, "dec"), HEX(16, "hex");

    public final int radix;
    public final String id; // lower-case canonical name

    Base(int radix, String id) {
        this.radix = radix;
        this.id = id;
    }

    /** Case-insensitive; unknown name is INVALID_BASE. */
    public static Base fromName(String name) {
        for (Base b : values()) {
            if (b.id.equalsIgnoreCase(name)) return b;
        }
        throw new ArithmosError(Code.INVALID_BASE, "'" + name + "' is not a base. Use bin, oct, dec or hex");
    }

    public static boolean isName(String name) {
        for (Base b : values()) {
            if (b.id.equalsIgnoreCase(name)) return true;
        }
        return false;
    }

    /** Base for a literal prefix letter (0b 0o 0d 0x), or null. */
    static Base fromPrefixChar(char c) {
        return switch (Character.toLowerCase(c)) {
            case 'b' -> BIN;
            case 'o' -> OCT;
            case 'd' -> DEC;
            case 'x' -> HEX;
            default -> null;
        };
    }

    /**
     * Shows a value in this base. DEC is the signed value; BIN/OCT/HEX show the full 64-bit
     * two's-complement pattern (Long.toXxxString print the unsigned pattern), upper-case, no prefix.
     */
    public String render(long v) {
        return switch (this) {
            case BIN -> Long.toBinaryString(v);
            case OCT -> Long.toOctalString(v);
            case DEC -> Long.toString(v);
            case HEX -> Long.toHexString(v).toUpperCase(java.util.Locale.ROOT);
        };
    }
}