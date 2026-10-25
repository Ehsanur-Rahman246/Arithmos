# Arithmos — Go edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in Go, standard library only.
Follows [the Release 1 spec](../docs/specifications/release-1.md). Checked against the
JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.
<!-- Only keep this line after `go test ./...` passes on your machine and the hand-test checklist is done. -->

## Prerequisites

- **Go 1.21 or newer** (`go version`). No modules to download: the standard library only.
- POSIX: `stty` (coreutils) for the arrow-key selector. Windows: a real console (cmd,
  PowerShell, Windows Terminal).

## Run

From this folder:

```bash
go run ./cmd/arithmos                          # interactive menu
go run ./cmd/arithmos std "20% of 150"         # one calculation        → 30
go run ./cmd/arithmos prog 0xFF AND 0x0F       # one programmer command
go run ./cmd/arithmos convert 100 cm in        # one conversion         → 39.3700787402
go run ./cmd/arithmos list length
go build -o arithmos ./cmd/arithmos            # optional: a standalone binary
```

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly. One-shot exit status: `0` success, `1` the
line produced an `Error [CODE]`, `2` bad usage. One-shot errors go to stderr; interactive
errors go to stdout.

## Test

```bash
go vet ./...
go test ./...
```

| File | What it checks | Count |
|---|---|---|
| `test/cases_test.go` | The shared cases (loaded from `../docs/release-1-cases.json`; `CASES=path` overrides) | 175 shared |
| `test/extras_test.go` | Formatting boundaries, settled amendments, unit-table sanity, garbage input, scripted sessions, one-shot exit codes | extras |
| `test/selector_test.go` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |

## Layout

```text
go/
├── go.mod
├── cmd/arithmos/main.go     entry point
├── internal/
│   ├── cli/                 cli.go (one-shot, entry), tools.go (prompt loops, guided converter, menu),
│   │                        pick.go, selector.go, keys.go, io.go, term_unix.go, term_windows.go
│   ├── calculator/          calculator.go: tokenizer → parser (AST) → evaluator
│   ├── programmer/          programmer.go: literals, commands, output
│   ├── converter/           converter.go (logic) + units.go (unit tables as data)
│   └── shared/              errors.go, format.go
└── test/                    cases_test.go, extras_test.go, selector_test.go
```

Engines never read stdin or write stdout. They throw `*shared.Error` (code + message) with
`panic` internally and every public function wraps its body in `shared.Guard`, so callers get
a normal returned `error`. Only the `cli` layer turns values into text and errors into
`Error [CODE]: message`.

## How the hard parts are done

**64-bit integers.** Go's `int64` is a native signed two's-complement integer, so `& | ^`,
`^x` (NOT), `<<`, and the arithmetic `>>` act on the 64-bit pattern directly. `<<` and `>>>`
run on `uint64` (`>>>` is a plain unsigned shift). Literals are accumulated digit by digit
into a `math/big.Int`, so range checks are exact (`0xFFFFFFFFFFFFFFFF` is `-1`,
`0x10000000000000000` is `OUT_OF_RANGE`) and nothing passes through `float64`.
`strconv.FormatUint(uint64(v), 16|8|2)` prints a negative value as its unsigned 64-bit
pattern, which is the spec's "full 64-bit pattern" rule.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`float64`. `shared.FormatNumber` prints the exact binary value with
`big.Float.Text('e', 800)` (800 digits is more than any double has, so the expansion is
exact), rounds that digit string to 12 significant digits half away from zero by hand, trims
zeros and picks plain or scientific notation (spec §2.3). Go's own `strconv` formatting is
not used, so `100000000000.5` gives `100000000001`. Spec §3.4 percent rules: a `%` that is the
*direct* right operand of `+` / `-` is relative; the parser wraps parentheses in a `groupN`
node, so `200 + (10%)` is plain.

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
  lines in the terminal's normal mode, so use `back` there.
- Every drawn line is at most (terminal width − 1) columns and the list window shrinks to fit the
  terminal height. Both are measured on every redraw (cached for 150 ms), so resizing works.
- **Raw mode (POSIX).** Go has no raw-mode API in the standard library, so the selector calls
  `stty` on `/dev/tty` (`-icanon -echo -isig min 0 time 1`) and reads keys with `syscall.Read`.
  Raw mode is on only while a selector is on screen. It is restored in `Leave` and by
  SIGTERM/SIGHUP handlers, so the terminal is never left raw. A lone Esc is told from an arrow
  key by the 0.1 s read timeout.
- **Windows.** Keys come from `_getwch` (msvcrt) and the console mode from kernel32, both through
  `syscall.NewLazyDLL`; ANSI escapes and UTF-8 are switched on while the program runs and
  restored on exit. The selector needs a real console (cmd, PowerShell, Windows Terminal). Git
  Bash (mintty) is not a console, so it shows numbered lists; run `winpty go run ./cmd/arithmos`
  to get the selector there.
- The converter is the guided flow (category → from → to → values) with the units in the prompt.
  Unit rows read `m — metre`; a symbol or the name selects them.

## Deviations from the spec

None in behaviour. Runtime note: POSIX needs `stty` for the selector, otherwise numbered lists
are used.

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)