# Arithmos — Release 1: Core CLI
 
> **Three tools. Forty-three languages. One behavior contract.**
 
Release 1 is the first implementation milestone of Arithmos. It delivers three command-line tools — **Standard Calculator**, **Programmer Calculator**, and **Unit Converter** — in **every language on the selected track** (Section 9). All implementations follow this one specification so that the same input produces the same result in every language.
 
This document is the language-neutral behavior contract for Release 1. It is meant to live at `docs/specifications/release-1.md`, with the shared test cases in `docs/test-cases.md`.
 
**Out of scope for Release 1:** scientific functions beyond `sqrt`, `abs` and `^`, graphing, statistics, date calculation, currency, memory/history, binary storage units (KiB, MiB…), selectable integer width, games, and any GUI. These belong to later releases (see the full roadmap).
 
---
 
## 1. Release Goals
 
1. All three tools work in each selected language.
2. Every implementation follows this specification, including its error codes and number formatting.
3. The common test cases in Section 8 pass in every language.
4. Invalid input never crashes a program; it produces a predictable error.
5. Each language edition documents how to build, run, and test it, plus any deviations.
6. JavaScript is built first as the **reference implementation**; other languages are checked against it.
---
 
## 2. Shared Conventions
 
These rules apply to all three tools.
 
### 2.1 Application shell
 
On start, each program shows a main menu:
 
```text
Arithmos 1.0 — Core CLI
  1) Standard Calculator
  2) Programmer Calculator
  3) Unit Converter
  0) Exit
```
 
- On a real terminal the user picks with an arrow-key selector (↑↓ move, Enter selects). When stdin or stdout is not a terminal (pipes, files, tests), or when `ARITHMOS_PLAIN=1` is set, the same screens are numbered lists answered by typing a number, a name or a symbol. Both modes are required: the selector is the default on a terminal, and the numbered list is the baseline for automated tests.
- Each tool runs its own loop until the user types `back` or `quit` (exit the program).
- `back` goes back one screen; from a tool's first screen it returns to the main menu. At an arrow-key selector, Esc and `b` also mean `back` and `q` means `quit`.
- Every tool accepts `help` (or `?`), `back`, and `quit` at its prompt, case-insensitively.
- End-of-input (EOF / Ctrl-D / Ctrl-Z) exits cleanly with no error.
- An unrecognized command produces `UNKNOWN_COMMAND`.
- Programs may also accept one-shot command-line arguments (for example `arithmos convert 100 cm in`) **where idiomatic**. The interactive menu is the required baseline.
### 2.2 Error reporting
 
Errors print as a single line:
 
```text
Error [CODE]: human-readable message
```
 
Tests check the **CODE**, never the message text. Messages may be worded freely per language.
 
| Code | Meaning |
|---|---|
| `INVALID_EXPRESSION` | Malformed expression (unbalanced parentheses, missing operand, unknown token, etc.) |
| `INVALID_NUMBER` | A value is not a valid number |
| `DIV_BY_ZERO` | Division by zero, or zero raised to a negative power |
| `DOMAIN_ERROR` | Input outside a function's domain (e.g. `sqrt(-1)`, negative base with fractional exponent) |
| `UNDEFINED` | Mathematically undefined result (`0^0`) |
| `OVERFLOW` | Result too large to represent |
| `INVALID_DIGIT` | A digit is not valid in the given base |
| `INVALID_BASE` | Unknown base name |
| `OUT_OF_RANGE` | Integer outside the 64-bit signed range |
| `INVALID_SHIFT` | Shift count outside 0–63 |
| `UNKNOWN_UNIT` | Unit symbol not recognized |
| `INCOMPATIBLE_UNITS` | Units belong to different categories |
| `BELOW_ABSOLUTE_ZERO` | Temperature below 0 K |
| `UNKNOWN_COMMAND` | Command not recognized |
 
### 2.3 Number formatting (Standard Calculator and Converter)
 
Computation may use the language's native floating-point type (IEEE 754 double) or a decimal type. **Display** must follow these rules so output is identical across languages:
 
1. Round to **12 significant digits**, half away from zero.
2. Remove trailing zeros and a trailing decimal point (`2.50` → `2.5`, `3.0` → `3`).
3. Use plain decimal notation when the magnitude is between `1e-6` and `1e15` (inclusive of 1e-6, exclusive of 1e15). Otherwise use scientific notation as `<mantissa>e<sign><exponent>`, for example `1.5e+20` or `2e-7`.
4. Negative zero displays as `0`.
5. A result of infinity is an `OVERFLOW` error. NaN is never shown; it must map to an error code.
Because of rule 1, `0.1 + 0.2` displays `0.3`.
 
### 2.4 Input handling
 
- Leading and trailing whitespace is ignored. Blank input is ignored (no error, no output).
- Keywords (`and`, `not`, `of`, `back`, unit symbols, base names) are **case-insensitive**.
- Decimal separator is `.`. Thousands separators are not accepted.
---
 
## 3. Standard Calculator
 
### 3.1 Prompt and behavior
 
```text
standard> 25 + 17
42
standard> ans * 2
84
standard> 10 / 0
Error [DIV_BY_ZERO]: Cannot divide by zero
```
 
The user enters one expression per line. The calculator evaluates it, prints the result, and prompts again. Calculations repeat until `back` or `quit`. A failed expression does not change `ans`.
 
### 3.2 Supported syntax
 
| Element | Form | Notes |
|---|---|---|
| Numbers | `12`, `12.5`, `.5`, `5.` | Decimal only. Scientific notation input (`1e5`) is **not** supported in Release 1. |
| Operators | `+  -  *  /  ^` | |
| Unary minus / plus | `-5`, `+5`, `-(2+3)`, `2 * -3` | |
| Parentheses | `( )` | Arbitrary nesting. |
| Percent | `50%` | Postfix operator, see 3.4. |
| `of` | `20% of 150` | Sugar for `20% * 150`. |
| Functions | `sqrt(x)`, `abs(x)` | Parentheses required. |
| Previous result | `ans` | Last successful result; `0` before the first calculation. |
 
