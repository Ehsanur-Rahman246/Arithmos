# converter/units.sh — the unit tables as DATA (spec §5.3). Adding a unit is a data change.
# Format: category|symbol|name|factor   (factor = base units per one of this unit).
# A factor may be a ratio "a/b" (b may be "pi"); the awk engine evaluates it, so the
# spec's exact ratios (1000/3600, 101325/760, 180/pi, …) are used rather than rounded decimals.
# Row order is the order used by `list` and by the `all` target.

read -r -d '' UNITS_DATA <<'EOF'
length|pm|picometre|0.000000000001
length|ang|ångström|0.0000000001
length|nm|nanometre|0.000000001
length|um|micrometre (micron)|0.000001
length|mm|millimetre|0.001
length|cm|centimetre|0.01
length|m|metre|1
length|km|kilometre|1000
length|in|inch|0.0254
length|ft|foot|0.3048
length|yd|yard|0.9144
length|mi|mile|1609.344
length|nmi|nautical mile|1852
length|au|astronomical unit|149597870700
length|ly|light-year|9460730472580800
mass|ug|microgram|0.000000001
mass|mg|milligram|0.000001
mass|ct|carat (metric)|0.0002
mass|gr|grain|0.00006479891
mass|g|gram|0.001
mass|kg|kilogram|1
mass|t|metric tonne|1000
mass|oz|ounce|0.028349523125
mass|lb|pound|0.45359237
mass|st|stone|6.35029318
mass|ton|US short ton (2000 lb)|907.18474
mass|lton|UK long ton (2240 lb)|1016.0469088
area|mm2|square millimetre|0.000001
area|cm2|square centimetre|0.0001
area|m2|square metre|1
area|ha|hectare|10000
area|km2|square kilometre|1000000
area|in2|square inch|0.00064516
area|ft2|square foot|0.09290304
area|yd2|square yard|0.83612736
area|ac|acre|4046.8564224
area|mi2|square mile|2589988.110336
volume|ml|millilitre|0.001
volume|l|litre|1
volume|cm3|cubic centimetre|0.001
volume|m3|cubic metre|1000
volume|in3|cubic inch|0.016387064
volume|ft3|cubic foot|28.316846592
volume|yd3|cubic yard|764.554857984
volume|tsp|US teaspoon|0.00492892159375
volume|tbsp|US tablespoon|0.01478676478125
volume|floz|US fluid ounce|0.0295735295625
volume|cup|US cup|0.2365882365
volume|pt|US pint|0.473176473
volume|qt|US quart|0.946352946
volume|gal|US gallon|3.785411784
volume|impfloz|imperial fluid ounce|0.0284130625
volume|imppt|imperial pint|0.56826125
volume|impqt|imperial quart|1.1365225
volume|impgal|imperial gallon|4.54609
time|ns|nanosecond|0.000000001
time|us|microsecond|0.000001
time|ms|millisecond|0.001
time|s|second|1
time|min|minute|60
time|h|hour|3600
time|d|day|86400
time|wk|week|604800
speed|mps|metre per second|1
speed|kmh|kilometre per hour|1000/3600
speed|mph|mile per hour|0.44704
speed|kn|knot|1852/3600
speed|fps|foot per second|0.3048
digital|bit|bit|1
digital|nibble|nibble|4
digital|byte|byte|8
digital|kbit|kilobit|1000
digital|mbit|megabit|1000000
digital|gbit|gigabit|1000000000
digital|tbit|terabit|1000000000000
digital|kb|kilobyte|8000
digital|mb|megabyte|8000000
digital|gb|gigabyte|8000000000
digital|tb|terabyte|8000000000000
digital|pb|petabyte|8000000000000000
digital|eb|exabyte|8000000000000000000
energy|ev|electronvolt|1.602176634e-19
energy|erg|erg|0.0000001
energy|j|joule|1
energy|kj|kilojoule|1000
energy|cal|thermochemical (thermal) calorie|4.184
energy|kcal|kilocalorie (food Calorie)|4184
energy|wh|watt-hour|3600
energy|kwh|kilowatt-hour|3600000
energy|btu|British thermal unit (International Table)|1055.05585262
energy|ftlb|foot-pound force|1.3558179483314004
power|w|watt|1
power|kw|kilowatt|1000
power|gw|gigawatt|1000000000
power|hp|mechanical horsepower|745.69987158227022
power|ps|metric horsepower (PS)|735.49875
power|btuh|BTU (IT) per hour|1055.05585262/3600
power|btumin|BTU (IT) per minute|1055.05585262/60
power|ftlbmin|foot-pound force per minute|1.3558179483314004/60
pressure|pa|pascal|1
pressure|hpa|hectopascal|100
pressure|kpa|kilopascal|1000
pressure|mpa|megapascal|1000000
pressure|mbar|millibar|100
pressure|bar|bar|100000
pressure|atm|standard atmosphere|101325
pressure|psi|pound-force per square inch|6894.757293168361
pressure|mmhg|millimetre of mercury (conventional)|133.322387415
pressure|inhg|inch of mercury (conventional)|3386.388640341
pressure|torr|torr|101325/760
angle|deg|degree|1
angle|rad|radian|180/pi
angle|grad|gradian (gon)|0.9
angle|turn|full turn (revolution)|360
angle|arcmin|arcminute|1/60
angle|arcsec|arcsecond|1/3600
temperature|c|degree Celsius|0
temperature|f|degree Fahrenheit|0
temperature|k|kelvin|0
EOF

declare -A U_CAT U_NAME U_FAC      # symbol → category / display name / factor text
declare -A CAT_SYMS                # category → "sym sym sym" in table order
CATEGORIES=()                      # category names in table order (the `list` order)

# units_load — parse UNITS_DATA once, at source time.
units_load() {
    local cat sym name fac
    while IFS='|' read -r cat sym name fac; do
        [[ -z $cat ]] && continue
        if [[ -z ${CAT_SYMS[$cat]+x} ]]; then CATEGORIES+=("$cat"); CAT_SYMS[$cat]=""; fi
        U_CAT[$sym]=$cat; U_NAME[$sym]=$name; U_FAC[$sym]=$fac
        CAT_SYMS[$cat]+="${CAT_SYMS[$cat]:+ }$sym"
    done <<<"$UNITS_DATA"
}
units_load