# Arithmos — Java edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in Java, standard library only.
Follows [the Release 1 spec](../docs/specifications/release-1.md). Checked against the JavaScript
reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.
<!-- Only keep this line after `RunCases` and `RunSelector` pass on your machine. -->

## Prerequisites

- **JDK 22 or newer** (developed for 25). Needs `java.lang.foreign` (final in 22) and
  `Console.isTerminal()` (22). No third-party packages, no build tool.
- `make` is optional; every command below also works without it.

## Run

From this folder, build once:

```bash
mkdir -p out && javac -d out $(find src -name '*.java')            # bash
```

```powershell
New-Item -ItemType Directory -Force out | Out-Null                 # PowerShell
javac -d out (Get-ChildItem src -Recurse -Filter *.java).FullName
```

Then:

```bash
java --enable-native-access=ALL-UNNAMED -cp out arithmos.Main                       # interactive menu
java --enable-native-access=ALL-UNNAMED -cp out arithmos.Main std "20% of 150"      # → 30
java -cp out arithmos.Main prog 0xFF AND 0x0F                                       # one programmer command
java -cp out arithmos.Main convert 100 cm in                                        # → 39.3700787402
java -cp out arithmos.Main list length
```

`--enable-native-access=ALL-UNNAMED` is only needed on Windows (the selector calls the console
through the foreign-function API); without it JDK 24+ prints a warning.

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all case-insensitive).
End-of-input exits cleanly. One-shot exit status: `0` success, `1` the line produced an
`Error [CODE]`, `2` bad usage. One-shot errors go to stderr; interactive errors go to stdout.

## Test

```bash
make test
# or, without make (use ';' instead of ':' in -cp on Windows):
mkdir -p out-test && javac -d out-test -cp out $(find test -name '*.java')
java -cp out:out-test arithmos.RunCases ../docs/release-1-cases.json
java -cp out:out-test arithmos.RunSelector
```

| Program | What it checks | Count |
|---|---|---|
| `RunCases` | The shared cases (loaded from `../docs/release-1-cases.json` with a small built-in JSON reader), then Java extras: formatting boundaries, settled amendments, garbage input, scripted CLI sessions | 175 shared + extras |
| `RunSelector` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |

## Layout

```text
java/
├── Makefile
├── src/arithmos/
│   ├── Main.java            entry point: argv → one-shot or menu
│   ├── cli/                 Cli (menu, one-shot), Tools (prompt loops, tool bindings),
│   │                        Pick, Selector, KeyParser, Terminal, ConsoleIo, Io, Style (the only I/O layer)
│   ├── calculator/          Tokenizer → Parser (AST) → Evaluator, Calculator (session)
│   ├── programmer/          Base, Literal (parsing), Programmer (commands)
│   ├── converter/           Converter (logic) + Units (unit tables as data)
│   └── shared/              ArithmosError, FormatNumber
└── test/arithmos/           RunCases, RunSelector, Json, Fakes
```

Engines never read stdin or write stdout. They throw `ArithmosError` (code + message), so they can be
tested directly and reused by a later GUI. Only the `cli` package turns values into text and errors
into `Error [CODE]: message`.

## How the hard parts are done

**64-bit integers.** Java's native `long` is a signed 64-bit two's-complement integer, which is the
spec's model. `<<` drops bits shifted past bit 63, `>>` is arithmetic and `>>>` is logical, so
nothing needs emulating. Literals are parsed with `BigInteger` and then reduced with `longValue()`
(the low 64 bits, read as signed). Range checks are therefore exact: `0xFFFFFFFFFFFFFFFF` is `-1`,
`0x10000000000000000` is `OUT_OF_RANGE`. `Long.toHexString`, `toOctalString` and `toBinaryString`
print the unsigned bit pattern, which is the spec's "full 64-bit pattern" rule for negative values.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`double`. `FormatNumber.format` converts the exact double with `new BigDecimal(double)` and rounds it
with `new MathContext(12, RoundingMode.HALF_UP)`. On `BigDecimal`, `HALF_UP` rounds ties away from
zero, as spec §2.3 requires, so `100000000000.5` gives `100000000001`. It then trims zeros and
picks plain or scientific notation. Spec §3.4 percent rules: a `%` that is the *direct* right
operand of `+` / `-` is relative; the parser wraps parentheses in a `Group` node, so `200 + (10%)`
is plain.

## Interface

- **On a real terminal** (stdin and stdout are terminals, `TERM` is not `dumb`, and `ARITHMOS_PLAIN`
  is not `1`) the menus and converter pickers are arrow-key selectors: ↑↓ move (wrapping),
  Home/End/PgUp/PgDn jump, Enter selects, Esc or `b` goes back, `q` quits, Ctrl-C / Ctrl-D ends the
  input. Lists longer than 10 rows scroll. The selected row is a full reverse-video bar with `❯`; a
  chosen row leaves `✔ <title>: <label>` behind.
- **Typing still works.** Any other printable key opens a typed line (number, name, symbol or
  one-line command such as `100 cm in`). Names that start with `b` or `q` (`bit`, `byte`, `bar`,
  `btu`, `qt`) must be picked with the arrows or a number, because `b` and `q` act at once.
- **Everywhere else** (pipes, files, tests, dumb terminals) and with **`ARITHMOS_PLAIN=1`** the same
  screens are numbered lists (`  1) length`), answered by typing a number, a name or a symbol.
- `NO_COLOR=1` removes the colours (the `❯` pointer stays).
- Esc works in the selectors only. The prompts (`standard>`, `converter (m → yd)>`) read whole
  lines, so use `back` there.
- Every drawn line is at most (terminal width − 1) columns and the list window shrinks to fit the
  terminal height. Both are measured on every redraw (cached for 150 ms), so resizing works.
- **Raw mode (POSIX).** Java has no raw-mode API, so the selector calls `stty` on `/dev/tty`. Raw mode
  is on only while the selector is on screen. It is restored in a `finally` and in a shutdown hook, so
  the terminal is never left raw. (One `stty` pair per selector, not per key, keeps it fast.)
- **Windows.** Keys, window size, ANSI escapes and UTF-8 come from kernel32 and `_getwch` through the
  foreign-function API (`java.lang.foreign`), so run with `--enable-native-access=ALL-UNNAMED`. The
  console mode and code pages are restored on exit. The selector needs a real console (cmd,
  PowerShell, Windows Terminal). Git Bash (mintty) is not a console, so it shows numbered lists; run
  `winpty java ...` to get the selector there. If the foreign-function calls fail, the program falls
  back to numbered lists.
- The converter is the guided flow (category → from → to → values) with the units in the prompt.
  Unit rows read `m — metre`; a symbol or the name selects them.

## Deviations from the spec

None in behaviour. All 175 shared cases pass. Interface notes (raw mode per selector run,
`--enable-native-access` on Windows) are listed above.

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)