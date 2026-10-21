# Arithmos — JavaScript edition (Release 1)

The reference edition. Standard Calculator, Programmer Calculator and Unit Converter,
following [the Release 1 spec](../docs/specifications/release-1.md). Other editions
are checked against this one. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases.

## Prerequisites

Node.js 20 or newer (developed and tested on 22). No third-party packages, so
`npm install` is not needed.

## Run

From this folder:

```bash
npm start                                  # interactive menu (or: node bin/arithmos.js)
node bin/arithmos.js std "2 + 3 * 4"       # one calculation        → 14
node bin/arithmos.js prog "5 AND 3"        # one programmer command
node bin/arithmos.js convert 100 cm in     # one conversion         → 39.3700787402
```

In any tool: `help (or ?)` shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly.

One-shot exit status: `0` success, `1` the line produced an `Error [CODE]`, `2` bad
usage.

## Examples

```text
standard> 200 + 10%            programmer> 0xFF                 converter (cm → in)> convert 100 cm in
220                            HEX: FF                          39.3700787402
standard> 20% of 150           DEC: 255                         converter (cm → in)> 0 c f
30                             OCT: 377                         32
standard> ans * 2              BIN: 11111111                    converter (cm → in)> convert 1 km all
60                             programmer> convert 255 dec hex  converter (cm → in)> list pressure
standard> 10 / 0               FF                               pa, hpa, kpa, mpa, …
Error [DIV_BY_ZERO]: …         programmer> -8 >>> 1
                               DEC: 9223372036854775804
```

Standard Calculator: `+ - * / ^`, unary signs, parentheses, `%`, `of`, `sqrt()`,
`abs()`, `ans`. Not supported in Release 1: `1e5` input and implicit multiplication.

Programmer Calculator: prefixes `0b 0o 0d 0x`; `base <bin|oct|dec|hex>`;
`[convert] <value> <from> <to>`; `AND OR XOR NOT`; `<<` `>>` (arithmetic) `>>>`
(logical); shift count is decimal 0–63; 64-bit signed throughout.

Unit Converter: twelve categories; `list`, `list <category>`, `convert … all`; symbols
are case-insensitive. Unit tables are in spec §5.3.

Error codes are listed in spec §2.2.

## Test

```bash
npm test               # everything
npm run test:std       # Standard Calculator cases (S1–S33)
npm run test:prog      # Programmer Calculator cases (P1–P32)
npm run test:conv      # Unit Converter cases (C1–C110)
```
— shared cases 175, selector tests 22 (SL1–SL21 + X1), plus the existing others.

Uses Node's built-in runner. Shared cases are read from `../docs/release-1-cases.json`
([format](../docs/test-cases.md)). Extra tests cover number formatting, the selector
and scripted CLI sessions.

## Layout

```text
bin/arithmos.js        entry point
src/cli/               menus, prompt loop, selector, tool bindings (only I/O layer)
src/calculator/        tokenizer, parser, evaluator
src/programmer/        int64, parse, operations, format
src/converter/         units, convert, temperature, session
src/shared/            errors, format-number
test/                  shared-case runners + extra tests
```

## How the spec's hard parts are done

- **64-bit integers:** every value is a `BigInt` normalized with `BigInt.asIntN(64, …)`.
  `>>>` and the HEX/OCT/BIN display of negative values use `BigInt.asUintN(64, …)`
  (`src/programmer/int64.js`).
- **12-digit display:** calculations use IEEE doubles. `src/shared/format-number.js`
  rounds with `toExponential(11)`, which rounds exact ties up on the magnitude, i.e.
  half away from zero as the spec requires.

## Interface

On a real terminal the menus are an arrow-key selector built on Node's own `readline`
key events, read by one persistent key reader. Set `ARITHMOS_PLAIN=1` to use numbered lists instead (useful if a terminal misbehaves). In interactive mode the line editor supports typing, Backspace and Enter; Esc goes back in the converter. Not supported: cursor movement and history. Pipes, files and tests get the same screens as numbered lists. Set
`NO_COLOR=1` to switch colour off.

## Deviations from the spec
None.

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Workflow](../docs/development-workflow.md)