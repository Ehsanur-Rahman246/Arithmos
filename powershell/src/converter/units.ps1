# Unit tables (spec §5.3) as DATA. Adding a unit is a data change.
# s = symbol, n = display name (exactly as in the spec, R33), f = factor in base units.
# Ratios the spec names are written as expressions so they stay exact.

$global:ArCategories = @(
    @{ name = 'length'; base = 'm'; units = @(
        @{ s = 'pm';  n = 'picometre';           f = 1e-12 },
        @{ s = 'ang'; n = 'ångström';            f = 1e-10 },
        @{ s = 'nm';  n = 'nanometre';           f = 1e-9 },
        @{ s = 'um';  n = 'micrometre (micron)'; f = 1e-6 },
        @{ s = 'mm';  n = 'millimetre';          f = 0.001 },
        @{ s = 'cm';  n = 'centimetre';          f = 0.01 },
        @{ s = 'm';   n = 'metre';               f = 1 },
        @{ s = 'km';  n = 'kilometre';           f = 1000 },
        @{ s = 'in';  n = 'inch';                f = 0.0254 },
        @{ s = 'ft';  n = 'foot';                f = 0.3048 },
        @{ s = 'yd';  n = 'yard';                f = 0.9144 },
        @{ s = 'mi';  n = 'mile';                f = 1609.344 },
        @{ s = 'nmi'; n = 'nautical mile';       f = 1852 },
        @{ s = 'au';  n = 'astronomical unit';   f = 149597870700 },
        @{ s = 'ly';  n = 'light-year';          f = 9460730472580800 }
    ) },
    @{ name = 'mass'; base = 'kg'; units = @(
        @{ s = 'ug';   n = 'microgram';              f = 1e-9 },
        @{ s = 'mg';   n = 'milligram';              f = 1e-6 },
        @{ s = 'ct';   n = 'carat (metric)';         f = 0.0002 },
        @{ s = 'gr';   n = 'grain';                  f = 0.00006479891 },
        @{ s = 'g';    n = 'gram';                   f = 0.001 },
        @{ s = 'kg';   n = 'kilogram';               f = 1 },
        @{ s = 't';    n = 'metric tonne';           f = 1000 },
        @{ s = 'oz';   n = 'ounce';                  f = 0.028349523125 },
        @{ s = 'lb';   n = 'pound';                  f = 0.45359237 },
        @{ s = 'st';   n = 'stone';                  f = 6.35029318 },
        @{ s = 'ton';  n = 'US short ton (2000 lb)'; f = 907.18474 },
        @{ s = 'lton'; n = 'UK long ton (2240 lb)';  f = 1016.0469088 }
    ) },
    @{ name = 'area'; base = 'm2'; units = @(
        @{ s = 'mm2'; n = 'square millimetre'; f = 1e-6 },
        @{ s = 'cm2'; n = 'square centimetre'; f = 0.0001 },
        @{ s = 'm2';  n = 'square metre';       f = 1 },
        @{ s = 'ha';  n = 'hectare';            f = 10000 },
        @{ s = 'km2'; n = 'square kilometre';   f = 1000000 },
        @{ s = 'in2'; n = 'square inch';        f = 0.00064516 },
        @{ s = 'ft2'; n = 'square foot';        f = 0.09290304 },
        @{ s = 'yd2'; n = 'square yard';        f = 0.83612736 },
        @{ s = 'ac';  n = 'acre';               f = 4046.8564224 },
        @{ s = 'mi2'; n = 'square mile';        f = 2589988.110336 }
    ) },
    @{ name = 'volume'; base = 'l'; units = @(
        @{ s = 'ml';      n = 'millilitre';           f = 0.001 },
        @{ s = 'l';       n = 'litre';                f = 1 },
        @{ s = 'cm3';     n = 'cubic centimetre';     f = 0.001 },
        @{ s = 'm3';      n = 'cubic metre';          f = 1000 },
        @{ s = 'in3';     n = 'cubic inch';           f = 0.016387064 },
        @{ s = 'ft3';     n = 'cubic foot';           f = 28.316846592 },
        @{ s = 'yd3';     n = 'cubic yard';           f = 764.554857984 },
        @{ s = 'tsp';     n = 'US teaspoon';          f = 0.00492892159375 },
        @{ s = 'tbsp';    n = 'US tablespoon';        f = 0.01478676478125 },
        @{ s = 'floz';    n = 'US fluid ounce';       f = 0.0295735295625 },
        @{ s = 'cup';     n = 'US cup';               f = 0.2365882365 },
        @{ s = 'pt';      n = 'US pint';              f = 0.473176473 },
        @{ s = 'qt';      n = 'US quart';             f = 0.946352946 },
        @{ s = 'gal';     n = 'US gallon';            f = 3.785411784 },
        @{ s = 'impfloz'; n = 'imperial fluid ounce'; f = 0.0284130625 },
        @{ s = 'imppt';   n = 'imperial pint';        f = 0.56826125 },
        @{ s = 'impqt';   n = 'imperial quart';       f = 1.1365225 },
        @{ s = 'impgal';  n = 'imperial gallon';      f = 4.54609 }
    ) },
    @{ name = 'time'; base = 's'; units = @(
        @{ s = 'ns';  n = 'nanosecond';  f = 1e-9 },
        @{ s = 'us';  n = 'microsecond'; f = 1e-6 },
        @{ s = 'ms';  n = 'millisecond'; f = 0.001 },
        @{ s = 's';   n = 'second';      f = 1 },
        @{ s = 'min'; n = 'minute';      f = 60 },
        @{ s = 'h';   n = 'hour';        f = 3600 },
        @{ s = 'd';   n = 'day';         f = 86400 },
        @{ s = 'wk';  n = 'week';        f = 604800 }
    ) },
    @{ name = 'speed'; base = 'mps'; units = @(
        @{ s = 'mps'; n = 'metre per second';     f = 1 },
        @{ s = 'kmh'; n = 'kilometre per hour';   f = 1000 / 3600 },
        @{ s = 'mph'; n = 'mile per hour';        f = 0.44704 },
        @{ s = 'kn';  n = 'knot';                 f = 1852 / 3600 },
        @{ s = 'fps'; n = 'foot per second';      f = 0.3048 }
    ) },
    @{ name = 'digital'; base = 'bit'; units = @(
        @{ s = 'bit';    n = 'bit';      f = 1 },
        @{ s = 'nibble'; n = 'nibble';   f = 4 },
        @{ s = 'byte';   n = 'byte';     f = 8 },
        @{ s = 'kbit';   n = 'kilobit';  f = 1e3 },
        @{ s = 'mbit';   n = 'megabit';  f = 1e6 },
        @{ s = 'gbit';   n = 'gigabit';  f = 1e9 },
        @{ s = 'tbit';   n = 'terabit';  f = 1e12 },
        @{ s = 'kb';     n = 'kilobyte'; f = 8e3 },
        @{ s = 'mb';     n = 'megabyte'; f = 8e6 },
        @{ s = 'gb';     n = 'gigabyte'; f = 8e9 },
        @{ s = 'tb';     n = 'terabyte'; f = 8e12 },
        @{ s = 'pb';     n = 'petabyte'; f = 8e15 },
        @{ s = 'eb';     n = 'exabyte';  f = 8e18 }
    ) },
    @{ name = 'energy'; base = 'j'; units = @(
        @{ s = 'ev';   n = 'electronvolt';                            f = 1.602176634e-19 },
        @{ s = 'erg';  n = 'erg';                                     f = 1e-7 },
        @{ s = 'j';    n = 'joule';                                   f = 1 },
        @{ s = 'kj';   n = 'kilojoule';                               f = 1000 },
        @{ s = 'cal';  n = 'thermochemical (thermal) calorie';        f = 4.184 },
        @{ s = 'kcal'; n = 'kilocalorie (food Calorie)';              f = 4184 },
        @{ s = 'wh';   n = 'watt-hour';                               f = 3600 },
        @{ s = 'kwh';  n = 'kilowatt-hour';                           f = 3600000 },
        @{ s = 'btu';  n = 'British thermal unit (International Table)'; f = 1055.05585262 },
        @{ s = 'ftlb'; n = 'foot-pound force';                        f = 1.3558179483314004 }
    ) },
    @{ name = 'power'; base = 'w'; units = @(
        @{ s = 'w';       n = 'watt';                         f = 1 },
        @{ s = 'kw';      n = 'kilowatt';                     f = 1000 },
        @{ s = 'gw';      n = 'gigawatt';                     f = 1e9 },
        @{ s = 'hp';      n = 'mechanical horsepower';        f = 745.69987158227022 },
        @{ s = 'ps';      n = 'metric horsepower (PS)';       f = 735.49875 },
        @{ s = 'btuh';    n = 'BTU (IT) per hour';            f = 1055.05585262 / 3600 },
        @{ s = 'btumin';  n = 'BTU (IT) per minute';          f = 1055.05585262 / 60 },
        @{ s = 'ftlbmin'; n = 'foot-pound force per minute';  f = 1.3558179483314004 / 60 }
    ) },
    @{ name = 'pressure'; base = 'pa'; units = @(
        @{ s = 'pa';   n = 'pascal';                               f = 1 },
        @{ s = 'hpa';  n = 'hectopascal';                          f = 100 },
        @{ s = 'kpa';  n = 'kilopascal';                           f = 1000 },
        @{ s = 'mpa';  n = 'megapascal';                           f = 1e6 },
        @{ s = 'mbar'; n = 'millibar';                             f = 100 },
        @{ s = 'bar';  n = 'bar';                                  f = 100000 },
        @{ s = 'atm';  n = 'standard atmosphere';                  f = 101325 },
        @{ s = 'psi';  n = 'pound-force per square inch';          f = 6894.757293168361 },
        @{ s = 'mmhg'; n = 'millimetre of mercury (conventional)'; f = 133.322387415 },
        @{ s = 'inhg'; n = 'inch of mercury (conventional)';       f = 3386.388640341 },
        @{ s = 'torr'; n = 'torr';                                 f = 101325 / 760 }
    ) },
    @{ name = 'angle'; base = 'deg'; units = @(
        @{ s = 'deg';    n = 'degree';                  f = 1 },
        @{ s = 'rad';    n = 'radian';                  f = 180 / [math]::PI },
        @{ s = 'grad';   n = 'gradian (gon)';           f = 0.9 },
        @{ s = 'turn';   n = 'full turn (revolution)';  f = 360 },
        @{ s = 'arcmin'; n = 'arcminute';               f = 1 / 60 },
        @{ s = 'arcsec'; n = 'arcsecond';               f = 1 / 3600 }
    ) },
    # Temperature is formula-based; the factors here are unused (see converter.ps1).
    @{ name = 'temperature'; base = 'c'; units = @(
        @{ s = 'c'; n = 'degree Celsius';    f = 1 },
        @{ s = 'f'; n = 'degree Fahrenheit'; f = 1 },
        @{ s = 'k'; n = 'kelvin';            f = 1 }
    ) }
)

# symbol -> @{ u = unit; cat = category }. Symbols are unique across all categories and
# matched case-insensitively (PowerShell hashtables ignore case), so the category is
# always inferred from the symbols.
$global:ArUnitIndex = @{}
foreach ($cat in $global:ArCategories) {
    foreach ($u in $cat.units) {
        $global:ArUnitIndex[$u.s] = @{ u = $u; cat = $cat }
    }
}