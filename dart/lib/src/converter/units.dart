// Unit tables as data (spec 5.3). Factor = how many BASE units equal one of this unit.
// Where the spec names an exact ratio (1000/3600, 101325/760, 180/pi ...) the ratio is
// written out instead of a rounded decimal. Display names follow the spec exactly (R33).
import 'dart:math' as math;

class Unit {
  final String symbol;
  final String name;
  final double factor;
  const Unit(this.symbol, this.name, this.factor);
}

class Category {
  final String name;
  final String base; // symbol of the base unit
  final List<Unit> units;
  const Category(this.name, this.base, this.units);
}

/// Table order is the order of `list` and of the `all` target.
const List<Category> categories = [
  Category('length', 'm', [
    Unit('pm', 'picometre', 1e-12),
    Unit('ang', 'ångström', 1e-10),
    Unit('nm', 'nanometre', 1e-9),
    Unit('um', 'micrometre (micron)', 1e-6),
    Unit('mm', 'millimetre', 0.001),
    Unit('cm', 'centimetre', 0.01),
    Unit('m', 'metre', 1),
    Unit('km', 'kilometre', 1000),
    Unit('in', 'inch', 0.0254),
    Unit('ft', 'foot', 0.3048),
    Unit('yd', 'yard', 0.9144),
    Unit('mi', 'mile', 1609.344),
    Unit('nmi', 'nautical mile', 1852),
    Unit('au', 'astronomical unit', 149597870700),
    Unit('ly', 'light-year', 9460730472580800),
  ]),
  Category('mass', 'kg', [
    Unit('ug', 'microgram', 1e-9),
    Unit('mg', 'milligram', 1e-6),
    Unit('ct', 'carat (metric)', 0.0002),
    Unit('gr', 'grain', 0.00006479891),
    Unit('g', 'gram', 0.001),
    Unit('kg', 'kilogram', 1),
    Unit('t', 'metric tonne', 1000),
    Unit('oz', 'ounce', 0.028349523125),
    Unit('lb', 'pound', 0.45359237),
    Unit('st', 'stone', 6.35029318),
    Unit('ton', 'US short ton (2000 lb)', 907.18474),
    Unit('lton', 'UK long ton (2240 lb)', 1016.0469088),
  ]),
  Category('area', 'm2', [
    Unit('mm2', 'square millimetre', 0.000001),
    Unit('cm2', 'square centimetre', 0.0001),
    Unit('m2', 'square metre', 1),
    Unit('ha', 'hectare', 10000),
    Unit('km2', 'square kilometre', 1000000),
    Unit('in2', 'square inch', 0.00064516),
    Unit('ft2', 'square foot', 0.09290304),
    Unit('yd2', 'square yard', 0.83612736),
    Unit('ac', 'acre', 4046.8564224),
    Unit('mi2', 'square mile', 2589988.110336),
  ]),
  Category('volume', 'l', [
    Unit('ml', 'millilitre', 0.001),
    Unit('l', 'litre', 1),
    Unit('cm3', 'cubic centimetre', 0.001),
    Unit('m3', 'cubic metre', 1000),
    Unit('in3', 'cubic inch', 0.016387064),
    Unit('ft3', 'cubic foot', 28.316846592),
    Unit('yd3', 'cubic yard', 764.554857984),
    Unit('tsp', 'US teaspoon', 0.00492892159375),
    Unit('tbsp', 'US tablespoon', 0.01478676478125),
    Unit('floz', 'US fluid ounce', 0.0295735295625),
    Unit('cup', 'US cup', 0.2365882365),
    Unit('pt', 'US pint', 0.473176473),
    Unit('qt', 'US quart', 0.946352946),
    Unit('gal', 'US gallon', 3.785411784),
    Unit('impfloz', 'imperial fluid ounce', 0.0284130625),
    Unit('imppt', 'imperial pint', 0.56826125),
    Unit('impqt', 'imperial quart', 1.1365225),
    Unit('impgal', 'imperial gallon', 4.54609),
  ]),
  Category('time', 's', [
    Unit('ns', 'nanosecond', 1e-9),
    Unit('us', 'microsecond', 1e-6),
    Unit('ms', 'millisecond', 0.001),
    Unit('s', 'second', 1),
    Unit('min', 'minute', 60),
    Unit('h', 'hour', 3600),
    Unit('d', 'day', 86400),
    Unit('wk', 'week', 604800),
  ]),
  Category('speed', 'mps', [
    Unit('mps', 'metre per second', 1),
    Unit('kmh', 'kilometre per hour', 1000 / 3600),
    Unit('mph', 'mile per hour', 0.44704),
    Unit('kn', 'knot', 1852 / 3600),
    Unit('fps', 'foot per second', 0.3048),
  ]),
  Category('digital', 'bit', [
    Unit('bit', 'bit', 1),
    Unit('nibble', 'nibble', 4),
    Unit('byte', 'byte', 8),
    Unit('kbit', 'kilobit', 1000),
    Unit('mbit', 'megabit', 1000000),
    Unit('gbit', 'gigabit', 1000000000),
    Unit('tbit', 'terabit', 1000000000000),
    Unit('kb', 'kilobyte', 8000),
    Unit('mb', 'megabyte', 8000000),
    Unit('gb', 'gigabyte', 8000000000),
    Unit('tb', 'terabyte', 8000000000000),
    Unit('pb', 'petabyte', 8000000000000000),
    Unit('eb', 'exabyte', 8000000000000000000),
  ]),
  Category('energy', 'j', [
    Unit('ev', 'electronvolt', 1.602176634e-19),
    Unit('erg', 'erg', 0.0000001),
    Unit('j', 'joule', 1),
    Unit('kj', 'kilojoule', 1000),
    Unit('cal', 'thermochemical (thermal) calorie', 4.184),
    Unit('kcal', 'kilocalorie (food Calorie)', 4184),
    Unit('wh', 'watt-hour', 3600),
    Unit('kwh', 'kilowatt-hour', 3600000),
    Unit('btu', 'British thermal unit (International Table)', 1055.05585262),
    Unit('ftlb', 'foot-pound force', 1.3558179483314004),
  ]),
  Category('power', 'w', [
    Unit('w', 'watt', 1),
    Unit('kw', 'kilowatt', 1000),
    Unit('gw', 'gigawatt', 1000000000),
    Unit('hp', 'mechanical horsepower', 745.69987158227022),
    Unit('ps', 'metric horsepower (PS)', 735.49875),
    Unit('btuh', 'BTU (IT) per hour', 1055.05585262 / 3600),
    Unit('btumin', 'BTU (IT) per minute', 1055.05585262 / 60),
    Unit('ftlbmin', 'foot-pound force per minute', 1.3558179483314004 / 60),
  ]),
  Category('pressure', 'pa', [
    Unit('pa', 'pascal', 1),
    Unit('hpa', 'hectopascal', 100),
    Unit('kpa', 'kilopascal', 1000),
    Unit('mpa', 'megapascal', 1000000),
    Unit('mbar', 'millibar', 100),
    Unit('bar', 'bar', 100000),
    Unit('atm', 'standard atmosphere', 101325),
    Unit('psi', 'pound-force per square inch', 6894.757293168361),
    Unit('mmhg', 'millimetre of mercury (conventional)', 133.322387415),
    Unit('inhg', 'inch of mercury (conventional)', 25.4 * 133.322387415),
    Unit('torr', 'torr', 101325 / 760),
  ]),
  Category('angle', 'deg', [
    Unit('deg', 'degree', 1),
    Unit('rad', 'radian', 180 / math.pi),
    Unit('grad', 'gradian (gon)', 0.9),
    Unit('turn', 'full turn (revolution)', 360),
    Unit('arcmin', 'arcminute', 1 / 60),
    Unit('arcsec', 'arcsecond', 1 / 3600),
  ]),
  // Temperature is formula-based; the factor is unused.
  Category('temperature', 'c', [
    Unit('c', 'degree Celsius', 1),
    Unit('f', 'degree Fahrenheit', 1),
    Unit('k', 'kelvin', 1),
  ]),
];

class UnitRef {
  final Category cat;
  final Unit unit;
  const UnitRef(this.cat, this.unit);
}

/// Symbols are unique across all categories, so the category is inferred.
final Map<String, UnitRef> unitIndex = {
  for (final c in categories)
    for (final u in c.units) u.symbol: UnitRef(c, u),
};