Implicit multiplication (`2(3)`, `2ans`) is **not** supported and is `INVALID_EXPRESSION`.
 
### 3.3 Precedence (high to low)
 
1. Parentheses, function calls
2. Postfix `%`
3. `^` (right-associative: `2^3^2 = 2^(3^2) = 512`)
4. Unary `+` / `-` (so `-2^2 = -4`)
5. `*`, `/`, `of` (left-associative)
6. `+`, `-` (left-associative)
### 3.4 Percentages
 
- A standalone percent is divided by 100: `50%` → `0.5`.
- When the **right operand of `+` or `-`** carries a `%`, it is relative to the left operand: `200 + 10%` → `220`, `200 - 10%` → `180`.
- For `*`, `/`, and `of`, the percent is simply divided by 100: `200 * 10%` → `20`, `200 / 10%` → `2000`, `20% of 150` → `30`.
### 3.5 Power and square root rules
 
| Case | Result |
|---|---|
| `sqrt(-1)` | `DOMAIN_ERROR` |
| `(-8)^(1/3)` (negative base, non-integer exponent) | `DOMAIN_ERROR` |
| `0^0` | `UNDEFINED` |
| `0^-1` | `DIV_BY_ZERO` |
| `2^-1` | `0.5` |
| `10^400` | `OVERFLOW` |
 
### 3.6 Required behavior checklist
 
- [ ] Addition, subtraction, multiplication, division
- [ ] Decimal and negative numbers
- [ ] Percentages and `of`
- [ ] Parentheses and correct precedence
- [ ] `^`, `sqrt`, `abs`
- [ ] `ans`
- [ ] Division-by-zero and domain errors
- [ ] Repeated calculation loop without restarting
- [ ] Errors for every malformed-input category
---
 
## 4. Programmer Calculator
 
### 4.1 Integer model (fixed for Release 1)
 
Every implementation emulates a **64-bit signed two's-complement integer**, regardless of the language's native integer width.
 
