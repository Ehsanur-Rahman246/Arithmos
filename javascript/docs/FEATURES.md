# Features — JavaScript Edition, Release 1

Mirrors the required-behavior checklists in the specification (Sections 3.6, 4.6, 5.4). Tick a box only when the feature passes its shared test cases.

## Application shell (spec 2.1, 2.4)

- [ ] Main menu with options 1/2/3/0
- [ ] `help`, `back`, `quit` in every tool, case-insensitive
- [ ] Clean exit on EOF
- [ ] `UNKNOWN_COMMAND` for unrecognized commands
- [ ] Blank input ignored; leading/trailing whitespace ignored
- [ ] One-shot command-line mode (`convert`, `std`, `prog`)
- [ ] `Error [CODE]: message` output format

## Standard Calculator (spec 3)

- [ ] Addition, subtraction, multiplication, division
- [ ] Decimal and negative numbers
- [ ] Percentages (`50%`) and `of` (`20% of 150`)
- [ ] Percent relative to left operand after `+` / `-`
- [ ] Parentheses and correct precedence
- [ ] `^` (right-associative), `sqrt`, `abs`
- [ ] `ans` (unchanged after an error)
- [ ] Division-by-zero, domain, `UNDEFINED`, and `OVERFLOW` errors
- [ ] Repeated calculation loop without restarting
- [ ] `INVALID_EXPRESSION` for every malformed-input category
- [ ] 12-significant-digit output with plain/scientific thresholds

## Programmer Calculator (spec 4)

- [ ] Binary, octal, decimal, hexadecimal input and output
- [ ] Literal prefixes `0b`, `0o`, `0d`, `0x`
- [ ] `base <bin|oct|dec|hex>` input base
- [ ] `convert <value> <from> <to>` base-to-base conversion
- [ ] `AND`, `OR`, `XOR`, `NOT`
- [ ] `<<`, `>>` (arithmetic), `>>>` (logical)
- [ ] Per-base digit validation (`INVALID_DIGIT`)
- [ ] Negative numbers as 64-bit two's complement
- [ ] Range validation (`OUT_OF_RANGE`) and shift-count validation (`INVALID_SHIFT`)
- [ ] Every result shown in HEX, DEC, OCT, BIN

## Unit Converter (spec 5)

Categories (twelve):

- [ ] Length
- [ ] Mass
- [ ] Area
- [ ] Volume (US customary, UK imperial `imp*`, cubic units)
- [ ] Time (no months/years)
- [ ] Speed
- [ ] Digital information (decimal SI only)
- [ ] Energy
- [ ] Power
- [ ] Pressure
- [ ] Angle
- [ ] Temperature (formula-based, absolute-zero checks)

Behavior:

- [ ] `convert <value> <from> <to>` and the shorthand `<value> <from> <to>`
- [ ] `convert <value> <from> all`
- [ ] `list` and `list <category>`
- [ ] Case-insensitive unit symbols
- [ ] Unique symbols across all categories (checked at load time)
- [ ] `UNKNOWN_UNIT`, `INCOMPATIBLE_UNITS`, `INVALID_NUMBER`, `BELOW_ABSOLUTE_ZERO`

## Out of scope for Release 1

Scientific functions beyond `sqrt`/`abs`/`^`, graphing, statistics, date calculation, currency, memory/history, binary storage units (KiB, MiB…), selectable integer width, games, GUI.

## Quality gates

- [ ] All shared cases pass (S1–S33, P1–P28, C1–C109)
- [ ] Invalid input never crashes the program
- [ ] Calculation logic has no I/O
- [ ] README satisfies spec Section 6
- [ ] Reviewed against the spec; ambiguities recorded in `SPEC-REVIEW.md`
