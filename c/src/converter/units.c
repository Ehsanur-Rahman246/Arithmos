/* Unit tables (spec 5.3). Factor = base units per one of the unit. Ratios the
 * spec names as exact (1000/3600, 101325/760, 180/pi, ...) are written as
 * expressions so the compiler folds them at full precision. */
#include "converter/units.h"

#define AR_PI 3.14159265358979323846
#define MMHG 133.322387415
#define BTU 1055.05585262
#define FTLB 1.3558179483314004

static const ConvUnit LENGTH[] = {
    {"pm", "picometre", 0.000000000001},
    {"ang",  "\xc3\xa5ngstr\xc3\xb6m", 0.0000000001},
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
    {"ly", "light-year", 9460730472580800.0}
};

static const ConvUnit MASS[] = {
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
    {"lton", "UK long ton (2240 lb)", 1016.0469088}
};

static const ConvUnit AREA[] = {
    {"mm2", "square millimetre", 0.000001},
    {"cm2", "square centimetre", 0.0001},
    {"m2", "square metre", 1},
    {"ha", "hectare", 10000},
    {"km2", "square kilometre", 1000000},
    {"in2", "square inch", 0.00064516},
    {"ft2", "square foot", 0.09290304},
    {"yd2", "square yard", 0.83612736},
    {"ac", "acre", 4046.8564224},
    {"mi2", "square mile", 2589988.110336}
};

static const ConvUnit VOLUME[] = {
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
    {"impgal", "imperial gallon", 4.54609}
};

static const ConvUnit TIME[] = {
    {"ns", "nanosecond", 0.000000001},
    {"us", "microsecond", 0.000001},
    {"ms", "millisecond", 0.001},
    {"s", "second", 1},
    {"min", "minute", 60},
    {"h", "hour", 3600},
    {"d", "day", 86400},
    {"wk", "week", 604800}
};

static const ConvUnit SPEED[] = {
    {"mps", "metre per second", 1},
    {"kmh", "kilometre per hour", 1000.0 / 3600.0},
    {"mph", "mile per hour", 0.44704},
    {"kn", "knot", 1852.0 / 3600.0},
    {"fps", "foot per second", 0.3048}
};

static const ConvUnit DIGITAL[] = {
    {"bit", "bit", 1},
    {"nibble", "nibble", 4},
    {"byte", "byte", 8},
    {"kbit", "kilobit", 1000.0},
    {"mbit", "megabit", 1000000.0},
    {"gbit", "gigabit", 1000000000.0},
    {"tbit", "terabit", 1000000000000.0},
    {"kb", "kilobyte", 8000.0},
    {"mb", "megabyte", 8000000.0},
    {"gb", "gigabyte", 8000000000.0},
    {"tb", "terabyte", 8000000000000.0},
    {"pb", "petabyte", 8000000000000000.0},
    {"eb", "exabyte", 8000000000000000000.0}
};

static const ConvUnit ENERGY[] = {
    {"ev", "electronvolt", 1.602176634e-19},
    {"erg", "erg", 0.0000001},
    {"j", "joule", 1},
    {"kj", "kilojoule", 1000},
    {"cal", "thermochemical calorie", 4.184},
    {"kcal", "kilocalorie (food Calorie)", 4184},
    {"wh", "watt-hour", 3600},
    {"kwh", "kilowatt-hour", 3600000},
    {"btu", "British thermal unit (IT)", BTU},
    {"ftlb", "foot-pound force", FTLB}
};

static const ConvUnit POWER[] = {
    {"w", "watt", 1},
    {"kw", "kilowatt", 1000},
    {"gw", "gigawatt", 1000000000.0},
    {"hp", "mechanical horsepower", 745.69987158227022},
    {"ps", "metric horsepower (PS)", 735.49875},
    {"btuh", "BTU (IT) per hour", BTU / 3600.0},
    {"btumin", "BTU (IT) per minute", BTU / 60.0},
    {"ftlbmin", "foot-pound force per minute", FTLB / 60.0}
};

static const ConvUnit PRESSURE[] = {
    {"pa", "pascal", 1},
    {"hpa", "hectopascal", 100},
    {"kpa", "kilopascal", 1000},
    {"mpa", "megapascal", 1000000},
    {"mbar", "millibar", 100},
    {"bar", "bar", 100000},
    {"atm", "standard atmosphere", 101325},
    {"psi", "pound-force per square inch", 6894.757293168361},
    {"mmhg", "millimetre of mercury", MMHG},
    {"inhg", "inch of mercury", 25.4 * MMHG},
    {"torr", "torr", 101325.0 / 760.0}
};

static const ConvUnit ANGLE[] = {
    {"deg", "degree", 1},
    {"rad", "radian", 180.0 / AR_PI},
    {"grad", "gradian (gon)", 0.9},
    {"turn", "full turn", 360},
    {"arcmin", "arcminute", 1.0 / 60.0},
    {"arcsec", "arcsecond", 1.0 / 3600.0}
};

/* Temperature is formula-based; the factor column is unused. */
static const ConvUnit TEMPERATURE[] = {
    {"c", "degree Celsius", 0},
    {"f", "degree Fahrenheit", 0},
    {"k", "kelvin", 0}
};

#define COUNT(a) ((int)(sizeof(a) / sizeof((a)[0])))

const ConvCategory CONV_CATEGORIES[] = {
    {"length", "m", LENGTH, COUNT(LENGTH), 0},
    {"mass", "kg", MASS, COUNT(MASS), 0},
    {"area", "m2", AREA, COUNT(AREA), 0},
    {"volume", "l", VOLUME, COUNT(VOLUME), 0},
    {"time", "s", TIME, COUNT(TIME), 0},
    {"speed", "mps", SPEED, COUNT(SPEED), 0},
    {"digital", "bit", DIGITAL, COUNT(DIGITAL), 0},
    {"energy", "j", ENERGY, COUNT(ENERGY), 0},
    {"power", "w", POWER, COUNT(POWER), 0},
    {"pressure", "pa", PRESSURE, COUNT(PRESSURE), 0},
    {"angle", "deg", ANGLE, COUNT(ANGLE), 0},
    {"temperature", "c", TEMPERATURE, COUNT(TEMPERATURE), 1}
};

const int CONV_CATEGORY_COUNT = COUNT(CONV_CATEGORIES);
