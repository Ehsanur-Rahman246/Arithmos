# Arithmos — Python edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter, following
`docs/specifications/release-1.md`.

## Prerequisites
Python 3.9 or newer (tested on 3.12). No third-party packages.

## Run
From this folder:

    python -m arithmos                       interactive menu
    python -m arithmos std "2 + 3 * 4"       one calculation
    python -m arithmos prog "5 AND 3"        one programmer command
    python -m arithmos convert 100 cm in     one conversion

## Test
From this folder:

    python -m unittest discover -s tests -t .

The shared cases are read from `../docs/release-1-cases.json`.

## How the spec's hard parts are done
- **64-bit integers:** Python ints are unbounded, so `to_int64` / `to_uint64`
  mask with 2**64-1 and sign-convert (`arithmos/programmer/int64.py`).
- **Decimal display:** calculations use IEEE doubles. Display converts the exact
  double to `decimal.Decimal` and rounds to 12 significant digits with
  `ROUND_HALF_UP` (Python's own float formatting rounds exact ties to even,
  which the spec does not allow).

## Interface
On a real terminal the menus are an arrow-key selector with a highlighted row
(Linux/macOS: `termios`, Windows: `msvcrt`). Pipes, files and tests get the same
screens as numbered lists. Set `NO_COLOR=1` to switch colours off.

## Known deviations from the spec
- The converter is a guided flow (category, from, to, values) instead of a bare
  `converter>` prompt. One-line commands such as `convert 100 cm in` still work.
- `back` goes back one screen; from a tool's first screen it returns to the main menu.
- In the programmer calculator the word `convert` is optional (`255 dec hex`).