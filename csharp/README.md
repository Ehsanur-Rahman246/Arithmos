<!-- csharp/README.md -->
# Arithmos — C# edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in C#, .NET base class library only.
Follows [the Release 1 spec](../docs/specifications/release-1.md). Checked against the
JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.
<!-- Only keep this line after `dotnet run --project test` passes on your machine and the hand-test checklist is done. -->

## Prerequisites

- **.NET SDK 8.0 or newer** (`dotnet --version`). Uses C# 11+ (`>>>`).
- No NuGet packages. The first `dotnet run` restores nothing from the network.

## Run

From this folder:

```bash
dotnet run                                       # interactive menu
dotnet run -- std "20% of 150"                   # one calculation        → 30
dotnet run -- prog 0xFF AND 0x0F                 # one programmer command
dotnet run -- convert 100 cm in                  # one conversion         → 39.3700787402
dotnet run -- list length
dotnet publish -c Release -o out                 # optional: build to out/arithmos
```

Quote expressions the shell would interpret: `dotnet run -- prog "-8 >>> 1"`,
`dotnet run -- std "(2 + 3) * 4"`.

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly. One-shot exit status: `0` success, `1` the
line produced an `Error [CODE]`, `2` bad usage. One-shot errors go to stderr; interactive
errors go to stdout.

## Test

```bash
dotnet run --project test -- ../docs/release-1-cases.json
```

| File | What it checks | Count |
|---|---|---|
| `test/RunCases.cs` | The shared cases (loaded from `../docs/release-1-cases.json` with `System.Text.Json`) | 175 shared |
| `test/Extras.cs` | Formatting boundaries, settled amendments, unit-table sanity, garbage input, scripted sessions, one-shot exit codes | extras |
| `test/RunSelector.cs` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |

The runner prints `N passed, M failed` and exits `1` on any failure. It is a plain console
program, so no test framework is needed.

## Layout

```text
csharp/
├── Arithmos.csproj
├── src/
│   ├── Program.cs
│   ├── cli/          App.cs (one-shot, menu), Tools.cs (prompt loops, guided converter),
│   │                 Pick.cs, Selector.cs, KeyParser.cs, ConsoleIo.cs, Terminal.cs, Report.cs
│   ├── calculator/   StandardCalculator.cs: tokenizer → parser (AST) → evaluator
│   ├── programmer/   ProgrammerCalculator.cs: literals, commands, output
│   ├── converter/    UnitConverter.cs (logic) + Units.cs (unit tables as data)
│   └── shared/       ArithmosError.cs, FormatNumber.cs
└── test/             Arithmos.Tests.csproj, Program.cs, Harness.cs, Fakes.cs,
                      RunCases.cs, Extras.cs, RunSelector.cs
```

Engines never read stdin or write stdout. They throw `ArithmosError` (code + message), so they
can be tested directly and reused by a later GUI. Only the `cli` layer turns values into text
and errors into `Error [CODE]: message`.

## How the hard parts are done

**64-bit integers.** C#'s `long` is a native signed two's-complement integer, so `& | ^ ~ <<`,
the arithmetic `>>` and the logical `>>>` (C# 11) act on the 64-bit pattern directly; shifts
never throw. Literals are accumulated digit by digit into a `BigInteger`, so range checks are
exact (`0xFFFFFFFFFFFFFFFF` is `-1`, `0x10000000000000000` is `OUT_OF_RANGE`) and nothing passes
through `double`. `Convert.ToString(long, 2|8|16)` prints a negative value as its unsigned 64-bit
pattern, which is the spec's "full 64-bit pattern" rule.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`double`. `FormatNumber.Format` builds the exact decimal expansion of the double with
`BigInteger` (`mantissa × 5^k` for the fractional part), rounds that digit string to 12
significant digits half away from zero by hand, trims zeros and picks plain or scientific
notation (spec §2.3), so `100000000000.5` gives `100000000001`. .NET's own `ToString("E…")` and
`Math.Round` are not used. Spec §3.4 percent rules: a `%` that is the *direct* right operand of
`+` / `-` is relative; the parser wraps parentheses in a `Group` node, so `200 + (10%)` is plain.

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
- Every drawn line is at most (terminal width − 1) columns and the list window shrinks to fit
  the terminal height. Both are measured on every redraw, so resizing works.
- **Keys.** `Console.ReadKey(true)` reports arrows and Esc directly, and .NET manages (and
  restores) the terminal mode itself, so no `stty` or native calls are needed. `TreatControlCAsInput`
  is switched on only while a selector is on screen and restored in a `finally`; the cursor is
  hidden only while a selector is on screen and shown again in `finally` and on exit.
- **Windows.** Works in Windows Terminal, cmd and the PowerShell console. ANSI escape processing is
  switched on through kernel32 while the program runs and restored on exit; output is UTF-8.
  Git Bash (mintty) is not a console: use `winpty dotnet run`, otherwise the numbered lists are shown.
- The converter is the guided flow (category → from → to → values) with the units in the prompt.
  Unit rows read `m — metre`; a symbol or the name selects them.

## Deviations from the spec

None in behaviour. Runtime note: a Standard Calculator line longer than 20 000 characters is
rejected with `INVALID_EXPRESSION` (evaluation runs on a 64 MB-stack thread, so deep nesting and
long chains below that limit are safe). .NET 8 SDK or newer is required.

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)