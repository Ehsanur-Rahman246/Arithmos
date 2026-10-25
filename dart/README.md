<!-- dart/README.md  (same template as the other editions) -->
# Arithmos — Dart edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in Dart, SDK only
(`dart:io`, `dart:ffi`, `dart:convert`, `dart:math`). Follows
[the Release 1 spec](../docs/specifications/release-1.md). Checked against the
JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.
<!-- Only keep this line after `dart run test/run_cases.dart` and `dart run test/run_selector.dart`
     pass on your machine and the hand-test checklist is done. -->

## Prerequisites

- **Dart SDK 3.0 or newer** (`dart --version`). VM only: native `int` is 64-bit on the VM,
  not under dart2js.
- No packages. The first `dart run` creates `.dart_tool/` by itself.
- POSIX: `sh` and `stty` (coreutils) for the arrow-key selector. Windows: a real console
  (cmd, PowerShell, Windows Terminal).

## Run

From this folder:

```bash
dart run bin/arithmos.dart                         # interactive menu
dart run bin/arithmos.dart std "20% of 150"        # one calculation        → 30
dart run bin/arithmos.dart prog 0xFF AND 0x0F      # one programmer command
dart run bin/arithmos.dart convert 100 cm in       # one conversion         → 39.3700787402
dart run bin/arithmos.dart list length
dart compile exe bin/arithmos.dart -o arithmos     # optional: a standalone binary
```

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly. One-shot exit status: `0` success, `1` the
line produced an `Error [CODE]`, `2` bad usage. One-shot errors go to stderr; interactive
errors go to stdout.

## Test

```bash
dart run test/run_cases.dart ../docs/release-1-cases.json
dart run test/run_selector.dart
```

| Program | What it checks | Count |
|---|---|---|
| `test/run_cases.dart` | The shared cases (loaded from `../docs/release-1-cases.json`), then Dart extras: formatting boundaries, settled amendments, unit-table sanity, garbage input, scripted sessions, one-shot exit codes | 175 shared + extras |
| `test/run_selector.dart` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |

## Layout

```text
dart/
├── pubspec.yaml
├── bin/arithmos.dart          entry point
├── lib/src/
│   ├── cli/                   cli.dart (one-shot, entry), tools.dart (prompt loops, guided converter, menu),
│   │                          pick.dart, selector.dart, keys.dart, terminal.dart, io.dart (the only I/O layer)
│   ├── calculator/            calculator.dart: tokenizer → parser (AST) → evaluator
│   ├── programmer/            programmer.dart: literals, commands, output
│   ├── converter/             converter.dart (logic) + units.dart (unit tables as data)
│   └── shared/                errors.dart, format_number.dart
└── test/                      fakes.dart, run_cases.dart, run_selector.dart
```

Engines never read stdin or write stdout. They throw `ArithmosError` (code + message), so
they can be tested directly and reused by a later GUI. Only the `cli` layer turns values
into text and errors into `Error [CODE]: message`. Engines are synchronous; only the CLI
layer is `async` (so a signal can restore the terminal while a selector waits for a key).

## How the hard parts are done

**64-bit integers.** Dart's native `int` is a signed 64-bit two's-complement integer on the
VM, so `&  |  ^  ~  <<  >>  >>>` act on the 64-bit pattern directly (`1 << 63` is
`-9223372036854775808`, `-8 >>> 1` is `9223372036854775804`). Literals are parsed digit by
digit into a `BigInt`, so range checks are exact (`0xFFFFFFFFFFFFFFFF` is `-1`,
`0x10000000000000000` is `OUT_OF_RANGE`). HEX/OCT/BIN print `BigInt.from(v).toUnsigned(64)`,
which is the spec's "full 64-bit pattern" rule for negative values.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`double`. `formatNumber` builds the exact decimal expansion of the double with `BigInt`
(`mantissa × 5^k` for the fractional part), rounds that digit string to 12 significant digits
half away from zero by hand, trims zeros and picks plain or scientific notation (spec §2.3),
so `100000000000.5` gives `100000000001`. Dart's own `toStringAsFixed` / `toStringAsPrecision`
are not used. Spec §3.4 percent rules: a `%` that is the *direct* right operand of `+` / `-`
is relative; the parser wraps parentheses in a `_Group` node, so `200 + (10%)` is plain.

## Interface

- **On a real terminal** (stdin and stdout are terminals, `TERM` is not `dumb`, and
  `ARITHMOS_PLAIN` is not `1`, and raw mode works) the menus and converter pickers are
  arrow-key selectors: ↑↓ move (wrapping), Home/End/PgUp/PgDn jump, Enter selects, Esc or `b`
  goes back, `q` quits, Ctrl-C / Ctrl-D ends the input. Lists longer than 10 rows scroll. The
  selected row is a full reverse-video bar with `❯`; a chosen row leaves `✔ <title>: <label>`
  behind.
- **Typing still works.** Any other printable key opens a typed line (number, name, symbol or
  one-line command such as `100 cm in`). Names that start with `b` or `q` (`bit`, `byte`,
  `bar`, `btu`, `qt`) must be picked with the arrows or a number, because `b` and `q` act at once.
- **Everywhere else** (pipes, files, tests, dumb terminals) and with **`ARITHMOS_PLAIN=1`** the
  same screens are numbered lists (`  1) length`), answered by typing a number, a name or a symbol.
- `NO_COLOR=1` removes the colours (the `❯` pointer stays).
- Esc works in the selectors only. The prompts (`standard>`, `converter (m → yd)>`) read whole
  lines, so use `back` there.
- Every drawn line is at most (terminal width − 1) columns and the list window shrinks to fit the
  terminal height. Both are measured on every redraw, so resizing works.
- **Raw mode (POSIX).** Dart has no raw-mode API with timeouts, so the selector calls `stty` on
  `/dev/tty` (`-icanon -echo -isig min 0 time 1`) and reads keys with libc `read()` through
  `dart:ffi`. Raw mode is on only while a selector is on screen. It is restored in a `finally`
  and by SIGTERM/SIGHUP handlers, so the terminal is never left raw. A lone Esc is told from an
  arrow key by the 0.1 s read timeout.
- **Windows.** Keys come from `_getwch` and the console mode from kernel32, both through
  `dart:ffi`; ANSI escapes and UTF-8 are switched on while the program runs and restored on
  exit. The selector needs a real console (cmd, PowerShell, Windows Terminal). Git Bash
  (mintty) is not a console, so it shows numbered lists; run `winpty dart run ...` to get the
  selector there. If the foreign calls fail, the program falls back to numbered lists.
- The converter is the guided flow (category → from → to → values) with the units in the prompt.
  Unit rows read `m — metre`; a symbol or the name selects them.

## Deviations from the spec

None in behaviour. Runtime notes: Dart VM only (not dart2js); POSIX needs `sh` + `stty` for the
selector, otherwise numbered lists are used.

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)