package arithmos.converter

/** One unit: symbol, display name (spec §5.3, parentheses included) and factor in base units. */
class UnitDef(val symbol: String, val name: String, val factor: Double)

/** A category and its base unit. Temperature has factor 0: it is formula-based. */
class Category(val name: String, val base: String, val units: List<UnitDef>)

private fun u(symbol: String, name: String, factor: Double) = UnitDef(symbol, name, factor)

// Exact ratios are written as ratios (spec §5.3), not as the rounded decimals.
private val MMHG = 133.322387415
private val BTU = 1055.05585262
private val FTLB = 1.3558179483314004

/** All twelve categories, in spec order. Adding a unit is a data change. */
val CATEGORIES: List<Category> = listOf(
    Category("length", "m", listOf(
        u("pm", "picometre", 1e-12), u("ang", "ångström", 1e-10), u("nm", "nanometre", 1e-9),
        u("um", "micrometre (micron)", 1e-6), u("mm", "millimetre", 0.001), u("cm", "centimetre", 0.01),
        u("m", "metre", 1.0), u("km", "kilometre", 1000.0), u("in", "inch", 0.0254),
        u("ft", "foot", 0.3048), u("yd", "yard", 0.9144), u("mi", "mile", 1609.344),
        u("nmi", "nautical mile", 1852.0), u("au", "astronomical unit", 149597870700.0),
        u("ly", "light-year", 9460730472580800.0))),
    Category("mass", "kg", listOf(
        u("ug", "microgram", 1e-9), u("mg", "milligram", 1e-6), u("ct", "carat (metric)", 0.0002),
        u("gr", "grain", 0.00006479891), u("g", "gram", 0.001), u("kg", "kilogram", 1.0),
        u("t", "metric tonne", 1000.0), u("oz", "ounce", 0.028349523125), u("lb", "pound", 0.45359237),
        u("st", "stone", 6.35029318), u("ton", "US short ton (2000 lb)", 907.18474),
        u("lton", "UK long ton (2240 lb)", 1016.0469088))),
    Category("area", "m2", listOf(
        u("mm2", "square millimetre", 1e-6), u("cm2", "square centimetre", 1e-4), u("m2", "square metre", 1.0),
        u("ha", "hectare", 10000.0), u("km2", "square kilometre", 1e6), u("in2", "square inch", 0.00064516),
        u("ft2", "square foot", 0.09290304), u("yd2", "square yard", 0.83612736), u("ac", "acre", 4046.8564224),
        u("mi2", "square mile", 2589988.110336))),
    Category("volume", "l", listOf(
        u("ml", "millilitre", 0.001), u("l", "litre", 1.0), u("cm3", "cubic centimetre", 0.001),
        u("m3", "cubic metre", 1000.0), u("in3", "cubic inch", 0.016387064), u("ft3", "cubic foot", 28.316846592),
        u("yd3", "cubic yard", 764.554857984), u("tsp", "US teaspoon", 0.00492892159375),
        u("tbsp", "US tablespoon", 0.01478676478125), u("floz", "US fluid ounce", 0.0295735295625),
        u("cup", "US cup", 0.2365882365), u("pt", "US pint", 0.473176473), u("qt", "US quart", 0.946352946),
        u("gal", "US gallon", 3.785411784), u("impfloz", "imperial fluid ounce", 0.0284130625),
        u("imppt", "imperial pint", 0.56826125), u("impqt", "imperial quart", 1.1365225),
        u("impgal", "imperial gallon", 4.54609))),
    Category("time", "s", listOf(
        u("ns", "nanosecond", 1e-9), u("us", "microsecond", 1e-6), u("ms", "millisecond", 0.001),
        u("s", "second", 1.0), u("min", "minute", 60.0), u("h", "hour", 3600.0), u("d", "day", 86400.0),
        u("wk", "week", 604800.0))),
    Category("speed", "mps", listOf(
        u("mps", "metre per second", 1.0), u("kmh", "kilometre per hour", 1000.0 / 3600.0),
        u("mph", "mile per hour", 0.44704), u("kn", "knot", 1852.0 / 3600.0), u("fps", "foot per second", 0.3048))),
    Category("digital", "bit", listOf(
        u("bit", "bit", 1.0), u("nibble", "nibble", 4.0), u("byte", "byte", 8.0), u("kbit", "kilobit", 1e3),
        u("mbit", "megabit", 1e6), u("gbit", "gigabit", 1e9), u("tbit", "terabit", 1e12),
        u("kb", "kilobyte", 8e3), u("mb", "megabyte", 8e6), u("gb", "gigabyte", 8e9), u("tb", "terabyte", 8e12),
        u("pb", "petabyte", 8e15), u("eb", "exabyte", 8e18))),
    Category("energy", "j", listOf(
        u("ev", "electronvolt", 1.602176634e-19), u("erg", "erg", 1e-7), u("j", "joule", 1.0),
        u("kj", "kilojoule", 1000.0), u("cal", "thermochemical (thermal) calorie", 4.184),
        u("kcal", "kilocalorie (food Calorie)", 4184.0), u("wh", "watt-hour", 3600.0),
        u("kwh", "kilowatt-hour", 3600000.0), u("btu", "British thermal unit (International Table)", BTU),
        u("ftlb", "foot-pound force", FTLB))),
    Category("power", "w", listOf(
        u("w", "watt", 1.0), u("kw", "kilowatt", 1000.0), u("gw", "gigawatt", 1e9),
        u("hp", "mechanical horsepower", 745.69987158227022), u("ps", "metric horsepower (PS)", 735.49875),
        u("btuh", "BTU (IT) per hour", BTU / 3600.0), u("btumin", "BTU (IT) per minute", BTU / 60.0),
        u("ftlbmin", "foot-pound force per minute", FTLB / 60.0))),
    Category("pressure", "pa", listOf(
        u("pa", "pascal", 1.0), u("hpa", "hectopascal", 100.0), u("kpa", "kilopascal", 1000.0),
        u("mpa", "megapascal", 1e6), u("mbar", "millibar", 100.0), u("bar", "bar", 1e5),
        u("atm", "standard atmosphere", 101325.0), u("psi", "pound-force per square inch", 6894.757293168361),
        u("mmhg", "millimetre of mercury (conventional)", MMHG),
        u("inhg", "inch of mercury (conventional)", 25.4 * MMHG), u("torr", "torr", 101325.0 / 760.0))),
    Category("angle", "deg", listOf(
        u("deg", "degree", 1.0), u("rad", "radian", 180.0 / Math.PI), u("grad", "gradian (gon)", 0.9),
        u("turn", "full turn (revolution)", 360.0), u("arcmin", "arcminute", 1.0 / 60.0),
        u("arcsec", "arcsecond", 1.0 / 3600.0))),
    Category("temperature", "c", listOf(
        u("c", "degree Celsius", 0.0), u("f", "degree Fahrenheit", 0.0), u("k", "kelvin", 0.0)))
)

/** Symbols are unique across categories and case-insensitive, so the category is inferred (spec §5.1). */
val BY_SYMBOL: Map<String, Pair<Category, UnitDef>> =
    CATEGORIES.flatMap { c -> c.units.map { it.symbol.lowercase() to (c to it) } }.toMap()