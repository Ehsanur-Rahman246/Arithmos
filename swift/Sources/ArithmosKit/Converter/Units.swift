import Foundation

// Unit tables as data (spec §5.3). Factor = how many BASE units equal one of this unit.
// Where the spec names an exact ratio, the ratio is written out instead of a rounded decimal.

struct Unit {
    let symbol: String      // unique across all categories, matched case-insensitively
    let name: String        // display name, exactly as in the spec table (R33)
    let factor: Double
}

struct Category {
    let name: String
    let units: [Unit]
    var isTemperature: Bool { name == "temperature" }
}

private func U(_ symbol: String, _ name: String, _ factor: Double) -> Unit {
    Unit(symbol: symbol, name: name, factor: factor)
}

/// The twelve categories, in the order `list` shows them.
let unitTable: [Category] = [
    Category(name: "length", units: [                       // base: metre
        U("pm", "picometre", 1e-12), U("ang", "ångström", 1e-10), U("nm", "nanometre", 1e-9),
        U("um", "micrometre (micron)", 1e-6), U("mm", "millimetre", 0.001),
        U("cm", "centimetre", 0.01), U("m", "metre", 1), U("km", "kilometre", 1000),
        U("in", "inch", 0.0254), U("ft", "foot", 0.3048), U("yd", "yard", 0.9144),
        U("mi", "mile", 1609.344), U("nmi", "nautical mile", 1852),
        U("au", "astronomical unit", 149597870700), U("ly", "light-year", 9460730472580800),
    ]),
    Category(name: "mass", units: [                         // base: kilogram
        U("ug", "microgram", 1e-9), U("mg", "milligram", 1e-6), U("ct", "carat (metric)", 0.0002),
        U("gr", "grain", 0.00006479891), U("g", "gram", 0.001), U("kg", "kilogram", 1),
        U("t", "metric tonne", 1000), U("oz", "ounce", 0.028349523125),
        U("lb", "pound", 0.45359237), U("st", "stone", 6.35029318),
        U("ton", "US short ton (2000 lb)", 907.18474), U("lton", "UK long ton (2240 lb)", 1016.0469088),
    ]),
    Category(name: "area", units: [                         // base: square metre
        U("mm2", "square millimetre", 1e-6), U("cm2", "square centimetre", 0.0001),
        U("m2", "square metre", 1), U("ha", "hectare", 10000), U("km2", "square kilometre", 1_000_000),
        U("in2", "square inch", 0.00064516), U("ft2", "square foot", 0.09290304),
        U("yd2", "square yard", 0.83612736), U("ac", "acre", 4046.8564224),
        U("mi2", "square mile", 2589988.110336),
    ]),
    Category(name: "volume", units: [                       // base: litre
        U("ml", "millilitre", 0.001), U("l", "litre", 1), U("cm3", "cubic centimetre", 0.001),
        U("m3", "cubic metre", 1000), U("in3", "cubic inch", 0.016387064),
        U("ft3", "cubic foot", 28.316846592), U("yd3", "cubic yard", 764.554857984),
        U("tsp", "US teaspoon", 0.00492892159375), U("tbsp", "US tablespoon", 0.01478676478125),
        U("floz", "US fluid ounce", 0.0295735295625), U("cup", "US cup", 0.2365882365),
        U("pt", "US pint", 0.473176473), U("qt", "US quart", 0.946352946),
        U("gal", "US gallon", 3.785411784), U("impfloz", "imperial fluid ounce", 0.0284130625),
        U("imppt", "imperial pint", 0.56826125), U("impqt", "imperial quart", 1.1365225),
        U("impgal", "imperial gallon", 4.54609),
    ]),
    Category(name: "time", units: [                         // base: second
        U("ns", "nanosecond", 1e-9), U("us", "microsecond", 1e-6), U("ms", "millisecond", 0.001),
        U("s", "second", 1), U("min", "minute", 60), U("h", "hour", 3600),
        U("d", "day", 86400), U("wk", "week", 604800),
    ]),
    Category(name: "speed", units: [                        // base: metre per second
        U("mps", "metre per second", 1), U("kmh", "kilometre per hour", 1000.0 / 3600.0),
        U("mph", "mile per hour", 0.44704), U("kn", "knot", 1852.0 / 3600.0),
        U("fps", "foot per second", 0.3048),
    ]),
    Category(name: "digital", units: [                      // base: bit, SI multiples only
        U("bit", "bit", 1), U("nibble", "nibble", 4), U("byte", "byte", 8),
        U("kbit", "kilobit", 1e3), U("mbit", "megabit", 1e6), U("gbit", "gigabit", 1e9),
        U("tbit", "terabit", 1e12), U("kb", "kilobyte", 8e3), U("mb", "megabyte", 8e6),
        U("gb", "gigabyte", 8e9), U("tb", "terabyte", 8e12), U("pb", "petabyte", 8e15),
        U("eb", "exabyte", 8e18),
    ]),
    Category(name: "energy", units: [                       // base: joule
        U("ev", "electronvolt", 1.602176634e-19), U("erg", "erg", 1e-7), U("j", "joule", 1),
        U("kj", "kilojoule", 1000), U("cal", "thermochemical (thermal) calorie", 4.184),
        U("kcal", "kilocalorie (food Calorie)", 4184), U("wh", "watt-hour", 3600),
        U("kwh", "kilowatt-hour", 3_600_000),
        U("btu", "British thermal unit (International Table)", 1055.05585262),
        U("ftlb", "foot-pound force", 1.3558179483314004),
    ]),
    Category(name: "power", units: [                        // base: watt
        U("w", "watt", 1), U("kw", "kilowatt", 1000), U("gw", "gigawatt", 1e9),
        U("hp", "mechanical horsepower", 745.69987158227022),
        U("ps", "metric horsepower (PS)", 735.49875),
        U("btuh", "BTU (IT) per hour", 1055.05585262 / 3600),
        U("btumin", "BTU (IT) per minute", 1055.05585262 / 60),
        U("ftlbmin", "foot-pound force per minute", 1.3558179483314004 / 60),
    ]),
    Category(name: "pressure", units: [                     // base: pascal
        U("pa", "pascal", 1), U("hpa", "hectopascal", 100), U("kpa", "kilopascal", 1000),
        U("mpa", "megapascal", 1e6), U("mbar", "millibar", 100), U("bar", "bar", 100000),
        U("atm", "standard atmosphere", 101325),
        U("psi", "pound-force per square inch", 6894.757293168361),
        U("mmhg", "millimetre of mercury (conventional)", 133.322387415),
        U("inhg", "inch of mercury (conventional)", 25.4 * 133.322387415),
        U("torr", "torr", 101325.0 / 760.0),
    ]),
    Category(name: "angle", units: [                        // base: degree
        U("deg", "degree", 1), U("rad", "radian", 180 / Double.pi), U("grad", "gradian (gon)", 0.9),
        U("turn", "full turn (revolution)", 360), U("arcmin", "arcminute", 1.0 / 60),
        U("arcsec", "arcsecond", 1.0 / 3600),
    ]),
    Category(name: "temperature", units: [                  // formula-based; factor unused
        U("c", "degree Celsius", 1), U("f", "degree Fahrenheit", 1), U("k", "kelvin", 1),
    ]),
]