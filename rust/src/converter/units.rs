//! Unit tables as data (spec §5.3). Factor = how many base units equal one of that unit.
//! Ratios the spec names are written as ratios (1000/3600, 101325/760, 180/π, ...).
use std::f64::consts::PI;
use std::sync::OnceLock;

pub struct Unit {
    pub symbol: &'static str,
    pub name: &'static str,
    pub factor: f64, // unused for temperature (formula based)
}

pub struct Category {
    pub name: &'static str,
    pub units: Vec<Unit>,
}

fn c(name: &'static str, rows: &[(&'static str, &'static str, f64)]) -> Category {
    Category {
        name,
        units: rows.iter().map(|&(symbol, name, factor)| Unit { symbol, name, factor }).collect(),
    }
}

fn build() -> Vec<Category> {
    vec![
        c("length", &[
            ("pm", "picometre", 1e-12), ("ang", "ångström", 1e-10), ("nm", "nanometre", 1e-9),
            ("um", "micrometre (micron)", 1e-6), ("mm", "millimetre", 0.001), ("cm", "centimetre", 0.01),
            ("m", "metre", 1.0), ("km", "kilometre", 1000.0), ("in", "inch", 0.0254),
            ("ft", "foot", 0.3048), ("yd", "yard", 0.9144), ("mi", "mile", 1609.344),
            ("nmi", "nautical mile", 1852.0), ("au", "astronomical unit", 149597870700.0),
            ("ly", "light-year", 9460730472580800.0),
        ]),
        c("mass", &[
            ("ug", "microgram", 1e-9), ("mg", "milligram", 1e-6), ("ct", "carat (metric)", 0.0002),
            ("gr", "grain", 0.00006479891), ("g", "gram", 0.001), ("kg", "kilogram", 1.0),
            ("t", "metric tonne", 1000.0), ("oz", "ounce", 0.028349523125), ("lb", "pound", 0.45359237),
            ("st", "stone", 6.35029318), ("ton", "US short ton (2000 lb)", 907.18474),
            ("lton", "UK long ton (2240 lb)", 1016.0469088),
        ]),
        c("area", &[
            ("mm2", "square millimetre", 1e-6), ("cm2", "square centimetre", 1e-4), ("m2", "square metre", 1.0),
            ("ha", "hectare", 10000.0), ("km2", "square kilometre", 1e6), ("in2", "square inch", 0.00064516),
            ("ft2", "square foot", 0.09290304), ("yd2", "square yard", 0.83612736),
            ("ac", "acre", 4046.8564224), ("mi2", "square mile", 2589988.110336),
        ]),
        c("volume", &[
            ("ml", "millilitre", 0.001), ("l", "litre", 1.0), ("cm3", "cubic centimetre", 0.001),
            ("m3", "cubic metre", 1000.0), ("in3", "cubic inch", 0.016387064),
            ("ft3", "cubic foot", 28.316846592), ("yd3", "cubic yard", 764.554857984),
            ("tsp", "US teaspoon", 0.00492892159375), ("tbsp", "US tablespoon", 0.01478676478125),
            ("floz", "US fluid ounce", 0.0295735295625), ("cup", "US cup", 0.2365882365),
            ("pt", "US pint", 0.473176473), ("qt", "US quart", 0.946352946), ("gal", "US gallon", 3.785411784),
            ("impfloz", "imperial fluid ounce", 0.0284130625), ("imppt", "imperial pint", 0.56826125),
            ("impqt", "imperial quart", 1.1365225), ("impgal", "imperial gallon", 4.54609),
        ]),
        c("time", &[
            ("ns", "nanosecond", 1e-9), ("us", "microsecond", 1e-6), ("ms", "millisecond", 0.001),
            ("s", "second", 1.0), ("min", "minute", 60.0), ("h", "hour", 3600.0),
            ("d", "day", 86400.0), ("wk", "week", 604800.0),
        ]),
        c("speed", &[
            ("mps", "metre per second", 1.0), ("kmh", "kilometre per hour", 1000.0 / 3600.0),
            ("mph", "mile per hour", 0.44704), ("kn", "knot", 1852.0 / 3600.0), ("fps", "foot per second", 0.3048),
        ]),
        c("digital", &[
            ("bit", "bit", 1.0), ("nibble", "nibble", 4.0), ("byte", "byte", 8.0),
            ("kbit", "kilobit", 1e3), ("mbit", "megabit", 1e6), ("gbit", "gigabit", 1e9), ("tbit", "terabit", 1e12),
            ("kb", "kilobyte", 8e3), ("mb", "megabyte", 8e6), ("gb", "gigabyte", 8e9),
            ("tb", "terabyte", 8e12), ("pb", "petabyte", 8e15), ("eb", "exabyte", 8e18),
        ]),
        c("energy", &[
            ("ev", "electronvolt", 1.602176634e-19), ("erg", "erg", 1e-7), ("j", "joule", 1.0),
            ("kj", "kilojoule", 1000.0), ("cal", "thermochemical (thermal) calorie", 4.184),
            ("kcal", "kilocalorie (food Calorie)", 4184.0), ("wh", "watt-hour", 3600.0),
            ("kwh", "kilowatt-hour", 3600000.0),
            ("btu", "British thermal unit (International Table)", 1055.05585262),
            ("ftlb", "foot-pound force", 1.3558179483314004),
        ]),
        c("power", &[
            ("w", "watt", 1.0), ("kw", "kilowatt", 1000.0), ("gw", "gigawatt", 1e9),
            ("hp", "mechanical horsepower", 745.69987158227022), ("ps", "metric horsepower (PS)", 735.49875),
            ("btuh", "BTU (IT) per hour", 1055.05585262 / 3600.0),
            ("btumin", "BTU (IT) per minute", 1055.05585262 / 60.0),
            ("ftlbmin", "foot-pound force per minute", 1.3558179483314004 / 60.0),
        ]),
        c("pressure", &[
            ("pa", "pascal", 1.0), ("hpa", "hectopascal", 100.0), ("kpa", "kilopascal", 1000.0),
            ("mpa", "megapascal", 1e6), ("mbar", "millibar", 100.0), ("bar", "bar", 100000.0),
            ("atm", "standard atmosphere", 101325.0), ("psi", "pound-force per square inch", 6894.757293168361),
            ("mmhg", "millimetre of mercury (conventional)", 133.322387415),
            ("inhg", "inch of mercury (conventional)", 25.4 * 133.322387415),
            ("torr", "torr", 101325.0 / 760.0),
        ]),
        c("angle", &[
            ("deg", "degree", 1.0), ("rad", "radian", 180.0 / PI), ("grad", "gradian (gon)", 0.9),
            ("turn", "full turn (revolution)", 360.0), ("arcmin", "arcminute", 1.0 / 60.0),
            ("arcsec", "arcsecond", 1.0 / 3600.0),
        ]),
        c("temperature", &[
            ("c", "degree Celsius", 0.0), ("f", "degree Fahrenheit", 0.0), ("k", "kelvin", 0.0),
        ]),
    ]
}

static TABLE: OnceLock<Vec<Category>> = OnceLock::new();

/// The twelve categories, in spec order.
pub fn categories() -> &'static [Category] {
    TABLE.get_or_init(build).as_slice()
}