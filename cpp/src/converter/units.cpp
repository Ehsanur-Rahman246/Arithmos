// Unit tables, one-to-one with spec §5.3 (adding a unit is a data change).
// Exact ratios (1000/3600, 101325/760, 180/pi, ...) are written as expressions.
#include "converter/converter.hpp"

#include "shared/text.hpp"

namespace arithmos::converter {
namespace {

constexpr double kPi = 3.14159265358979323846;

const std::vector<Category>& build() {
  static const std::vector<Category> data = {
      {"length", "m", {
          {"pm", "picometre", 0.000000000001},
          {"ang", "ångström", 0.0000000001},
          {"nm", "nanometre", 0.000000001},
          {"um", "micrometre (micron)", 0.000001},
          {"mm", "millimetre", 0.001},
          {"cm", "centimetre", 0.01},
          {"m", "metre", 1},
          {"km", "kilometre", 1000},
          {"in", "inch", 0.0254},
          {"ft", "foot", 0.3048},
          {"yd", "yard", 0.9144},
          {"mi", "mile", 1609.344},
          {"nmi", "nautical mile", 1852},
          {"au", "astronomical unit", 149597870700.0},
          {"ly", "light-year", 9460730472580800.0}}},
      {"mass", "kg", {
          {"ug", "microgram", 0.000000001},
          {"mg", "milligram", 0.000001},
          {"ct", "carat (metric)", 0.0002},
          {"gr", "grain", 0.00006479891},
          {"g", "gram", 0.001},
          {"kg", "kilogram", 1},
          {"t", "metric tonne", 1000},
          {"oz", "ounce", 0.028349523125},
          {"lb", "pound", 0.45359237},
          {"st", "stone", 6.35029318},
          {"ton", "US short ton (2000 lb)", 907.18474},
          {"lton", "UK long ton (2240 lb)", 1016.0469088}}},
      {"area", "m2", {
          {"mm2", "square millimetre", 0.000001},
          {"cm2", "square centimetre", 0.0001},
          {"m2", "square metre", 1},
          {"ha", "hectare", 10000},
          {"km2", "square kilometre", 1000000},
          {"in2", "square inch", 0.00064516},
          {"ft2", "square foot", 0.09290304},
          {"yd2", "square yard", 0.83612736},
          {"ac", "acre", 4046.8564224},
          {"mi2", "square mile", 2589988.110336}}},
      {"volume", "l", {
          {"ml", "millilitre", 0.001},
          {"l", "litre", 1},
          {"cm3", "cubic centimetre", 0.001},
          {"m3", "cubic metre", 1000},
          {"in3", "cubic inch", 0.016387064},
          {"ft3", "cubic foot", 28.316846592},
          {"yd3", "cubic yard", 764.554857984},
          {"tsp", "US teaspoon", 0.00492892159375},
          {"tbsp", "US tablespoon", 0.01478676478125},
          {"floz", "US fluid ounce", 0.0295735295625},
          {"cup", "US cup", 0.2365882365},
          {"pt", "US pint", 0.473176473},
          {"qt", "US quart", 0.946352946},
          {"gal", "US gallon", 3.785411784},
          {"impfloz", "imperial fluid ounce", 0.0284130625},
          {"imppt", "imperial pint", 0.56826125},
          {"impqt", "imperial quart", 1.1365225},
          {"impgal", "imperial gallon", 4.54609}}},
      {"time", "s", {
          {"ns", "nanosecond", 0.000000001},
          {"us", "microsecond", 0.000001},
          {"ms", "millisecond", 0.001},
          {"s", "second", 1},
          {"min", "minute", 60},
          {"h", "hour", 3600},
          {"d", "day", 86400},
          {"wk", "week", 604800}}},
      {"speed", "mps", {
          {"mps", "metre per second", 1},
          {"kmh", "kilometre per hour", 1000.0 / 3600.0},
          {"mph", "mile per hour", 0.44704},
          {"kn", "knot", 1852.0 / 3600.0},
          {"fps", "foot per second", 0.3048}}},
      {"digital", "bit", {
          {"bit", "bit", 1},
          {"nibble", "nibble", 4},
          {"byte", "byte", 8},
          {"kbit", "kilobit", 1e3},
          {"mbit", "megabit", 1e6},
          {"gbit", "gigabit", 1e9},
          {"tbit", "terabit", 1e12},
          {"kb", "kilobyte", 8e3},
          {"mb", "megabyte", 8e6},
          {"gb", "gigabyte", 8e9},
          {"tb", "terabyte", 8e12},
          {"pb", "petabyte", 8e15},
          {"eb", "exabyte", 8e18}}},
      {"energy", "j", {
          {"ev", "electronvolt", 1.602176634e-19},
          {"erg", "erg", 0.0000001},
          {"j", "joule", 1},
          {"kj", "kilojoule", 1000},
          {"cal", "thermochemical (thermal) calorie", 4.184},
          {"kcal", "kilocalorie (food Calorie)", 4184},
          {"wh", "watt-hour", 3600},
          {"kwh", "kilowatt-hour", 3600000},
          {"btu", "British thermal unit (International Table)", 1055.05585262},
          {"ftlb", "foot-pound force", 1.3558179483314004}}},
      {"power", "w", {
          {"w", "watt", 1},
          {"kw", "kilowatt", 1000},
          {"gw", "gigawatt", 1000000000},
          {"hp", "mechanical horsepower", 745.69987158227022},
          {"ps", "metric horsepower (PS)", 735.49875},
          {"btuh", "BTU (IT) per hour", 1055.05585262 / 3600.0},
          {"btumin", "BTU (IT) per minute", 1055.05585262 / 60.0},
          {"ftlbmin", "foot-pound force per minute", 1.3558179483314004 / 60.0}}},
      {"pressure", "pa", {
          {"pa", "pascal", 1},
          {"hpa", "hectopascal", 100},
          {"kpa", "kilopascal", 1000},
          {"mpa", "megapascal", 1000000},
          {"mbar", "millibar", 100},
          {"bar", "bar", 100000},
          {"atm", "standard atmosphere", 101325},
          {"psi", "pound-force per square inch", 6894.757293168361},
          {"mmhg", "millimetre of mercury (conventional)", 133.322387415},
          {"inhg", "inch of mercury (conventional)", 3386.388640341},
          {"torr", "torr", 101325.0 / 760.0}}},
      {"angle", "deg", {
          {"deg", "degree", 1},
          {"rad", "radian", 180.0 / kPi},
          {"grad", "gradian (gon)", 0.9},
          {"turn", "full turn (revolution)", 360},
          {"arcmin", "arcminute", 1.0 / 60.0},
          {"arcsec", "arcsecond", 1.0 / 3600.0}}},
      // Temperature is formula-based (offsets), so the factors here are unused.
      {"temperature", "c", {
          {"c", "celsius", 1},
          {"f", "fahrenheit", 1},
          {"k", "kelvin", 1}}},
  };
  return data;
}

}  // namespace

const std::vector<Category>& categories() { return build(); }

const Category* findCategory(const std::string& name) {
  const std::string n = text::lower(name);
  for (const Category& c : build())
    if (c.name == n) return &c;
  return nullptr;
}

const Unit* findUnit(const std::string& symbol, const Category** category) {
  const std::string s = text::lower(symbol);
  for (const Category& c : build())
    for (const Unit& u : c.units)
      if (u.symbol == s) {
        if (category) *category = &c;
        return &u;
      }
  return nullptr;
}

}  // namespace arithmos::converter