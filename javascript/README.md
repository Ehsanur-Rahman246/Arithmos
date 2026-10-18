# Arithmos — JavaScript edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter, following
`docs/specifications/release-1.md`. This is the **reference edition**: the other
language editions are checked against it.

## Prerequisites
Node.js 20 or newer (tested on 22). No third-party packages, so `npm install` is
not needed.

## Run
From this folder:

    npm start                                interactive menu (or: node bin/arithmos.js)
    node bin/arithmos.js std "2 + 3 * 4"     one calculation
    node bin/arithmos.js prog "5 AND 3"      one programmer command
    node bin/arithmos.js convert 100 cm in   one conversion

## Test
From this folder:

    npm test                 everything
    npm run test:std         Standard Calculator cases (S1-S33)
    npm run test:prog        Programmer Calculator cases (P1-P28)
    npm run test:conv        Unit Converter cases (C1-C109)

The shared cases are read from `../docs/release-1-cases.json`.

## How the spec's hard parts are done
- **64-bit integers:** every value is a `BigInt` normalized with
  `BigInt.asIntN(64, …)`. Logical right shift (`>>>`) and the HEX/OCT/BIN display of
  negative values use `BigInt.asUintN(64, …)` to expose the raw 64-bit pattern
  (`src/programmer/int64.js`).
- **Decimal display:** calculations use IEEE doubles. Display (`src/shared/format-number.js`)
  rounds to 12 significant digits with `toExponential(11)`, which rounds exact ties
  up on the magnitude, i.e. half away from zero as the spec requires.

## Interface
On a real terminal the menus are an arrow-key selector with a highlighted row, built
on Node's own `readline` key events (no extra code per operating system). Pipes,
files and tests get the same screens as numbered lists. Set `NO_COLOR=1` to switch
colours off.

## Known deviations from the spec
- The converter is a guided flow (category, from, to, values) instead of a bare
  `converter>` prompt. One-line commands such as `convert 100 cm in` still work.
- `back` goes back one screen; from a tool's first screen it returns to the main menu.
- In the programmer calculator the word `convert` is optional (`255 dec hex`).

## More documentation
`docs/` holds the architecture notes, feature checklist, usage guide, error codes,
testing notes, deviations log and spec-review log.