- Range: `-9223372036854775808` to `9223372036854775807`.
- Bitwise operations act on the 64-bit pattern.
- Selectable widths (8/16/32/64) and unsigned views arrive in Release 3.
- Languages without a native 64-bit integer (for example R, or MATLAB's default doubles) must emulate it correctly and document how.
### 4.2 Bases
 
| Name | Radix | Valid digits | Literal prefix |
|---|---|---|---|
| `bin` | 2 | `0-1` | `0b` |
| `oct` | 8 | `0-7` | `0o` |
| `dec` | 10 | `0-9` | none (or `0d`) |
| `hex` | 16 | `0-9`, `A-F` (any case) | `0x` |
 
The calculator has a current **input base**, `dec` by default. A literal with a prefix uses its own base; an unprefixed literal uses the input base. Change it with `base hex`, `base bin`, and so on.
 
### 4.3 Input rules
 
- **Decimal** input must fit the signed range, otherwise `OUT_OF_RANGE`.
- **Binary, octal, and hex** input without a minus sign is read as a raw bit pattern of up to 64 bits and reinterpreted as signed, so `0xFFFFFFFFFFFFFFFF` is `-1`. A pattern needing more than 64 bits is `OUT_OF_RANGE`.
- A leading `-` is allowed in any base and negates the magnitude (`-FF` in hex is `-255`). The magnitude must not exceed 2^63.
- A digit not valid in the base is `INVALID_DIGIT` (for example `102` in binary, `8` in octal, `G` in hex).
- Empty or non-alphanumeric garbage is `INVALID_NUMBER`.
### 4.4 Output
 
Every result is shown in all four bases, plus the signed decimal value:
 
```text
programmer> 5 AND 3
HEX: 1
DEC: 1
OCT: 1
BIN: 1
```
 
- Hex is uppercase with no prefix.
- No leading zeros (zero displays as `0`).
- No digit grouping (grouping arrives in Release 3).
- For **negative** values, `HEX`, `OCT`, and `BIN` show the full 64-bit two's-complement pattern with no minus sign; `DEC` shows the signed value. Example, `-1` → `HEX: FFFFFFFFFFFFFFFF`, `DEC: -1`.
### 4.5 Commands and operations
 
| Command | Example | Meaning |
|---|---|---|
| `<value>` | `0xFF` | Show the value in all bases |
| `base <bin\|oct\|dec\|hex>` | `base hex` | Set input base; unknown name → `INVALID_BASE` |
| `[convert] <value> <from> <to>` | `convert 255 dec hex` or `255 dec hex` | Print just the converted number in the target base, e.g. `FF` |
| `<a> AND <b>` | `5 AND 3` | Bitwise AND |
| `<a> OR <b>` | `5 OR 3` | Bitwise OR |
| `<a> XOR <b>` | `5 XOR 3` | Bitwise XOR |
| `NOT <a>` | `NOT 5` | Bitwise complement (64-bit) |
| `<a> << <n>` | `1 << 3` | Left shift |
| `<a> >> <n>` | `-8 >> 1` | Arithmetic right shift (sign-extending) |
| `<a> >>> <n>` | `-8 >>> 1` | Logical right shift (zero-filling) |
 
Rules:
 
- Release 1 evaluates **one operation per line**; chaining and operator precedence are not required.
- The shift count `n` is always a **decimal** number, regardless of input base. Valid range is `0`–`63`; anything else is `INVALID_SHIFT`.
- Left shift discards bits shifted past bit 63 and does **not** raise an error (`1 << 63` is `-9223372036854775808`).
- `convert` uses the explicit `from` base to read the value, independent of the current input base.
- The word `convert` may be omitted: a line of exactly three words whose last two are base names (`255 dec hex`) is a conversion, as in the Unit Converter (§5.1).
### 4.6 Required behavior checklist
 
- [ ] Binary, octal, decimal, hexadecimal input and output
- [ ] Base-to-base conversion (convert, optional word)
- [ ] AND, OR, XOR, NOT
- [ ] `<<`, `>>`, `>>>`
- [ ] Per-base digit validation
- [ ] Negative numbers as 64-bit two's complement
- [ ] Range and shift-count validation
- [ ] Documented method of 64-bit emulation where native support is missing
---
 
## 5. Unit Converter
 
### 5.1 Usage

The one-line forms, used by one-shot mode (`arithmos convert 100 cm in`) and accepted at every converter prompt (`converter>` below stands for any of them):
 
```text
converter> convert 100 cm in
39.3700787402
converter> 0 c f
32
converter> list length
pm, ang, nm, um, mm, cm, m, km, in, ft, yd, mi, nmi, au, ly
converter> list
length, mass, area, volume, time, speed, digital, energy, power, pressure, angle, temperature
converter> convert 1 kwh kj
3600
```

The interactive converter is a guided flow (arrow-key lists on a real terminal, numbered lists answered by typing elsewhere): category → from-unit →
to-unit → values. Only units of the chosen category are offered, so
`INCOMPATIBLE_UNITS` cannot occur in the guided flow. After the units are chosen
the prompt shows them:

```text
converter (m → yd)> 100
100 m = 109.361329834 yd
```

The prompt also accepts the full one-line forms: `100 cm in`, `convert 100 cm in`,
`<value> <from> all`, `list`, `list <category>`.
 
- `convert <value> <from> <to>` — the word `convert` may be omitted (`100 cm in`).
- `list` shows all twelve categories; `list <category>` shows its units. Category names are `length`, `mass`, `area`, `volume`, `time`, `speed`, `digital`, `energy`, `power`, `pressure`, `angle`, `temperature`.
- Every unit symbol is unique across all categories, so the category is always inferred from the symbols.
- `convert <value> <from> all` (target `all`) prints the value in every unit of the source's category, one per line as `<symbol>: <value>`, in the order the units are listed in Section 5.3, including the source unit itself. This mirrors the "see the same value in other units" view of common desktop calculators.
- Unit symbols are **case-insensitive**.
- Both units must be in the same category, otherwise `INCOMPATIBLE_UNITS`.
- An unrecognized symbol is `UNKNOWN_UNIT`; a non-numeric value is `INVALID_NUMBER`.
- Negative values are allowed (they are meaningful for temperature and harmless elsewhere).
- Output follows the number-formatting rules in Section 2.3.
### 5.2 Conversion method
 
Each category has a **base unit**. Convert `value → base → target` using the exact factors below. Factors are defined as exact values; implementations should use them as given rather than deriving them.
 
### 5.3 Units and factors
 
Factor = how many **base units** equal one of that unit.
 
**Length** — base: metre (`m`)
 
| Symbol | Unit | Factor (m) |
|---|---|---|
| `pm` | picometre | 0.000000000001 |
| `ang` | ångström | 0.0000000001 |
| `nm` | nanometre | 0.000000001 |
| `um` | micrometre (micron) | 0.000001 |
| `mm` | millimetre | 0.001 |
| `cm` | centimetre | 0.01 |
| `m` | metre | 1 |
| `km` | kilometre | 1000 |
| `in` | inch | 0.0254 |
| `ft` | foot | 0.3048 |
| `yd` | yard | 0.9144 |
| `mi` | mile | 1609.344 |
| `nmi` | nautical mile | 1852 |
| `au` | astronomical unit | 149597870700 |
| `ly` | light-year | 9460730472580800 |
 
**Mass** — base: kilogram (`kg`)
 
| Symbol | Unit | Factor (kg) |
|---|---|---|
| `ug` | microgram | 0.000000001 |
| `mg` | milligram | 0.000001 |
| `ct` | carat (metric) | 0.0002 |
| `gr` | grain | 0.00006479891 |
| `g` | gram | 0.001 |
| `kg` | kilogram | 1 |
| `t` | metric tonne | 1000 |
| `oz` | ounce | 0.028349523125 |
| `lb` | pound | 0.45359237 |
| `st` | stone | 6.35029318 |
| `ton` | US short ton (2000 lb) | 907.18474 |
| `lton` | UK long ton (2240 lb) | 1016.0469088 |
 
**Area** — base: square metre (`m2`)
 
| Symbol | Unit | Factor (m²) |
|---|---|---|
| `mm2` | square millimetre | 0.000001 |
| `cm2` | square centimetre | 0.0001 |
| `m2` | square metre | 1 |
| `ha` | hectare | 10000 |
| `km2` | square kilometre | 1000000 |
| `in2` | square inch | 0.00064516 |
| `ft2` | square foot | 0.09290304 |
| `yd2` | square yard | 0.83612736 |
| `ac` | acre | 4046.8564224 |
| `mi2` | square mile | 2589988.110336 |
 
**Volume** — base: litre (`l`). `tsp` through `gal` are US customary; UK imperial units carry the `imp` prefix; cubic units are exact.
 
| Symbol | Unit | Factor (l) |
|---|---|---|
| `ml` | millilitre | 0.001 |
| `l` | litre | 1 |
| `cm3` | cubic centimetre | 0.001 |
| `m3` | cubic metre | 1000 |
| `in3` | cubic inch | 0.016387064 |
| `ft3` | cubic foot | 28.316846592 |
| `yd3` | cubic yard | 764.554857984 |
| `tsp` | US teaspoon | 0.00492892159375 |
| `tbsp` | US tablespoon | 0.01478676478125 |
| `floz` | US fluid ounce | 0.0295735295625 |
| `cup` | US cup | 0.2365882365 |
| `pt` | US pint | 0.473176473 |
| `qt` | US quart | 0.946352946 |
| `gal` | US gallon | 3.785411784 |
| `impfloz` | imperial fluid ounce | 0.0284130625 |
| `imppt` | imperial pint | 0.56826125 |
| `impqt` | imperial quart | 1.1365225 |
| `impgal` | imperial gallon | 4.54609 |
 
**Time** — base: second (`s`)
 
| Symbol | Unit | Factor (s) |
|---|---|---|
| `ns` | nanosecond | 0.000000001 |
| `us` | microsecond | 0.000001 |
| `ms` | millisecond | 0.001 |
| `s` | second | 1 |
| `min` | minute | 60 |
| `h` | hour | 3600 |
| `d` | day | 86400 |
| `wk` | week | 604800 |
 
Months and years are **excluded** from Release 1 because their lengths are ambiguous. Calendar-aware logic comes with the Date and Time Calculator in Release 2.
 
**Speed** — base: metre per second (`mps`)
 
| Symbol | Unit | Factor (m/s) |
|---|---|---|
| `mps` | metre per second | 1 |
| `kmh` | kilometre per hour | 0.277777777777778 (= 1/3.6) |
| `mph` | mile per hour | 0.44704 |
| `kn` | knot | 0.514444444444444 (= 1852/3600) |
| `fps` | foot per second | 0.3048 |
 
For `kmh` and `kn`, compute from the exact ratios (`1000/3600`, `1852/3600`) where possible rather than from the rounded decimals above.
 
**Digital information** — base: bit (`bit`). Release 1 uses **decimal (SI)** multiples only.
 
| Symbol | Unit | Factor (bit) |
|---|---|---|
| `bit` | bit | 1 |
| `nibble` | nibble | 4 |
| `byte` | byte | 8 |
| `kbit` | kilobit | 1 000 |
| `mbit` | megabit | 1 000 000 |
| `gbit` | gigabit | 1 000 000 000 |
| `tbit` | terabit | 1 000 000 000 000 |
| `kb` | kilobyte | 8 000 |
| `mb` | megabyte | 8 000 000 |
| `gb` | gigabyte | 8 000 000 000 |
| `tb` | terabyte | 8 000 000 000 000 |
| `pb` | petabyte | 8 000 000 000 000 000 |
| `eb` | exabyte | 8 000 000 000 000 000 000 |
 
Binary units (KiB, MiB, GiB…) and the KB-versus-KiB explanation are added in Release 3.
 
**Energy** — base: joule (`j`)
 
| Symbol | Unit | Factor (J) |
|---|---|---|
| `ev` | electronvolt | 1.602176634e-19 |
| `erg` | erg | 0.0000001 |
| `j` | joule | 1 |
| `kj` | kilojoule | 1000 |
| `cal` | thermochemical (thermal) calorie | 4.184 |
| `kcal` | kilocalorie (food Calorie) | 4184 |
| `wh` | watt-hour | 3600 |
| `kwh` | kilowatt-hour | 3600000 |
| `btu` | British thermal unit (International Table) | 1055.05585262 |
| `ftlb` | foot-pound force | 1.3558179483314004 |
 
The `ev` factor is an internal constant. Scientific-notation *input* is still not accepted in Release 1; only the displayed result may use it (for example `1.602176634e-19`).
 
**Power** — base: watt (`w`)
 
| Symbol | Unit | Factor (W) |
|---|---|---|
| `w` | watt | 1 |
| `kw` | kilowatt | 1000 |
| `gw` | gigawatt | 1000000000 |
| `hp` | mechanical horsepower | 745.69987158227022 |
| `ps` | metric horsepower (PS) | 735.49875 |
| `btuh` | BTU (IT) per hour | 0.29307107017222 (= 1055.05585262 / 3600) |
| `btumin` | BTU (IT) per minute | 17.584264210333 (= 1055.05585262 / 60) |
| `ftlbmin` | foot-pound force per minute | 0.022596965805523 (= 1.3558179483314004 / 60) |
 
For `btumin`, `btuh` and `ftlbmin`, compute from the exact ratios (`1055.05585262/60`, `1055.05585262/3600`, `1.3558179483314004/60`) where possible rather than from the rounded decimals above. Milliwatt and megawatt are excluded because `mw` / `MW` collide under case-insensitive matching (gigawatt `gw` has no such clash).
 
**Pressure** — base: pascal (`pa`)
 
| Symbol | Unit | Factor (Pa) |
|---|---|---|
| `pa` | pascal | 1 |
| `hpa` | hectopascal | 100 |
| `kpa` | kilopascal | 1000 |
| `mpa` | megapascal | 1000000 |
| `mbar` | millibar | 100 |
| `bar` | bar | 100000 |
| `atm` | standard atmosphere | 101325 |
| `psi` | pound-force per square inch | 6894.757293168361 |
| `mmhg` | millimetre of mercury (conventional) | 133.322387415 |
| `inhg` | inch of mercury (conventional) | 3386.388640341 (= 25.4 × `mmhg`) |
| `torr` | torr | 133.322368421053 (= 101325 / 760) |
 
For `torr`, compute from the exact ratio `101325/760` where possible. `mmhg` uses the conventional value (13595.1 kg/m³ × 9.80665 m/s² × 0.001 m); it differs very slightly from `torr`, and both are kept deliberately.
 
**Angle** — base: degree (`deg`)
 
| Symbol | Unit | Factor (deg) |
|---|---|---|
| `deg` | degree | 1 |
| `rad` | radian | 180/π (≈ 57.295779513082) |
| `grad` | gradian (gon) | 0.9 |
| `turn` | full turn (revolution) | 360 |
| `arcmin` | arcminute | 1/60 |
| `arcsec` | arcsecond | 1/3600 |
 
For `rad`, compute `180/π` using the language's most precise π constant. For `arcmin` and `arcsec`, compute from the exact ratios (`1/60`, `1/3600`).
 
**Temperature** — formula-based (offsets, not factors); symbols `c`, `f`, `k`
 
| From → To | Formula |
|---|---|
| °C → °F | `F = C × 9/5 + 32` |
| °F → °C | `C = (F − 32) × 5/9` |
| °C → K | `K = C + 273.15` |
| K → °C | `C = K − 273.15` |
| °F ↔ K | via °C |
 
Any input or result below absolute zero (`-273.15 °C`, `-459.67 °F`, `0 K`) is rejected with `BELOW_ABSOLUTE_ZERO`.
 
### 5.4 Required behavior checklist
 
- [ ] All eleven factor-based categories (length, mass, area, volume, time, speed, digital information, energy, power, pressure, angle) plus temperature (twelve total)
- [ ] `convert` command and shorthand form
- [ ] `list` command
- [ ] The `all` target (`convert <value> <from> all`)
- [ ] Case-insensitive unit symbols
- [ ] `UNKNOWN_UNIT`, `INCOMPATIBLE_UNITS`, `INVALID_NUMBER`, `BELOW_ABSOLUTE_ZERO`
- [ ] 12-significant-digit output formatting
- [ ] Guided flow (category → from → to → values); the values prompt shows the units, e.g. `converter (m → yd)>`; `list` and the other one-line forms also work there
---
 
## 6. Language-Specific Documentation
 
Each language folder must contain a `README.md` that covers:
 
1. Prerequisites (compiler/interpreter/runtime and minimum version)
2. Build command (if any)
3. Run command
4. Test command
5. How 64-bit signed integers are provided or emulated
6. How decimal arithmetic and the 12-digit formatting are achieved
7. Known deviations from this specification, each with a reason
8. Any non-standard delivery model (host environment, reduced feature set)
**Suggested layout** (adapt to each language's conventions):
 
```text
<language>/
├── README.md
├── src/
│   ├── cli/            # menu and prompts
│   ├── calculator/     # standard calculator logic
│   ├── programmer/     # programmer calculator logic
│   ├── converter/      # unit conversion logic
│   └── shared/         # formatting, error codes
└── test/
```
 
Calculation logic must be separate from CLI input/output so it can be tested directly and reused by later GUI editions.
 
---
 
## 7. Testing Requirements
 
- Every language implements the test cases below, or an equivalent data-driven version of them.
- Tests assert **results and error codes**, not prompt text or terminal formatting.
- A shared, language-neutral data file (for example `docs/release-1-cases.json` with `tool`, `input`, `expected`, `error` fields) is recommended so every language can load the same cases.
- A language cannot be marked complete if any shared test fails, even if it compiles and runs.
---
 
## 8. Shared Test Cases
 
### 8.1 Standard Calculator
 
| # | Input | Expected |
|---|---|---|
| S1 | `25 + 17` | `42` |
| S2 | `10 / 4` | `2.5` |
| S3 | `10 / 0` | `DIV_BY_ZERO` |
| S4 | `0.1 + 0.2` | `0.3` |
| S5 | `-5 + 3` | `-2` |
| S6 | `2 * -3` | `-6` |
| S7 | `2 + 3 * 4` | `14` |
| S8 | `(2 + 3) * 4` | `20` |
| S9 | `2^3^2` | `512` |
| S10 | `-2^2` | `-4` |
| S11 | `2^-1` | `0.5` |
| S12 | `sqrt(16)` | `4` |
| S13 | `sqrt(2)` | `1.41421356237` |
| S14 | `sqrt(-1)` | `DOMAIN_ERROR` |
| S15 | `abs(-7.5)` | `7.5` |
| S16 | `20% of 150` | `30` |
| S17 | `200 + 10%` | `220` |
| S18 | `200 - 10%` | `180` |
| S19 | `200 * 10%` | `20` |
| S20 | `50%` | `0.5` |
| S21 | `0^0` | `UNDEFINED` |
| S22 | `0^-1` | `DIV_BY_ZERO` |
| S23 | `10^400` | `OVERFLOW` |
| S24 | `(2 + 3` | `INVALID_EXPRESSION` |
| S25 | `2 +` | `INVALID_EXPRESSION` |
| S26 | `2(3)` | `INVALID_EXPRESSION` |
| S27 | `abc` | `INVALID_EXPRESSION` |
| S28 | `1 / 3` | `0.333333333333` |
| S29 | `2 / 3` | `0.666666666667` |
| S30 | `1000000 * 1000000000` | `1e+15` |
| S31 | `1 / 10000000` | `1e-7` |
| S32 | `5 + 5` then `ans * 2` | `10`, then `20` |
| S33 | `10 / 0` then `ans` (after a prior result of `7`) | error, then `7` (`ans` unchanged) |
 
### 8.2 Programmer Calculator
 
| # | Input | Expected |
|---|---|---|
| P1 | `convert 255 dec hex` | `FF` |
| P2 | `convert FF hex dec` | `255` |
| P3 | `convert 11111111 bin dec` | `255` |
| P4 | `convert 255 dec bin` | `11111111` |
| P5 | `convert 255 dec oct` | `377` |
| P6 | `5 AND 3` | DEC `1` |
| P7 | `5 OR 3` | DEC `7` |
| P8 | `5 XOR 3` | DEC `6` |
| P9 | `NOT 5` | DEC `-6`, HEX `FFFFFFFFFFFFFFFA` |
| P10 | `NOT 0` | DEC `-1` |
| P11 | `1 << 3` | DEC `8` |
| P12 | `1 << 63` | DEC `-9223372036854775808` |
| P13 | `-8 >> 1` | DEC `-4` |
| P14 | `-8 >>> 1` | DEC `9223372036854775804`, HEX `7FFFFFFFFFFFFFFC` |
| P15 | `1 << 64` | `INVALID_SHIFT` |
| P16 | `1 << -1` | `INVALID_SHIFT` |
| P17 | `-1` | HEX `FFFFFFFFFFFFFFFF`, BIN is 64 ones |
| P18 | `0xFFFFFFFFFFFFFFFF` | DEC `-1` |
| P19 | `-FF` with `base hex` | DEC `-255` |
| P20 | `9223372036854775807` | HEX `7FFFFFFFFFFFFFFF` |
| P21 | `9223372036854775808` | `OUT_OF_RANGE` |
| P22 | `0x10000000000000000` | `OUT_OF_RANGE` |
| P23 | `convert 102 bin dec` | `INVALID_DIGIT` |
| P24 | `convert 8 oct dec` | `INVALID_DIGIT` |
| P25 | `convert G hex dec` | `INVALID_DIGIT` |
| P26 | `base xyz` | `INVALID_BASE` |
| P27 | `0` | HEX `0`, DEC `0`, OCT `0`, BIN `0` |
| P28 | `0xff AND 0x0f` | DEC `15` |
| P29 | `255 dec hex` | `FF` |
| P30 | `FF hex dec` | `255` |
| P31 | `FACE XOR BEEF` with `base hex` | HEX `4421` |
| P32 | `0B1` with `base hex` | DEC `1` |
 
### 8.3 Unit Converter
 
| # | Input | Expected |
|---|---|---|
| C1 | `convert 1 in cm` | `2.54` |
| C2 | `convert 1 mi km` | `1.609344` |
| C3 | `convert 1 km mi` | `0.621371192237` |
| C4 | `convert 1 lb kg` | `0.45359237` |
| C5 | `convert 1 kg lb` | `2.20462262185` |
| C6 | `convert 1 gal l` | `3.785411784` |
| C7 | `convert 1 ha m2` | `10000` |
| C8 | `convert 1 ac m2` | `4046.8564224` |
| C9 | `convert 1 h min` | `60` |
| C10 | `convert 1 d h` | `24` |
| C11 | `convert 60 mph kmh` | `96.56064` |
| C12 | `convert 100 kmh mps` | `27.7777777778` |
| C13 | `convert 1 kn kmh` | `1.852` |
| C14 | `convert 1 byte bit` | `8` |
| C15 | `convert 1 kb byte` | `1000` |
| C16 | `convert 1 gb mb` | `1000` |
| C17 | `convert 0 c f` | `32` |
| C18 | `convert 100 c f` | `212` |
| C19 | `convert -40 c f` | `-40` |
| C20 | `convert 32 f c` | `0` |
| C21 | `convert 273.15 k c` | `0` |
| C22 | `convert 0 k c` | `-273.15` |
| C23 | `convert -1 k c` | `BELOW_ABSOLUTE_ZERO` |
| C24 | `convert -300 c f` | `BELOW_ABSOLUTE_ZERO` |
| C25 | `convert 5 m kg` | `INCOMPATIBLE_UNITS` |
| C26 | `convert 5 xyz m` | `UNKNOWN_UNIT` |
| C27 | `convert abc m cm` | `INVALID_NUMBER` |
| C28 | `convert 5 CM M` (uppercase) | `0.05` |
| C29 | `convert 0 m ft` | `0` |
| C30 | `convert -5 m cm` | `-500` |
| C31 | `convert 1 kj j` | `1000` |
| C32 | `convert 1 kcal kj` | `4.184` |
| C33 | `convert 1 cal j` | `4.184` |
| C34 | `convert 1 kcal cal` | `1000` |
| C35 | `convert 1 kwh wh` | `1000` |
| C36 | `convert 1 kwh j` | `3600000` |
| C37 | `convert 1 btu j` | `1055.05585262` |
| C38 | `convert 1 ftlb j` | `1.35581794833` |
| C39 | `convert 1 ev j` | `1.602176634e-19` |
| C40 | `convert 1 kw w` | `1000` |
| C41 | `convert 1 hp w` | `745.699871582` |
| C42 | `convert 1 hp kw` | `0.745699871582` |
| C43 | `convert 1 kw hp` | `1.3410220896` |
| C44 | `convert 1 btumin w` | `17.5842642103` |
| C45 | `convert 60 ftlbmin w` | `1.35581794833` |
| C46 | `convert 1 atm pa` | `101325` |
| C47 | `convert 1 bar kpa` | `100` |
| C48 | `convert 1 atm bar` | `1.01325` |
| C49 | `convert 1 hpa mbar` | `1` |
| C50 | `convert 1 psi pa` | `6894.75729317` |
| C51 | `convert 1 atm psi` | `14.6959487755` |
| C52 | `convert 1 bar psi` | `14.503773773` |
| C53 | `convert 760 torr atm` | `1` |
| C54 | `convert 1 torr pa` | `133.322368421` |
| C55 | `convert 1 mmhg pa` | `133.322387415` |
| C56 | `convert 180 deg rad` | `3.14159265359` |
| C57 | `convert 1 rad deg` | `57.2957795131` |
| C58 | `convert 90 deg grad` | `100` |
| C59 | `convert 200 grad deg` | `180` |
| C60 | `convert 1 turn deg` | `360` |
| C61 | `convert 1 turn rad` | `6.28318530718` |
| C62 | `convert 1 deg arcmin` | `60` |
| C63 | `convert 1 arcmin arcsec` | `60` |
| C64 | `convert -90 deg rad` | `-1.57079632679` |
| C65 | `convert 0 deg rad` | `0` |
| C66 | `convert 1 j w` | `INCOMPATIBLE_UNITS` |
| C67 | `convert 1 psi deg` | `INCOMPATIBLE_UNITS` |
| C68 | `convert 5 pascal pa` | `UNKNOWN_UNIT` |
| C69 | `convert 1 KWH J` (uppercase) | `3600000` |
| C70 | `convert 1 nm m` | `1e-9` |
| C71 | `convert 1 um nm` | `1000` |
| C72 | `convert 1 nmi m` | `1852` |
| C73 | `convert 1 nmi km` | `1.852` |
| C74 | `convert 1 au km` | `149597870.7` |
| C75 | `convert 1 ly km` | `9460730472580` |
| C76 | `convert 1 ang nm` | `0.1` |
| C77 | `convert 1 pm ang` | `0.01` |
| C78 | `convert 1 ct mg` | `200` |
| C79 | `convert 1 st lb` | `14` |
| C80 | `convert 1 ton lb` | `2000` |
| C81 | `convert 1 lton lb` | `2240` |
| C82 | `convert 1 gr mg` | `64.79891` |
| C83 | `convert 1 mg ug` | `1000` |
| C84 | `convert 1 cm3 ml` | `1` |
| C85 | `convert 1 ft3 l` | `28.316846592` |
| C86 | `convert 1 in3 ml` | `16.387064` |
| C87 | `convert 1 yd3 ft3` | `27` |
| C88 | `convert 1 impgal l` | `4.54609` |
| C89 | `convert 1 impgal gal` | `1.2009499255` |
| C90 | `convert 1 impqt impfloz` | `40` |
| C91 | `convert 1 ms us` | `1000` |
| C92 | `convert 1 us ns` | `1000` |
| C93 | `convert 1 nibble bit` | `4` |
| C94 | `convert 1 byte nibble` | `2` |
| C95 | `convert 1 mbit kbit` | `1000` |
| C96 | `convert 8 mbit mb` | `1` |
| C97 | `convert 1 eb pb` | `1000` |
| C98 | `convert 1 gw kw` | `1000000` |
| C99 | `convert 1 ps w` | `735.49875` |
| C100 | `convert 1 btuh w` | `0.293071070172` |
| C101 | `convert 1 mpa kpa` | `1000` |
| C102 | `convert 1 inhg pa` | `3386.38864034` |
| C103 | `convert 1 inhg mmhg` | `25.4` |
| C104 | `convert 1 erg j` | `1e-7` |
| C105 | `convert 1 km all` | lines include `m: 1000` and `mi: 0.621371192237` |
| C106 | `convert 0 c all` | `c: 0`, `f: 32`, `k: 273.15` |
| C107 | `convert 1 xyz all` | `UNKNOWN_UNIT` |
| C108 | `convert -1 k all` | `BELOW_ABSOLUTE_ZERO` |
| C109 | `convert 1 m s` | `INCOMPATIBLE_UNITS` |
| C110 | `convert 1 ly pm` | `9.46073047258e+27` |
 
---
 
## 9. Language Track and Progress
 
Release 1 is implemented in **all 43 selected languages**. Per the roadmap's language policy, languages with an unusual runtime still follow this specification as closely as possible; every deviation must be recorded in that language's README and in the Notes column below — never hidden.
 
**Legend:** ☐ not started · ◐ in progress · ☑ complete and verified against Section 8

**Terminal exemption.** A language that cannot run an interactive terminal program (for example ABAP, Apex, Solidity, VBA) is exempt from the arrow-key selector. Record the exemption in that language's README and in the Notes column; the numbered list is then the only interface.
 
| # | Language | Std | Prog | Conv | Docs | Notes |
|---|---|:-:|:-:|:-:|:-:|---|
| 1 | ABAP | ☐ | ☐ | ☐ | ☐ | Needs an ABAP runtime (SAP system or compatible environment). Likely a report program rather than a standalone executable; document the host. |
| 2 | Ada | ☐ | ☐ | ☐ | ☐ | Compile with GNAT. `Long_Long_Integer` / `Interfaces.Integer_64` for programmer mode. |
| 3 | Apex | ☐ | ☐ | ☐ | ☐ | Requires Salesforce tooling. Run through anonymous Apex or test classes; `Long` is 64-bit. Specialized workflow. |
| 4 | Assembly (ASM) | ☐ | ☐ | ☐ | ☐ | Choose and document one target (for example x86-64 Linux, NASM). Native 64-bit integers; floating-point and parsing are manual work. |
| 5 | Bash | ☑ | ☑ | ☑ | ☑ | Bash 4.0+. Programmer mode is pure Bash: `$(( ))` is native signed 64-bit and wraps; literals are parsed digit by digit. Decimals use awk (documented dependency). |
| 6 | C | ☑ | ☑ | ☑ | ☑ | `int64_t` / `uint64_t`; hand-written expression parser. |
| 7 | C++ | ☑ | ☑ | ☑ | ☑ | Use `<cstdint>` types. |
| 8 | C# | ☐ | ☐ | ☐ | ☐ | `long` / `ulong`; `decimal` or `double` for calculations. |
| 9 | Clojure | ☐ | ☐ | ☐ | ☐ | JVM-based; use `long` with unchecked ops for wrap-around. |
| 10 | COBOL | ☐ | ☐ | ☐ | ☐ | Use GnuCOBOL; document the compiler. Bitwise operations need intrinsic or custom routines. |
| 11 | Dart | ☐ | ☐ | ☐ | ☐ | Native `int` is 64-bit on the VM but not on web; target the VM. |
| 12 | Elixir | ☐ | ☐ | ☐ | ☐ | Integers are arbitrary precision; mask to 64 bits manually. Use `Bitwise`. |
| 13 | Erlang | ☐ | ☐ | ☐ | ☐ | Arbitrary-precision integers; mask to 64 bits manually. Use `escript` for the CLI. |
| 14 | F# | ☐ | ☐ | ☐ | ☐ | `int64`; .NET runtime. |
| 15 | Fortran | ☐ | ☐ | ☐ | ☐ | Use `integer(int64)`; document the compiler (for example gfortran). |
| 16 | Go | ☐ | ☐ | ☐ | ☐ | `int64` / `uint64`. |
| 17 | Groovy | ☐ | ☐ | ☐ | ☐ | JVM-based; watch dynamic number promotion to `BigInteger` / `BigDecimal`. |
| 18 | Haskell | ☐ | ☐ | ☐ | ☐ | Use `Int64` from `Data.Int` and `Data.Bits`. |
| 19 | Java | ☑ | ☑ | ☑ | ☑ | `long`; `>>` and `>>>` map directly. |
| 20 | JavaScript | ☑ | ☑ | ☑ | ☑ | **Reference implementation (Node.js).** Use `BigInt` with `BigInt.asIntN(64, …)` for programmer mode. |
| 21 | Julia | ☐ | ☐ | ☐ | ☐ | `Int64` wraps natively; `>>` is arithmetic, `>>>` is logical. |
| 22 | Kotlin | ☐ | ☐ | ☐ | ☐ | `Long`; `shr` / `ushr` / `shl`. |
| 23 | Lisp | ☐ | ☐ | ☐ | ☐ | Specify the dialect (Common Lisp with SBCL assumed). Integers are arbitrary precision; use `ldb` / masking for 64-bit. |
| 24 | Lua | ☐ | ☐ | ☐ | ☐ | Requires Lua 5.3+ for native 64-bit integers and bitwise operators. |
| 25 | MATLAB | ☐ | ☐ | ☐ | ☐ | Needs MATLAB (or document use of GNU Octave). Use `int64` and `bitand` / `bitor` / `bitxor` / `bitshift`; watch saturation instead of wrap-around. |
| 26 | Nim | ☐ | ☐ | ☐ | ☐ | `int64`; `shl` / `shr` / `ashr`. |
| 27 | Objective-C | ☐ | ☐ | ☐ | ☐ | Build with clang (macOS) or GNUstep; use `int64_t`. |
| 28 | OCaml | ☐ | ☐ | ☐ | ☐ | Native `int` is **63-bit**; use `Int64` for programmer mode. |
| 29 | Perl | ☐ | ☐ | ☐ | ☐ | Needs a 64-bit Perl build; use `use integer` carefully for signed behavior. |
| 30 | PHP | ☑ | ☑ | ☑ | ☑ | Requires a 64-bit build. Literals are parsed from strings and results never pass through `float`, so there is no silent integer-to-float overflow. |
| 31 | PowerShell | ☐ | ☐ | ☐ | ☐ | `[long]` / `[ulong]`; cross-platform PowerShell 7 preferred. |
| 32 | Prolog | ☐ | ☐ | ☐ | ☐ | SWI-Prolog assumed; integers are unbounded, so mask to 64 bits. |
| 33 | Python | ☑ | ☑ | ☑ | ☑ | Integers are unbounded; mask and sign-convert to 64 bits manually. Consider `decimal` for conversions. |
| 34 | R | ☐ | ☐ | ☐ | ☐ | No native 64-bit integer; use `bit64` or emulate with two 32-bit halves. Document the choice. |
| 35 | Ruby | ☐ | ☐ | ☐ | ☐ | Integers are unbounded; mask and sign-convert to 64 bits manually. |
| 36 | Rust | ☐ | ☐ | ☐ | ☐ | `i64` with `wrapping_shl`-style care; `u64` for logical shifts. |
| 37 | Scala | ☐ | ☐ | ☐ | ☐ | JVM-based; `Long`, `>>`, `>>>`, `<<`. |
| 38 | Solidity | ☐ | ☐ | ☐ | ☐ | Contract logic tested through Foundry or Hardhat, not a standalone CLI. No floating point: the Standard Calculator and Converter need fixed-point arithmetic. Document the precision limits; a reduced edition is acceptable if clearly labeled. |
| 39 | Swift | ☐ | ☐ | ☐ | ☐ | `Int64`; `&<<` / `&>>` for masking shifts. |
| 40 | TypeScript | ☐ | ☐ | ☐ | ☐ | Same approach as JavaScript (`BigInt`); strict typing. |
| 41 | VBA | ☐ | ☐ | ☐ | ☐ | Runs inside an Office host. `LongLong` is 64-bit only in 64-bit Office; no native shift operators. Document the host workflow. |
| 42 | VB.NET | ☐ | ☐ | ☐ | ☐ | `Long`; .NET runtime. |
| 43 | Zig | ☐ | ☐ | ☐ | ☐ | `i64` / `u64`; use `<<`, `>>` with explicit casts. |
 
---
 
## 10. Release 1 Completion Criteria
 
Release 1 is complete only when **all** of the following are true:
 
- [ ] All 43 languages show ☑ in the Std, Prog, Conv, and Docs columns, **or** each exception is explicitly documented and accepted.
- [ ] Every shared test case in Section 8 passes in every completed language.
- [ ] Each language edition has a README satisfying Section 6.
- [ ] Invalid input in every tool yields a documented error code and never a crash.
- [ ] Deviations caused by language semantics or runtime limits are recorded in the language README and in Section 9.
- [ ] The JavaScript reference implementation has been reviewed against this document, and any ambiguity found has been resolved by amending this specification (not by diverging per language).
Only then begins **Release 2 — Advanced Calculations**.
 
---
 
## 11. Design Decisions Made in This Specification
 
The roadmap deliberately left several points open for the "agreed initial specification". This document fixes them as follows, so they can be reviewed and changed in one place:
 
| Topic | Decision |
|---|---|
| Scientific operations in Release 1 | Only `sqrt`, `abs`, and `^` |
| Expression evaluation | Required, with full precedence and parentheses |
| Percent semantics | Relative to the left operand after `+` / `-`; plain division by 100 elsewhere |
| Numeric display | 12 significant digits, trailing zeros trimmed |
| `0^0` | `UNDEFINED` |
| Programmer integer model | Fixed 64-bit signed two's complement; width selection and unsigned views deferred to Release 3 |
| Right shifts | `>>` arithmetic, `>>>` logical |
| Left-shift overflow | Bits discarded, no error |
| Digital units | Decimal (SI) only in Release 1 |
| Energy units | `ev`, `j`, `kj`, `cal` (thermochemical, 4.184 J), `kcal` (food Calorie), `wh`, `kwh`, `btu` (IT), `ftlb` |
| Power units | `w`, `kw`, `hp` (mechanical), `btumin`, `ftlbmin`; milliwatt and megawatt excluded (case-insensitive clash) |
| Pressure units | `pa`, `hpa`, `kpa`, `mbar`, `bar`, `atm`, `psi`, `mmhg` (conventional), `torr` (101325/760) |
| Angle units | `deg`, `rad`, `grad`, `turn`, `arcmin`, `arcsec`; base unit is the degree so degree-based conversions stay exact |
| Extra units | Beyond the Windows-calculator set: `pm ang nm um nmi au ly` (length), `ug ct gr st ton lton` (mass), `cm3 in3 ft3 yd3` and `imp*` (volume), `ns us` (time), `nibble kbit mbit gbit tbit eb` (digital), `erg` (energy), `gw ps btuh` (power), `mpa inhg` (pressure) |
| `ton` / `lton` | `ton` is the US short ton, `lton` the UK long ton; the unprefixed `t` stays the metric tonne |
| Converter `all` target | `convert <value> <from> all` lists the value in every unit of the category |
| Unit symbols | Unique across all categories; categories total twelve including temperature |
| Time units | No months or years |
| Volume units | US customary |
| Error checking | By error code, not message text |
| Interactive converter | Guided flow: category → from → to → values. The values prompt shows the units; one-line forms are still accepted |
| Navigation | `back` goes back one screen (main menu from a tool's first screen); Esc and `b` are the key equivalents at a selector; `help` or `?` |
| Programmer `convert` | The word is optional (`255 dec hex`) |
| Selectors | Arrow-key selector is required on a real terminal; numbered lists for pipes, files, tests and `ARITHMOS_PLAIN=1` |