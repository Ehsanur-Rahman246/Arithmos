<?php
declare(strict_types=1);

namespace Arithmos\Converter;

/**
 * The unit tables of spec §5.3 as DATA. Adding a unit is a data change.
 *
 * Unit = [symbol, display name, factor]; factor = how many BASE units equal one
 * of that unit. Where the spec names an exact ratio (1000/3600, 101325/760,
 * 180/pi ...) the ratio is written out instead of a rounded decimal.
 * Temperature has no factors (formulas live in Converter) and comes last.
 */
final class Units
{
    /** @return list<array{name:string,units:list<array{0:string,1:string,2:?float}>}> */
    public static function categories(): array
    {
        static $cats = null;
        if ($cats !== null) {
            return $cats;
        }
        $mmhg = 133.322387415;
        $btu = 1055.05585262;
        $ftlb = 1.3558179483314004;
        $cats = [
            ['name' => 'length', 'units' => [ // base: metre
                ['pm', 'picometre', 1e-12], ['ang', 'ångström', 1e-10], ['nm', 'nanometre', 1e-9],
                ['um', 'micrometre (micron)', 1e-6], ['mm', 'millimetre', 0.001], ['cm', 'centimetre', 0.01],
                ['m', 'metre', 1.0], ['km', 'kilometre', 1000.0], ['in', 'inch', 0.0254],
                ['ft', 'foot', 0.3048], ['yd', 'yard', 0.9144], ['mi', 'mile', 1609.344],
                ['nmi', 'nautical mile', 1852.0], ['au', 'astronomical unit', 149597870700.0],
                ['ly', 'light-year', 9460730472580800.0],
            ]],
            ['name' => 'mass', 'units' => [ // base: kilogram
                ['ug', 'microgram', 1e-9], ['mg', 'milligram', 1e-6], ['ct', 'carat (metric)', 0.0002],
                ['gr', 'grain', 0.00006479891], ['g', 'gram', 0.001], ['kg', 'kilogram', 1.0],
                ['t', 'metric tonne', 1000.0], ['oz', 'ounce', 0.028349523125], ['lb', 'pound', 0.45359237],
                ['st', 'stone', 6.35029318], ['ton', 'US short ton (2000 lb)', 907.18474],
                ['lton', 'UK long ton (2240 lb)', 1016.0469088],
            ]],
            ['name' => 'area', 'units' => [ // base: square metre
                ['mm2', 'square millimetre', 1e-6], ['cm2', 'square centimetre', 0.0001], ['m2', 'square metre', 1.0],
                ['ha', 'hectare', 10000.0], ['km2', 'square kilometre', 1000000.0],
                ['in2', 'square inch', 0.00064516], ['ft2', 'square foot', 0.09290304],
                ['yd2', 'square yard', 0.83612736], ['ac', 'acre', 4046.8564224],
                ['mi2', 'square mile', 2589988.110336],
            ]],
            ['name' => 'volume', 'units' => [ // base: litre
                ['ml', 'millilitre', 0.001], ['l', 'litre', 1.0], ['cm3', 'cubic centimetre', 0.001],
                ['m3', 'cubic metre', 1000.0], ['in3', 'cubic inch', 0.016387064],
                ['ft3', 'cubic foot', 28.316846592], ['yd3', 'cubic yard', 764.554857984],
                ['tsp', 'US teaspoon', 0.00492892159375], ['tbsp', 'US tablespoon', 0.01478676478125],
                ['floz', 'US fluid ounce', 0.0295735295625], ['cup', 'US cup', 0.2365882365],
                ['pt', 'US pint', 0.473176473], ['qt', 'US quart', 0.946352946], ['gal', 'US gallon', 3.785411784],
                ['impfloz', 'imperial fluid ounce', 0.0284130625], ['imppt', 'imperial pint', 0.56826125],
                ['impqt', 'imperial quart', 1.1365225], ['impgal', 'imperial gallon', 4.54609],
            ]],
            ['name' => 'time', 'units' => [ // base: second (no months or years)
                ['ns', 'nanosecond', 1e-9], ['us', 'microsecond', 1e-6], ['ms', 'millisecond', 0.001],
                ['s', 'second', 1.0], ['min', 'minute', 60.0], ['h', 'hour', 3600.0],
                ['d', 'day', 86400.0], ['wk', 'week', 604800.0],
            ]],
            ['name' => 'speed', 'units' => [ // base: metre per second
                ['mps', 'metre per second', 1.0], ['kmh', 'kilometre per hour', 1000.0 / 3600.0],
                ['mph', 'mile per hour', 0.44704], ['kn', 'knot', 1852.0 / 3600.0],
                ['fps', 'foot per second', 0.3048],
            ]],
            ['name' => 'digital', 'units' => [ // base: bit, decimal (SI) multiples only
                ['bit', 'bit', 1.0], ['nibble', 'nibble', 4.0], ['byte', 'byte', 8.0],
                ['kbit', 'kilobit', 1e3], ['mbit', 'megabit', 1e6], ['gbit', 'gigabit', 1e9], ['tbit', 'terabit', 1e12],
                ['kb', 'kilobyte', 8e3], ['mb', 'megabyte', 8e6], ['gb', 'gigabyte', 8e9],
                ['tb', 'terabyte', 8e12], ['pb', 'petabyte', 8e15], ['eb', 'exabyte', 8e18],
            ]],
            ['name' => 'energy', 'units' => [ // base: joule
                ['ev', 'electronvolt', 1.602176634e-19], ['erg', 'erg', 1e-7], ['j', 'joule', 1.0],
                ['kj', 'kilojoule', 1000.0], ['cal', 'thermochemical (thermal) calorie', 4.184],
                ['kcal', 'kilocalorie (food Calorie)', 4184.0], ['wh', 'watt-hour', 3600.0],
                ['kwh', 'kilowatt-hour', 3600000.0], ['btu', 'British thermal unit (International Table)', $btu],
                ['ftlb', 'foot-pound force', $ftlb],
            ]],
            ['name' => 'power', 'units' => [ // base: watt
                ['w', 'watt', 1.0], ['kw', 'kilowatt', 1000.0], ['gw', 'gigawatt', 1e9],
                ['hp', 'mechanical horsepower', 745.69987158227022], ['ps', 'metric horsepower (PS)', 735.49875],
                ['btuh', 'BTU (IT) per hour', $btu / 3600.0], ['btumin', 'BTU (IT) per minute', $btu / 60.0],
                ['ftlbmin', 'foot-pound force per minute', $ftlb / 60.0],
            ]],
            ['name' => 'pressure', 'units' => [ // base: pascal
                ['pa', 'pascal', 1.0], ['hpa', 'hectopascal', 100.0], ['kpa', 'kilopascal', 1000.0],
                ['mpa', 'megapascal', 1e6], ['mbar', 'millibar', 100.0], ['bar', 'bar', 100000.0],
                ['atm', 'standard atmosphere', 101325.0], ['psi', 'pound-force per square inch', 6894.757293168361],
                ['mmhg', 'millimetre of mercury (conventional)', $mmhg],
                ['inhg', 'inch of mercury (conventional)', 25.4 * $mmhg],
                ['torr', 'torr', 101325.0 / 760.0],
            ]],
            ['name' => 'angle', 'units' => [ // base: degree
                ['deg', 'degree', 1.0], ['rad', 'radian', 180.0 / M_PI], ['grad', 'gradian (gon)', 0.9],
                ['turn', 'full turn (revolution)', 360.0], ['arcmin', 'arcminute', 1.0 / 60.0],
                ['arcsec', 'arcsecond', 1.0 / 3600.0],
            ]],
            ['name' => 'temperature', 'units' => [ // formula-based: factors are null
                ['c', 'Celsius', null], ['f', 'Fahrenheit', null], ['k', 'Kelvin', null],
            ]],
        ];
        return $cats;
    }

    /**
     * Symbols are unique across all categories (spec §5.1) and matched
     * case-insensitively, so one lookup finds the category.
     *
     * @return array{0:int,1:int}|null [category index, unit index]
     */
    public static function find(string $symbol): ?array
    {
        static $index = null;
        if ($index === null) {
            $index = [];
            foreach (self::categories() as $ci => $cat) {
                foreach ($cat['units'] as $ui => $unit) {
                    $index[$unit[0]] = [$ci, $ui];
                }
            }
        }
        return $index[strtolower($symbol)] ?? null;
    }
}