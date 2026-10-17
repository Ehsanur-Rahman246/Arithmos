// Data-driven unit tables (spec 5.3). One entry per category:
//   { name, base, units: [{ symbol, name, factor }] }
// Temperature is formula-based (no factors); its symbols live here only so
// they take part in the unique-symbol check and in list/lookup.
// Every symbol must be unique across ALL categories (checked at load time).
const u = (symbol, name, factor) => ({ symbol, name, factor });

export const CATEGORIES = [
  { name: 'length', base: 'm', units: [
    u('pm', 'picometre', 0.000000000001), u('ang', 'ångström', 0.0000000001),
    u('nm', 'nanometre', 0.000000001), u('um', 'micrometre', 0.000001),
    u('mm', 'millimetre', 0.001), u('cm', 'centimetre', 0.01), u('m', 'metre', 1),
    u('km', 'kilometre', 1000), u('in', 'inch', 0.0254), u('ft', 'foot', 0.3048),
    u('yd', 'yard', 0.9144), u('mi', 'mile', 1609.344), u('nmi', 'nautical mile', 1852),
    u('au', 'astronomical unit', 149597870700), u('ly', 'light-year', 9460730472580800),
  ] },
  { name: 'mass', base: 'kg', units: [
    u('ug', 'microgram', 0.000000001), u('mg', 'milligram', 0.000001),
    u('ct', 'carat (metric)', 0.0002), u('gr', 'grain', 0.00006479891),
    u('g', 'gram', 0.001), u('kg', 'kilogram', 1), u('t', 'metric tonne', 1000),
    u('oz', 'ounce', 0.028349523125), u('lb', 'pound', 0.45359237),
    u('st', 'stone', 6.35029318), u('ton', 'US short ton', 907.18474),
    u('lton', 'UK long ton', 1016.0469088),
  ] },
  { name: 'area', base: 'm2', units: [
    u('mm2', 'square millimetre', 0.000001), u('cm2', 'square centimetre', 0.0001),
    u('m2', 'square metre', 1), u('ha', 'hectare', 10000), u('km2', 'square kilometre', 1000000),
    u('in2', 'square inch', 0.00064516), u('ft2', 'square foot', 0.09290304),
    u('yd2', 'square yard', 0.83612736), u('ac', 'acre', 4046.8564224),
    u('mi2', 'square mile', 2589988.110336),
  ] },
  { name: 'volume', base: 'l', units: [
    u('ml', 'millilitre', 0.001), u('l', 'litre', 1), u('cm3', 'cubic centimetre', 0.001),
    u('m3', 'cubic metre', 1000), u('in3', 'cubic inch', 0.016387064),
    u('ft3', 'cubic foot', 28.316846592), u('yd3', 'cubic yard', 764.554857984),
    u('tsp', 'US teaspoon', 0.00492892159375), u('tbsp', 'US tablespoon', 0.01478676478125),
    u('floz', 'US fluid ounce', 0.0295735295625), u('cup', 'US cup', 0.2365882365),
    u('pt', 'US pint', 0.473176473), u('qt', 'US quart', 0.946352946),
    u('gal', 'US gallon', 3.785411784), u('impfloz', 'imperial fluid ounce', 0.0284130625),
    u('imppt', 'imperial pint', 0.56826125), u('impqt', 'imperial quart', 1.1365225),
    u('impgal', 'imperial gallon', 4.54609),
  ] },
  { name: 'time', base: 's', units: [
    u('ns', 'nanosecond', 0.000000001), u('us', 'microsecond', 0.000001),
    u('ms', 'millisecond', 0.001), u('s', 'second', 1), u('min', 'minute', 60),
    u('h', 'hour', 3600), u('d', 'day', 86400), u('wk', 'week', 604800),
  ] },
  { name: 'speed', base: 'mps', units: [
    u('mps', 'metre per second', 1), u('kmh', 'kilometre per hour', 1000 / 3600),
    u('mph', 'mile per hour', 0.44704), u('kn', 'knot', 1852 / 3600),
    u('fps', 'foot per second', 0.3048),
  ] },
  { name: 'digital', base: 'bit', units: [
    u('bit', 'bit', 1), u('nibble', 'nibble', 4), u('byte', 'byte', 8),
    u('kbit', 'kilobit', 1e3), u('mbit', 'megabit', 1e6), u('gbit', 'gigabit', 1e9),
    u('tbit', 'terabit', 1e12), u('kb', 'kilobyte', 8e3), u('mb', 'megabyte', 8e6),
    u('gb', 'gigabyte', 8e9), u('tb', 'terabyte', 8e12), u('pb', 'petabyte', 8e15),
    u('eb', 'exabyte', 8e18),
  ] },
  { name: 'energy', base: 'j', units: [
    u('ev', 'electronvolt', 1.602176634e-19), u('erg', 'erg', 0.0000001), u('j', 'joule', 1),
    u('kj', 'kilojoule', 1000), u('cal', 'thermochemical calorie', 4.184),
    u('kcal', 'kilocalorie (food Calorie)', 4184), u('wh', 'watt-hour', 3600),
    u('kwh', 'kilowatt-hour', 3600000), u('btu', 'British thermal unit (IT)', 1055.05585262),
    u('ftlb', 'foot-pound force', 1.3558179483314004),
  ] },
  { name: 'power', base: 'w', units: [
    u('w', 'watt', 1), u('kw', 'kilowatt', 1000), u('gw', 'gigawatt', 1000000000),
    u('hp', 'mechanical horsepower', 745.69987158227022), u('ps', 'metric horsepower', 735.49875),
    u('btuh', 'BTU (IT) per hour', 1055.05585262 / 3600),
    u('btumin', 'BTU (IT) per minute', 1055.05585262 / 60),
    u('ftlbmin', 'foot-pound force per minute', 1.3558179483314004 / 60),
  ] },
  { name: 'pressure', base: 'pa', units: [
    u('pa', 'pascal', 1), u('hpa', 'hectopascal', 100), u('kpa', 'kilopascal', 1000),
    u('mpa', 'megapascal', 1000000), u('mbar', 'millibar', 100), u('bar', 'bar', 100000),
    u('atm', 'standard atmosphere', 101325), u('psi', 'pound-force per square inch', 6894.757293168361),
    u('mmhg', 'millimetre of mercury', 133.322387415),
    u('inhg', 'inch of mercury', 25.4 * 133.322387415),
    u('torr', 'torr', 101325 / 760),
  ] },
  { name: 'angle', base: 'deg', units: [
    u('deg', 'degree', 1), u('rad', 'radian', 180 / Math.PI), u('grad', 'gradian', 0.9),
    u('turn', 'full turn', 360), u('arcmin', 'arcminute', 1 / 60), u('arcsec', 'arcsecond', 1 / 3600),
  ] },
  { name: 'temperature', base: 'c', formula: true, units: [
    { symbol: 'c', name: 'degree Celsius' },
    { symbol: 'f', name: 'degree Fahrenheit' },
    { symbol: 'k', name: 'kelvin' },
  ] },
];

// Lowercase symbol -> { category, unit }. Built once; duplicates are a bug.
export const SYMBOL_INDEX = new Map();
for (const category of CATEGORIES) {
  for (const unit of category.units) {
    if (SYMBOL_INDEX.has(unit.symbol)) throw new Error(`Duplicate unit symbol: ${unit.symbol}`);
    SYMBOL_INDEX.set(unit.symbol, { category, unit });
  }
}
