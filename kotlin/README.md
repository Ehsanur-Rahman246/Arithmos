# Arithmos — Kotlin edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in Kotlin (JVM), Kotlin and Java
standard libraries only. Follows [the Release 1 spec](../docs/specifications/release-1.md). Checked
against the JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.
<!-- Only keep this line after both test programs pass on your machine and the hand-test checklist is done. -->

## Prerequisites

- **JDK 22 or newer** (`java -version`) and **Kotlin 1.9 or newer** (`kotlinc -version`).
- No libraries, no Gradle or Maven: `kotlinc` compiles the source folder directly.
- POSIX: `stty` (coreutils) for the arrow-key selector. Windows: `powershell.exe` (built in).
- `--enable-native-access=ALL-UNNAMED` is only needed on Windows (the selector calls the console through java.lang.foreign); without it JDK 24+ prints a warning.

## Run

From this folder, build once:

```bash
kotlinc src/main/kotlin -include-runtime -d arithmos.jar
```

```powershell
kotlinc src/main/kotlin -include-runtime -d arithmos.jar
```

Then:

```bash
java -jar arithmos.jar                          # interactive menu
java -jar arithmos.jar std "20% of 150"         # one calculation        → 30
java -jar arithmos.jar prog 0xFF AND 0x0F       # one programmer command
java -jar arithmos.jar convert 100 cm in        # one conversion         → 39.3700787402
java -jar arithmos.jar list length
```

If the jar has no `Main-Class`, use `java -cp arithmos.jar arithmos.MainKt`.
Quote expressions the shell would interpret: `prog "-8 >>> 1"`, `std "(2 + 3) * 4"`.

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly. One-shot exit status: `0` success, `1` the line
produced an `Error [CODE]`, `2` bad usage. One-shot errors go to stderr; interactive errors go to stdout.

## Test

```bash
kotlinc src/main/kotlin src/test/kotlin -include-runtime -d arithmos-tests.jar
java -cp arithmos-tests.jar arithmos.test.RunCasesKt ../docs/release-1-cases.json
java -cp arithmos-tests.jar arithmos.test.RunSelectorKt
```

| Program | What it checks | Count |
|---|---|---|
| `RunCases` | The shared cases (loaded from `../docs/release-1-cases.json` with a small built-in JSON reader), then Kotlin extras: formatting boundaries, settled amendments, unit-table sanity, garbage input, a scripted session, one-shot exit codes | 175 shared + extras |
| `RunSelector` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |

Each runner prints `N passed, M failed` and exits `1` on any failure.

## Layout

```text
kotlin/
├── src/main/kotlin/
│   ├── Main.kt                 entry point: argv → one-shot or menu (256 MB stack thread)
│   ├── cli/                    Tools (menus, prompt loops, guided converter), Pick, Selector, Keys,
│   │                           Terminal (stty / PowerShell helper, ConsoleIo), Io, OneShot (the only I/O layer)
│   ├── calculator/             Calculator.kt: tokenizer → parser (AST) → evaluator
│   ├── programmer/             Programmer.kt: literals, commands, output
│   ├── converter/              Converter.kt (logic) + Units.kt (unit tables as data)
│   └── shared/                 Errors.kt, FormatNumber.kt
└── src/test/kotlin/            Fakes.kt, Json.kt, RunCases.kt, RunSelector.kt
```

Engines never read stdin or write stdout. They throw `ArithmosError` (code + message), so they can
be tested directly and reused by a later GUI. Only the `cli` package turns values into text and
errors into `Error [CODE]: message`.

## How the hard parts are done

**64-bit integers.** Kotlin's `Long` is a native signed two's-complement integer, so `and or xor inv`,
`shl`, the arithmetic `shr` and the logical `ushr` act on the 64-bit pattern directly (`1 shl 63` is
`Long.MIN_VALUE`). Literals are parsed digit by digit into a `BigInteger`, so range checks are exact
(`0xFFFFFFFFFFFFFFFF` is `-1`, `0x10000000000000000` is `OUT_OF_RANGE`) and nothing passes through
`Double`. `Long.toHexString`, `toOctalString` and `toBinaryString` print a negative value as its
unsigned 64-bit pattern, which is the spec's "full 64-bit pattern" rule.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE `Double`.
`formatNumber` converts the exact double with `BigDecimal(double)` and rounds it with
`MathContext(12, RoundingMode.HALF_UP)`. On `BigDecimal`, `HALF_UP` rounds ties away from zero, as spec
§2.3 requires, so `100000000000.5` gives `100000000001`. It then trims zeros and picks plain or
scientific notation. Spec §3.4 percent rules: a `%` that is the *direct* right operand of `+` / `-` is
relative; the parser wraps parentheses in a `Group` node, so `200 + (10%)` is plain.

## Interface

- **On a real terminal** (stdin and stdout are terminals, `TERM` is not `dumb`, and `ARITHMOS_PLAIN`
  is not `1`) the menus and converter pickers are arrow-key selectors: ↑↓ move (wrapping),
  Home/End/PgUp/PgDn jump, Enter selects, Esc or `b` goes back, `q` quits, Ctrl-C / Ctrl-D ends the
  input. Lists longer than 10 rows scroll. The selected row is a full reverse-video bar with `❯`; a
  chosen row leaves `✔ <title>: <label>` behind.
- **Typing still works.** Any other printable key opens a typed line (number, name, symbol or one-line
  command such as `100 cm in`). Names that start with `b` or `q` (`bit`, `byte`, `bar`, `btu`, `qt`)
  must be picked with the arrows or a number, because `b` and `q` act at once.
- **Everywhere else** (pipes, files, tests, dumb terminals) and with **`ARITHMOS_PLAIN=1`** the same
  screens are numbered lists (`  1) length`), answered by typing a number, a name or a symbol.
- `NO_COLOR=1` removes the colours (the `❯` pointer stays).
- Esc works in the selectors only. The prompts (`standard>`, `converter (m → yd)>`) read whole lines,
  so use `back` there.
- Every drawn line is at most (terminal width − 1) columns and the list window shrinks to fit the
  terminal height. Both are measured on every redraw (cached for 150 ms on POSIX), so resizing works.
- **Raw mode (POSIX).** The JVM has no raw-mode API, so the selector calls `stty` on `/dev/tty`
  (`-icanon -echo -isig`) and reads keys from `/dev/tty`. Raw mode is on only while a selector is on
  screen. It is restored in a `finally` and in a shutdown hook (Ctrl-C, SIGTERM, SIGHUP), so the
  terminal is never left raw. A lone Esc is told from an arrow key by a 25 ms wait for pending bytes.
- **Windows.** Keys (`_getwch`), window size, ANSI escapes and UTF-8 come from msvcrt and kernel32 through the
    foreign-function API (`java.lang.foreign`), so run with `--enable-native-access=ALL-UNNAMED`. The console mode and
    code page are restored on exit. Ctrl-C is read as a key while a selector is on screen. Git Bash (mintty) is not a
    console, so it shows numbered lists; run `winpty java ... -jar arithmos.jar` to get the selector there. If the
    foreign calls fail, the program falls back to numbered lists.
- The converter is the guided flow (category → from → to → values) with the units in the prompt.
  Unit rows read `m — metre`; a symbol or the name selects them.

## Deviations from the spec

None in behaviour. Runtime notes: a Standard Calculator line longer than 20 000 characters is rejected
with `INVALID_EXPRESSION` (the program runs on a 256 MB-stack thread, so deep nesting below that limit
is safe).

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)