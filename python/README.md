# Arithmos — Python edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter, following
[the Release 1 spec](../docs/specifications/release-1.md). Checked against the
JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases.

## Prerequisites

Python 3.9 or newer (tested on 3.12). No third-party packages.

## Run

From this folder:

```bash
python -m arithmos                       # interactive menu
python -m arithmos std "2 + 3 * 4"       # one calculation        → 14
python -m arithmos prog "5 AND 3"        # one programmer command
python -m arithmos convert 100 cm in     # one conversion         → 39.3700787402
```

In any tool: `help (or ?)` shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly.

One-shot exit status: `0` success, `1` the line produced an `Error [CODE]`, `2` bad
usage.

## Usage

The command set is identical to the JavaScript edition; see its
[examples](../javascript/README.md#examples). Error codes are in spec §2.2.

## Test

```bash
python -m unittest discover -s tests -t .
```

Shared cases are read from `../docs/release-1-cases.json`
([format](../docs/test-cases.md)). Extra tests cover number formatting, the selector
and scripted CLI sessions.

## Layout

```text
arithmos/__main__.py    entry point
arithmos/cli/           menus, prompt loop, selector, tool bindings (only I/O layer)
arithmos/calculator/    tokenizer, parser, evaluator
arithmos/programmer/    int64, parse, operations, format
arithmos/converter/     units, convert, temperature, session
arithmos/shared/        errors, format_number
tests/                  shared-case runners + extra tests
```

## How the spec's hard parts are done

- **64-bit integers:** Python ints are unbounded, so `to_int64` / `to_uint64` mask
  with `2**64 − 1` and sign-convert (`arithmos/programmer/int64.py`).
- **12-digit display:** calculations use IEEE doubles. Display converts the exact
  double to `decimal.Decimal` and rounds to 12 significant digits with
  `ROUND_HALF_UP`. Python's own float formatting rounds exact ties to even, which the
  spec does not allow.

## Interface

On a real terminal the menus are an arrow-key selector with a highlighted row
(Linux/macOS: `termios`; Windows: `msvcrt`). Pipes, files and tests get the same
screens as numbered lists. Set `NO_COLOR=1` to switch colour off. Esc goes back 
in the selectors; at the converter's values prompt, type back.

## Deviations from the spec
None.

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Workflow](../docs/development-workflow.md)