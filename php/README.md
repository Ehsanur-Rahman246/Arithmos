# Arithmos: PHP edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in PHP, standard library
only. Follows [the Release 1 spec](../docs/specifications/release-1.md). Checked against the
JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.

## Prerequisites

- PHP 8.0 or newer, CLI, **64-bit build** (`php -r "echo PHP_INT_SIZE;"` prints `8`)
- Core extensions only (pcre, which is always on). No Composer, no packages.
- `shell_exec` must be enabled for the arrow-key selector (it uses `stty`, or PowerShell on
  Windows). Without it, set `ARITHMOS_PLAIN=1`.

## Run

```bash
cd php
php bin/arithmos.php                         # interactive menu (or: make run)
php bin/arithmos.php std "20% of 150"        # one calculation        → 30
php bin/arithmos.php prog 0xFF AND 0x0F      # one programmer command
php bin/arithmos.php convert 100 cm in       # one conversion         → 39.3700787402
php bin/arithmos.php list length
```

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly. One-shot exit status: `0` success, `1` the
line produced an `Error [CODE]`, `2` bad usage; one-shot errors go to stderr, interactive
errors to stdout.

## Test

```bash
make test
# or
php test/run_cases.php ../docs/release-1-cases.json
php test/run_selector.php
```

| Program | What it checks | Count |
|---|---|---|
| `test/run_cases.php` | The shared cases (loaded from `../docs/release-1-cases.json`), then PHP extras: formatting boundaries, settled amendments, garbage input, scripted sessions, one-shot exit codes | 175 shared + extras |
| `test/run_selector.php` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |

## Layout

```text
php/
├── Makefile
├── bin/arithmos.php        entry point
├── src/
│   ├── autoload.php        plain require list
│   ├── cli/                cli.php (menu, one-shot), tools.php (prompt loops, tool bindings),
│   │                       pick.php, selector.php, terminal.php, io.php, render.php (the only I/O layer)
│   ├── calculator/         tokenizer → parser (AST) → evaluator
│   ├── programmer/         int64.php (ops, output), parse.php (literals), programmer.php (commands)
│   ├── converter/          converter.php (logic) + units.php (unit tables as data)
│   └── shared/             errors.php, format_number.php
└── test/
    ├── run_cases.php
    └── run_selector.php
```

Engines never read stdin or write stdout. They throw `ArithmosError` (code + message), so they
can be tested directly and reused by a later GUI.

## How the hard parts are done

**64-bit integers.** PHP's native `int` is 64-bit signed on a 64-bit build. The Programmer
engine uses it only for bitwise work and shifts, where it wraps natively (`1 << 63` is
`PHP_INT_MIN`). Anything that could silently turn into `float` is avoided: literals are parsed
from strings, never through float. Decimal text is compared against the limits as a string;
bin/oct/hex accumulate the bit pattern digit by digit and refuse to shift out set bits.
`>>` is PHP's arithmetic shift; `>>>` clears the sign-extended top bits with
`PHP_INT_MAX >> (n-1)`. `dechex`/`decoct`/`decbin` print an int as unsigned, which is the
spec's "full 64-bit pattern" rule for negative values.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`float`. `FormatNumber::format` prints the value with `sprintf('%.34e')` (an exact expansion;
PHP uses correctly rounding `zend_dtoa`), rounds the digit string to 12 significant digits half
away from zero by hand, trims zeros and picks plain or scientific notation (spec §2.3). PHP's
`round()` and float formatting are not used, so `100000000000.5` gives `100000000001`. Spec §3.4
percent rules: a `%` that is the *direct* right operand of `+`/`-` is relative; the parser wraps
parentheses in a `group` node so `200 + (10%)` is plain.

## Interface

- **On a real terminal** (stdin and stdout are terminals, `TERM` is not `dumb`, and
  `ARITHMOS_PLAIN` is not `1`) the menus and converter pickers are arrow-key selectors:
  ↑↓ move (wrapping), Home/End/PgUp/PgDn jump, Enter selects, Esc or `b` goes back, `q` quits,
  Ctrl-C / Ctrl-D ends the input. Lists longer than 10 rows scroll. The selected row is a full
  reverse-video bar with `❯`; a chosen row leaves `✔ <title>: <label>` behind.
- **Typing still works.** Any other printable key opens a typed line (number, name, symbol or
  one-line command such as `100 cm in`). Names that start with `b` or `q` (`bit`, `byte`,
  `bar`, `btu`, `qt`) must be picked with the arrows or a number.
- **Everywhere else** (pipes, files, tests, dumb terminals) and with **`ARITHMOS_PLAIN=1`** the
  same screens are numbered lists (`  1) length`), answered by typing a number, a name or a symbol.
- `NO_COLOR=1` removes the colours (the `❯` pointer stays).
- Esc works in the selectors only. The prompts (`standard>`, `converter (m → yd)>`) read whole
  lines, so use `back` there.
- The terminal is raw only while a key is being read (`stty -icanon -echo -isig`, restored in a
  `finally`), so it is never left raw.
- **Windows:** PHP has no raw console read, so each key press is read by a short PowerShell call.
  The selector works but is slower per key; typing a number is quicker. Terminal height comes from
  `mode con`, which reports the buffer, not the window, so the 10-row window may be taller than a
  very short console. The console is switched to UTF-8 and ANSI escapes while the program runs,
  and restored on exit.
- The converter is the guided flow (category → from → to → values) with the units in the prompt.
  Unit rows read `m — metre`; a symbol or the name selects them.

## Deviations from the spec

None in behaviour. All 175 shared cases pass. Interface notes (Windows key reading, `shell_exec`
for the selector) are listed above.

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)