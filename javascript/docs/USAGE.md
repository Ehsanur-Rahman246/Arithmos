# Usage — JavaScript Edition

## Starting

```bash
npm start
```

```text
Arithmos 1.0 — Core CLI
  1) Standard Calculator
  2) Programmer Calculator
  3) Unit Converter
  0) Exit
```

In any tool: `help` shows commands, `back` returns to the menu, `quit` exits. All three are case-insensitive. End-of-input (Ctrl-D / Ctrl-Z) exits cleanly.

## One-shot mode

```bash
node bin/arithmos.js std "25 + 17"          # 42
node bin/arithmos.js prog "convert 255 dec hex"   # FF
node bin/arithmos.js convert 100 cm in       # 39.3700787402
```

One-shot runs a single line and exits with status `0`, or `1` when the line produced an error. (Exit codes are proposed, not part of the spec; see `SPEC-REVIEW.md` R21.)

## Standard Calculator

```text
standard> 25 + 17
42
standard> ans * 2
84
standard> 200 + 10%
220
standard> 20% of 150
30
standard> sqrt(2)
1.41421356237
standard> 10 / 0
Error [DIV_BY_ZERO]: Cannot divide by zero
```

| Element | Form |
|---|---|
| Operators | `+  -  *  /  ^` |
| Unary | `-5`, `+5`, `2 * -3` |
| Parentheses | `( )` |
| Percent | `50%`, `200 + 10%` (relative), `20% of 150` |
| Functions | `sqrt(x)`, `abs(x)` |
| Previous result | `ans` |

Not supported in Release 1: scientific-notation input (`1e5`), implicit multiplication (`2(3)`).

## Programmer Calculator

```text
programmer> 0xFF
HEX: FF
DEC: 255
OCT: 377
BIN: 11111111
programmer> convert 255 dec hex
FF
programmer> 5 AND 3
HEX: 1
DEC: 1
OCT: 1
BIN: 1
programmer> base hex
programmer> -FF
HEX: FFFFFFFFFFFFFF01
DEC: -255
OCT: 1777777777777777777401
BIN: 1111111111111111111111111111111111111111111111111111111100000001
```

| Command | Meaning |
|---|---|
| `<value>` | Show in all bases |
| `base <bin\|oct\|dec\|hex>` | Set input base |
| `convert <value> <from> <to>` | Print the number in the target base |
| `<a> AND\|OR\|XOR <b>` | Bitwise operation |
| `NOT <a>` | Bitwise complement |
| `<a> << <n>` / `>>` / `>>>` | Left / arithmetic right / logical right shift (`n` decimal, 0–63) |

Prefixes: `0b` binary, `0o` octal, `0d` decimal, `0x` hexadecimal. 64-bit signed two's complement throughout.

## Unit Converter

```text
converter> convert 100 cm in
39.3700787402
converter> 0 c f
32
converter> convert 1 km all
pm: 1e+15
ang: 1e+13
…
m: 1000
…
km: 1
…
converter> list
length, mass, area, volume, time, speed, digital, energy, power, pressure, angle, temperature
converter> list pressure
pa, hpa, kpa, mpa, mbar, bar, atm, psi, mmhg, inhg, torr
```

The word `convert` is optional. Unit symbols are case-insensitive. Run `list <category>` for the symbols in each category; the full tables are in spec Section 5.3.

## Exit codes (one-shot mode, proposed)

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | The line produced an `Error [CODE]` result |
| 2 | Bad command-line usage |
