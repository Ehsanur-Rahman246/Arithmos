# Arithmos — Swift edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in Swift, Swift standard
library and Foundation only. Follows [the Release 1 spec](../docs/specifications/release-1.md).
Checked against the JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.
<!-- Only enable the line above after `swift test` passes on your machine and the hand-test checklist is done. -->

## Prerequisites

- **Swift 5.9 or newer** (`swift --version`) with SwiftPM, on **Linux or macOS**.
- No packages, no Xcode project. Windows: use WSL (see Deviations).

## Run

From this folder:

```bash
swift run arithmos                          # interactive menu (builds first)
swift run arithmos std "20% of 150"         # one calculation        → 30
swift run arithmos prog 0xFF AND 0x0F       # one programmer command
swift run arithmos convert 100 cm in        # one conversion         → 39.3700787402
swift run arithmos list length
swift build -c release                      # optional: .build/release/arithmos
```

Quote expressions the shell would interpret: `prog "-8 >>> 1"`, `std "(2 + 3) * 4"`.

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly. One-shot exit status: `0` success, `1` the
line produced an `Error [CODE]`, `2` bad usage. One-shot errors go to stderr; interactive
errors go to stdout.

## Test

```bash
swift test
CASES=path/to/cases.json swift test        # another case file
```

| File | What it checks | Count |
|---|---|---|
| `CasesTests.swift` | The shared cases (loaded from `../docs/release-1-cases.json`) | 175 shared |
| `ExtrasTests.swift` | Formatting boundaries, settled amendments, garbage input, one-shot exit codes, scripted sessions | extras |
| `SelectorTests.swift` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |

## Layout

```text
swift/
├── Package.swift
├── Sources/
│   ├── arithmos/main.swift          entry point (calls arithmosRun)
│   └── ArithmosKit/
│       ├── Entry.swift              big-stack thread, argv → one-shot or menu
│       ├── CLI/                     Tools (menus, prompt loops, guided converter), OneShot, Pick,
│       │                            Selector, Keys, Terminal (termios, ConsoleIo), Io, Style
│       ├── Calculator/              Calculator.swift: tokenizer → parser (AST) → evaluator
│       ├── Programmer/              Programmer.swift: literals, commands, output
│       ├── Converter/               Converter.swift (logic) + Units.swift (unit tables as data)
│       └── Shared/                  Errors.swift, FormatNumber.swift
└── Tests/ArithmosKitTests/          Support, CasesTests, ExtrasTests, SelectorTests
```

Engines never read stdin or write stdout. They throw `ArithmosError` (code + message), so they
can be tested directly and reused by a later GUI. Only the `CLI` folder turns values into text
and errors into `Error [CODE]: message`.

## How the hard parts are done

**64-bit integers.** Swift's `Int64` is a native signed two's-complement integer. The masking
shifts `&<<` and `&>>` act on the 64-bit pattern and never trap (`1 << 63` is
`Int64.min`; `&>>` on a signed value is arithmetic). `>>>` is `&>>` on the `UInt64` bit
pattern. Literals are accumulated digit by digit into a `UInt64` with
`multipliedReportingOverflow` / `addingReportingOverflow`, so range checks are exact
(`0xFFFFFFFFFFFFFFFF` is `-1`, `0x10000000000000000` is `OUT_OF_RANGE`) and nothing passes
through `Double`. `String(UInt64(bitPattern:), radix:)` prints a negative value as its unsigned
64-bit pattern, which is the spec's "full 64-bit pattern" rule. Negation of `Int64.min` is
special-cased so no arithmetic ever traps.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`Double`. `formatNumber` prints the value with `String(format: "%.34e")` (an exact expansion on
glibc and Apple libc), rounds that digit string to 12 significant digits half away from zero by
hand, trims zeros and picks plain or scientific notation (spec §2.3), so `100000000000.5` gives
`100000000001`. Swift's own `description` and `round` are not used. Spec §3.4 percent rules: a `%`
that is the *direct* right operand of `+` / `-` is relative; the parser wraps parentheses in a
`group` node, so `200 + (10%)` is plain.

## Interface

- **On a real terminal** (stdin and stdout are terminals, `TERM` is not `dumb`, and
  `ARITHMOS_PLAIN` is not `1`) the menus and converter pickers are arrow-key selectors:
  ↑↓ move (wrapping), Home/End/PgUp/PgDn jump, Enter selects, Esc or `b` goes back, `q` quits,
  Ctrl-C / Ctrl-D ends the input. Lists longer than 10 rows scroll. The selected row is a full
  reverse-video bar with `❯`; a chosen row leaves `✔ <title>: <label>` behind.
- **Typing still works.** Any other printable key opens a typed line (number, name, symbol or
  one-line command such as `100 cm in`). Names that start with `b` or `q` (`bit`, `byte`, `bar`,
  `btu`, `qt`) must be picked with the arrows or a number, because `b` and `q` act at once.
- **Everywhere else** (pipes, files, tests, dumb terminals) and with **`ARITHMOS_PLAIN=1`** the
  same screens are numbered lists (`  1) length`), answered by typing a number, a name or a symbol.
- `NO_COLOR=1` removes the colours (the `❯` pointer stays).
- Esc works in the selectors only. The prompts (`standard>`, `converter (m → yd)>`) read whole
  lines, so use `back` there.
- Every drawn line is at most (terminal width − 1) columns and the list window shrinks to fit the
  terminal height. Both are measured on every redraw (`ioctl TIOCGWINSZ`), so resizing works.
- **Raw mode (POSIX).** The selector uses `termios` directly (`ICANON`, `ECHO` and `ISIG` off,
  `VMIN 1`). Raw mode is on only while a selector is on screen. It is restored in `leave()` and by
  SIGTERM/SIGHUP handlers installed only while a selector is on screen, so the terminal is never
  left raw. A lone Esc is told from an arrow key by a 40 ms wait for further bytes. Keys and lines
  share one byte buffer, so type-ahead is never lost.
- The converter is the guided flow (category → from → to → values) with the units in the prompt.
  Unit rows read `m — metre`; a symbol or the name selects them.

## Deviations from the spec

None in behaviour. Runtime notes: **POSIX only** (Linux, macOS; Windows through WSL), because the
selector is written against `termios`; a native Windows build would need a console layer like the
other editions have. A Standard Calculator line longer than 20 000 characters is rejected with
`INVALID_EXPRESSION` (the program runs on a 256 MB-stack thread, so deep nesting below that limit
is safe).

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)