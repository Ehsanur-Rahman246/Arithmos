# Arithmos — C++ edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in C++17, standard library
only. Follows [the Release 1 spec](../docs/specifications/release-1.md). Checked against the
JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.

## Prerequisites

- A C++17 compiler: g++ 8+, clang++ 7+ or MSVC 2019+ (tested with g++)
- Nothing else: no third-party packages. `make` is optional; every command below also works
  without it.

## Run

From this folder, build once (one line):

```bash
g++ -std=c++17 -O2 -Wall -Wextra -Isrc -o arithmos src/main.cpp src/shared/format_number.cpp src/calculator/calculator.cpp src/programmer/programmer.cpp src/converter/units.cpp src/converter/converter.cpp src/cli/cli.cpp src/cli/pick.cpp src/cli/selector.cpp src/cli/terminal.cpp
```

or `make`. Then:

```bash
./arithmos                          # interactive menu (arithmos.exe on Windows)
./arithmos std "20% of 150"         # one calculation          → 30
./arithmos prog 0xFF AND 0x0F       # one programmer command
./arithmos convert 100 cm in        # one conversion           → 39.3700787402
./arithmos list length
```

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly.

One-shot exit status: `0` success, `1` the line produced an `Error [CODE]`, `2` bad usage.
One-shot errors go to stderr; interactive errors go to stdout.

## Test

```bash
make test    # shared cases + extras, then the selector tests
make asan    # the same under AddressSanitizer + UBSan (Linux/macOS)
```

Without make:

```bash
g++ -std=c++17 -O2 -Isrc -o run_tests test/run_cases.cpp src/shared/format_number.cpp src/calculator/calculator.cpp src/programmer/programmer.cpp src/converter/units.cpp src/converter/converter.cpp src/cli/cli.cpp src/cli/pick.cpp src/cli/selector.cpp src/cli/terminal.cpp && ./run_tests ../docs/release-1-cases.json
g++ -std=c++17 -O2 -Isrc -o run_selector test/run_selector.cpp src/cli/selector.cpp src/cli/pick.cpp && ./run_selector
```

| Program | What it checks | Count |
|---|---|---|
| `run_tests` (`test/run_cases.cpp`) | The shared cases, loaded from `../docs/release-1-cases.json` with a small built-in JSON reader, then C++ extras (formatting boundaries, garbage input, settled amendments, scripted CLI sessions, one-shot exit codes) | 175 shared + extras |
| `run_selector` (`test/run_selector.cpp`) | Selector tests SL1–SL21: key handling, drawing, the draw/read loop and `pick()` over a fake keyboard and screen | 21 |

Pass another case file as the first argument: `./run_tests path/to/cases.json`. The selector
tests are the same 21 behaviours, with the same numbers, as the other editions
([docs/test-cases.md](../docs/test-cases.md)).

## Layout

```text
cpp/
├── Makefile
├── src/
│   ├── main.cpp
│   ├── cli/            cli.cpp (menus, prompt loops, one-shot mode: the only I/O)
│   │                   selector.cpp (arrow-key selector: key handling, drawing, draw/read loop)
│   │                   pick.cpp (pick(): one question, many answers)
│   │                   terminal.cpp (real terminal: detection, raw key reading)
│   ├── calculator/     tokenizer -> parser (AST) -> evaluator (all in calculator.cpp)
│   ├── programmer/     64-bit parsing, bases, bitwise ops, shifts
│   ├── converter/      converter.cpp (logic) + units.cpp (unit tables as data)
│   └── shared/         errors.hpp, text.hpp, format_number.cpp
└── test/
    ├── run_cases.cpp     shared cases + extra tests
    └── run_selector.cpp  selector tests SL1–SL21
```

Engines never read stdin or write stdout. They throw `ArithmosError` (code + message), so
they can be tested directly and reused by a later GUI. Only `cli.cpp` turns values into text
and errors into `Error [CODE]: message`.

## How the hard parts are done

**64-bit integers.** `std::int64_t` / `std::uint64_t`. Bitwise operations and shifts run on
`uint64_t`, so there is no signed overflow or implementation-defined shifting. Results are
converted back with `toSigned()`, which does not depend on how the compiler converts
out-of-range unsigned values. `>>` is built from `>>` on a non-negative value
(`~((~v) >> n)` for negatives); `>>>` is a plain unsigned shift.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`double`. `formatNumber` prints the value with `%.34e` (an exact expansion), rounds that digit
string to 12 significant digits half away from zero, trims zeros and picks plain or scientific
notation (spec §2.3). Binary `printf` rounding (half to even on exact ties) is not used, so
`100000000000.5` gives `100000000001`. Spec §3.4 percent rules: a `%` that is the *direct*
right operand of `+` / `-` is relative; the parser wraps parentheses in a `Group` node so
`200 + (10%)` is plain.

## Interface

- **On a real terminal** (stdin and stdout are terminals, `TERM` is not `dumb`, and
  `ARITHMOS_PLAIN` is not `1`) the menus and converter pickers are arrow-key selectors:
  ↑↓ move (wrapping), Home/End/PgUp/PgDn jump, Enter selects, Esc or `b` goes back, `q` quits,
  Ctrl-C / Ctrl-D ends the input. Lists longer than 10 rows scroll. The selected row is a full
  reverse-video bar with `❯`; a chosen row leaves `✔ <title>: <label>` behind.
- **Typing still works.** Any other printable key opens a typed line (number, name, symbol or
  one-line command such as `100 cm in`): the prompt shows the key and the rest of the line is
  read. Names that start with `b` or `q` (`bit`, `byte`, `bar`, `btu`, `qt`) must be picked with
  the arrows or a number, because `b` and `q` act at once.
- **Everywhere else** (pipes, files, tests, dumb terminals) and with **`ARITHMOS_PLAIN=1`** the
  same screens are numbered lists (`  1) length`), answered by typing a number, a name or a
  symbol. Typed words: `help` / `?`, `quit`, and `back` where a screen can go back.
- `NO_COLOR=1` removes the colours (the `❯` pointer stays).
- Esc works in the selectors only. The prompts (`standard>`, `converter (m → yd)>`) read whole
  lines, so use `back` there.
- The terminal is raw only while a key is being read, so it is never left raw.
- **Windows:** the console is switched to UTF-8 and ANSI escape processing while the program
  runs, and restored on exit. The selector needs a real console (cmd, PowerShell, Windows
  Terminal). Git Bash (mintty) is not a console, so it shows numbered lists; run
  `winpty ./arithmos.exe` to get the selector there.
- The converter is the guided flow (category → from → to → values) with the units in the
  prompt.

## Deviations from the spec

None. All 175 shared cases pass.

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)