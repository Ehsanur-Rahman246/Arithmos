"""Data-driven unit tables (spec 5.3). Every symbol is unique across ALL categories
(checked at import). Temperature is formula-based, so its units have no factor."""
import math
from dataclasses import dataclass, field
from typing import Optional


@dataclass(frozen=True)
class Unit:
    symbol: str
    name: str
    factor: Optional[float] = None


@dataclass(frozen=True)
class Category:
    name: str
    base: str
    units: tuple = field(default_factory=tuple)
    formula: bool = False


def _u(symbol, name, factor):
    return Unit(symbol, name, factor)


CATEGORIES = (
    Category("length", "m", (
        _u("pm", "picometre", 1e-12), _u("ang", "ångström", 1e-10), _u("nm", "nanometre", 1e-9),
        _u("um", "micrometre", 1e-6), _u("mm", "millimetre", 0.001), _u("cm", "centimetre", 0.01),
        _u("m", "metre", 1.0), _u("km", "kilometre", 1000.0), _u("in", "inch", 0.0254),
        _u("ft", "foot", 0.3048), _u("yd", "yard", 0.9144), _u("mi", "mile", 1609.344),
        _u("nmi", "nautical mile", 1852.0), _u("au", "astronomical unit", 149597870700.0),
        _u("ly", "light-year", 9460730472580800.0),
    )),
    Category("mass", "kg", (
        _u("ug", "microgram", 1e-9), _u("mg", "milligram", 1e-6), _u("ct", "carat (metric)", 0.0002),
        _u("gr", "grain", 0.00006479891), _u("g", "gram", 0.001), _u("kg", "kilogram", 1.0),
        _u("t", "metric tonne", 1000.0), _u("oz", "ounce", 0.028349523125),
        _u("lb", "pound", 0.45359237), _u("st", "stone", 6.35029318),
        _u("ton", "US short ton", 907.18474), _u("lton", "UK long ton", 1016.0469088),
    )),
    Category("area", "m2", (
        _u("mm2", "square millimetre", 1e-6), _u("cm2", "square centimetre", 0.0001),
        _u("m2", "square metre", 1.0), _u("ha", "hectare", 10000.0),
        _u("km2", "square kilometre", 1000000.0), _u("in2", "square inch", 0.00064516),
        _u("ft2", "square foot", 0.09290304), _u("yd2", "square yard", 0.83612736),
        _u("ac", "acre", 4046.8564224), _u("mi2", "square mile", 2589988.110336),
    )),
    Category("volume", "l", (
        _u("ml", "millilitre", 0.001), _u("l", "litre", 1.0), _u("cm3", "cubic centimetre", 0.001),
        _u("m3", "cubic metre", 1000.0), _u("in3", "cubic inch", 0.016387064),
        _u("ft3", "cubic foot", 28.316846592), _u("yd3", "cubic yard", 764.554857984),
        _u("tsp", "US teaspoon", 0.00492892159375), _u("tbsp", "US tablespoon", 0.01478676478125),
        _u("floz", "US fluid ounce", 0.0295735295625), _u("cup", "US cup", 0.2365882365),
        _u("pt", "US pint", 0.473176473), _u("qt", "US quart", 0.946352946),
        _u("gal", "US gallon", 3.785411784), _u("impfloz", "imperial fluid ounce", 0.0284130625),
        _u("imppt", "imperial pint", 0.56826125), _u("impqt", "imperial quart", 1.1365225),
        _u("impgal", "imperial gallon", 4.54609),
    )),
    Category("time", "s", (
        _u("ns", "nanosecond", 1e-9), _u("us", "microsecond", 1e-6), _u("ms", "millisecond", 0.001),
        _u("s", "second", 1.0), _u("min", "minute", 60.0), _u("h", "hour", 3600.0),
        _u("d", "day", 86400.0), _u("wk", "week", 604800.0),
    )),
    Category("speed", "mps", (
        _u("mps", "metre per second", 1.0), _u("kmh", "kilometre per hour", 1000 / 3600),
        _u("mph", "mile per hour", 0.44704), _u("kn", "knot", 1852 / 3600),
        _u("fps", "foot per second", 0.3048),
    )),
    Category("digital", "bit", (
        _u("bit", "bit", 1.0), _u("nibble", "nibble", 4.0), _u("byte", "byte", 8.0),
        _u("kbit", "kilobit", 1e3), _u("mbit", "megabit", 1e6), _u("gbit", "gigabit", 1e9),
        _u("tbit", "terabit", 1e12), _u("kb", "kilobyte", 8e3), _u("mb", "megabyte", 8e6),
        _u("gb", "gigabyte", 8e9), _u("tb", "terabyte", 8e12), _u("pb", "petabyte", 8e15),
        _u("eb", "exabyte", 8e18),
    )),
    Category("energy", "j", (
        _u("ev", "electronvolt", 1.602176634e-19), _u("erg", "erg", 1e-7), _u("j", "joule", 1.0),
        _u("kj", "kilojoule", 1000.0), _u("cal", "thermochemical calorie", 4.184),
        _u("kcal", "kilocalorie (food Calorie)", 4184.0), _u("wh", "watt-hour", 3600.0),
        _u("kwh", "kilowatt-hour", 3600000.0), _u("btu", "British thermal unit (IT)", 1055.05585262),
        _u("ftlb", "foot-pound force", 1.3558179483314004),
    )),
    Category("power", "w", (
        _u("w", "watt", 1.0), _u("kw", "kilowatt", 1000.0), _u("gw", "gigawatt", 1e9),
        _u("hp", "mechanical horsepower", 745.69987158227022), _u("ps", "metric horsepower", 735.49875),
        _u("btuh", "BTU (IT) per hour", 1055.05585262 / 3600),
        _u("btumin", "BTU (IT) per minute", 1055.05585262 / 60),
        _u("ftlbmin", "foot-pound force per minute", 1.3558179483314004 / 60),
    )),
    Category("pressure", "pa", (
        _u("pa", "pascal", 1.0), _u("hpa", "hectopascal", 100.0), _u("kpa", "kilopascal", 1000.0),
        _u("mpa", "megapascal", 1e6), _u("mbar", "millibar", 100.0), _u("bar", "bar", 100000.0),
        _u("atm", "standard atmosphere", 101325.0), _u("psi", "pound-force per square inch", 6894.757293168361),
        _u("mmhg", "millimetre of mercury", 133.322387415),
        _u("inhg", "inch of mercury", 25.4 * 133.322387415), _u("torr", "torr", 101325 / 760),
    )),
    Category("angle", "deg", (
        _u("deg", "degree", 1.0), _u("rad", "radian", 180 / math.pi), _u("grad", "gradian", 0.9),
        _u("turn", "full turn", 360.0), _u("arcmin", "arcminute", 1 / 60), _u("arcsec", "arcsecond", 1 / 3600),
    )),
    Category("temperature", "c", (
        Unit("c", "degree Celsius"), Unit("f", "degree Fahrenheit"), Unit("k", "kelvin"),
    ), formula=True),
)

# lowercase symbol -> (category, unit)
SYMBOL_INDEX = {}
for _category in CATEGORIES:
    for _unit in _category.units:
        if _unit.symbol in SYMBOL_INDEX:
            raise RuntimeError(f"Duplicate unit symbol: {_unit.symbol}")
        SYMBOL_INDEX[_unit.symbol] = (_category, _unit)