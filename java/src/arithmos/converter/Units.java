package arithmos.converter;

import arithmos.shared.ArithmosError;
import arithmos.shared.ArithmosError.Code;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * The unit tables of spec §5.3, as data. Adding a unit is a data change.
 * Factor = how many BASE units equal one of that unit. Exact ratios are written as ratios.
 * Symbols are unique across all categories and matched case-insensitively.
 */
public final class Units {
    private Units() {}

    public record Unit(String symbol, String name, double factor) {}

    public record Category(String name, String base, List<Unit> units) {}

    /** A unit together with its category. */
    public record Found(Category category, Unit unit) {}

    private static Unit u(String symbol, String name, double factor) {
        return new Unit(symbol, name, factor);
    }

    private static Category cat(String name, String base, Unit... units) {
        return new Category(name, base, List.of(units));
    }

    /** Table order matters: it is the order of "list" and of the "all" target. */
    public static final List<Category> CATEGORIES = List.of(
        cat("length", "m",
            u("pm", "picometre", 1e-12), u("ang", "ångström", 1e-10), u("nm", "nanometre", 1e-9),
            u("um", "micrometre (micron)", 1e-6), u("mm", "millimetre", 0.001), u("cm", "centimetre", 0.01),
            u("m", "metre", 1), u("km", "kilometre", 1000), u("in", "inch", 0.0254),
            u("ft", "foot", 0.3048), u("yd", "yard", 0.9144), u("mi", "mile", 1609.344),
            u("nmi", "nautical mile", 1852), u("au", "astronomical unit", 149597870700.0),
            u("ly", "light-year", 9460730472580800.0)),
        cat("mass", "kg",
            u("ug", "microgram", 1e-9), u("mg", "milligram", 1e-6), u("ct", "carat (metric)", 0.0002),
            u("gr", "grain", 0.00006479891), u("g", "gram", 0.001), u("kg", "kilogram", 1),
            u("t", "metric tonne", 1000), u("oz", "ounce", 0.028349523125), u("lb", "pound", 0.45359237),
            u("st", "stone", 6.35029318), u("ton", "US short ton (2000 lb)", 907.18474),
            u("lton", "UK long ton (2240 lb)", 1016.0469088)),
        cat("area", "m2",
            u("mm2", "square millimetre", 1e-6), u("cm2", "square centimetre", 1e-4),
            u("m2", "square metre", 1), u("ha", "hectare", 10000), u("km2", "square kilometre", 1e6),
            u("in2", "square inch", 0.00064516), u("ft2", "square foot", 0.09290304),
            u("yd2", "square yard", 0.83612736), u("ac", "acre", 4046.8564224),
            u("mi2", "square mile", 2589988.110336)),
        cat("volume", "l",
            u("ml", "millilitre", 0.001), u("l", "litre", 1), u("cm3", "cubic centimetre", 0.001),
            u("m3", "cubic metre", 1000), u("in3", "cubic inch", 0.016387064),
            u("ft3", "cubic foot", 28.316846592), u("yd3", "cubic yard", 764.554857984),
            u("tsp", "US teaspoon", 0.00492892159375), u("tbsp", "US tablespoon", 0.01478676478125),
            u("floz", "US fluid ounce", 0.0295735295625), u("cup", "US cup", 0.2365882365),
            u("pt", "US pint", 0.473176473), u("qt", "US quart", 0.946352946),
            u("gal", "US gallon", 3.785411784), u("impfloz", "imperial fluid ounce", 0.0284130625),
            u("imppt", "imperial pint", 0.56826125), u("impqt", "imperial quart", 1.1365225),
            u("impgal", "imperial gallon", 4.54609)),
        cat("time", "s",
            u("ns", "nanosecond", 1e-9), u("us", "microsecond", 1e-6), u("ms", "millisecond", 0.001),
            u("s", "second", 1), u("min", "minute", 60), u("h", "hour", 3600), u("d", "day", 86400),
            u("wk", "week", 604800)),
        cat("speed", "mps",
            u("mps", "metre per second", 1),
            u("kmh", "kilometre per hour", 1000.0 / 3600.0),   // exact ratio, not the rounded decimal
            u("mph", "mile per hour", 0.44704),
            u("kn", "knot", 1852.0 / 3600.0),                  // exact ratio
            u("fps", "foot per second", 0.3048)),
        cat("digital", "bit",
            u("bit", "bit", 1), u("nibble", "nibble", 4), u("byte", "byte", 8),
            u("kbit", "kilobit", 1e3), u("mbit", "megabit", 1e6), u("gbit", "gigabit", 1e9),
            u("tbit", "terabit", 1e12), u("kb", "kilobyte", 8e3), u("mb", "megabyte", 8e6),
            u("gb", "gigabyte", 8e9), u("tb", "terabyte", 8e12), u("pb", "petabyte", 8e15),
            u("eb", "exabyte", 8e18)),
        cat("energy", "j",
            u("ev", "electronvolt", 1.602176634e-19), u("erg", "erg", 1e-7), u("j", "joule", 1),
            u("kj", "kilojoule", 1000), u("cal", "thermochemical (thermal) calorie", 4.184),
            u("kcal", "kilocalorie (food Calorie)", 4184), u("wh", "watt-hour", 3600),
            u("kwh", "kilowatt-hour", 3600000), u("btu", "British thermal unit (International Table)", 1055.05585262),
            u("ftlb", "foot-pound force", 1.3558179483314004)),
        cat("power", "w",
            u("w", "watt", 1), u("kw", "kilowatt", 1000), u("gw", "gigawatt", 1e9),
            u("hp", "mechanical horsepower", 745.69987158227022),
            u("ps", "metric horsepower (PS)", 735.49875),
            u("btuh", "BTU (IT) per hour", 1055.05585262 / 3600.0),
            u("btumin", "BTU (IT) per minute", 1055.05585262 / 60.0),
            u("ftlbmin", "foot-pound force per minute", 1.3558179483314004 / 60.0)),
        cat("pressure", "pa",
            u("pa", "pascal", 1), u("hpa", "hectopascal", 100), u("kpa", "kilopascal", 1000),
            u("mpa", "megapascal", 1e6), u("mbar", "millibar", 100), u("bar", "bar", 100000),
            u("atm", "standard atmosphere", 101325), u("psi", "pound-force per square inch", 6894.757293168361),
            u("mmhg", "millimetre of mercury (conventional)", 133.322387415),
            u("inhg", "inch of mercury (conventional)", 3386.388640341),
            u("torr", "torr", 101325.0 / 760.0)),                // exact ratio
        cat("angle", "deg",
            u("deg", "degree", 1), u("rad", "radian", 180.0 / Math.PI), u("grad", "gradian (gon)", 0.9),
            u("turn", "full turn (revolution)", 360), u("arcmin", "arcminute", 1.0 / 60.0),
            u("arcsec", "arcsecond", 1.0 / 3600.0)),
        // Temperature is formula-based (offsets, not factors); the factor column is unused.
        cat("temperature", "c",
            u("c", "degree Celsius", Double.NaN), u("f", "degree Fahrenheit", Double.NaN),
            u("k", "kelvin", Double.NaN)));

    private static final Map<String, Found> INDEX = new HashMap<>();

    static {
        for (Category c : CATEGORIES) {
            for (Unit un : c.units()) {
                if (INDEX.put(un.symbol(), new Found(c, un)) != null) {
                    throw new IllegalStateException("duplicate unit symbol " + un.symbol());
                }
            }
        }
    }

    /** Case-insensitive lookup; the category is inferred from the symbol. */
    public static Found find(String symbol) {
        Found f = INDEX.get(symbol.toLowerCase(Locale.ROOT));
        if (f == null) {
            throw new ArithmosError(Code.UNKNOWN_UNIT, "'" + symbol + "' is not a known unit. Try: list");
        }
        return f;
    }

    public static Category category(String name) {
        for (Category c : CATEGORIES) {
            if (c.name().equalsIgnoreCase(name)) return c;
        }
        return null;
    }
}