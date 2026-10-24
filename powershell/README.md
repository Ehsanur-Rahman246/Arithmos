# Arithmos — PowerShell edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in PowerShell, standard
library (.NET) only. Follows [the Release 1 spec](../docs/specifications/release-1.md).
Checked against the JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.
<!-- Only keep this line after `test/run_all.ps1` passes on your machine and the hand-test checklist is done. -->

## Prerequisites

- **PowerShell 7.2 or newer** (`pwsh`), on Windows, Linux or macOS. Windows PowerShell 5.1 is
  not supported: its .NET Framework cannot print a double exactly, which the 12-digit
  formatter relies on.
- No modules, no packages, no build step. Files are UTF-8 (no BOM needed in PowerShell 7).

## Run

From this folder:

```powershell
pwsh bin/arithmos.ps1                          # interactive menu
pwsh bin/arithmos.ps1 std "20% of 150"         # one calculation        → 30
pwsh bin/arithmos.ps1 prog "0xFF AND 0x0F"     # one programmer command
pwsh bin/arithmos.ps1 convert 100 cm in        # one conversion         → 39.3700787402
pwsh bin/arithmos.ps1 list length
```

Quote expressions PowerShell would otherwise interpret (`>` is a redirection, `(` starts a
group): `prog "-8 >>> 1"`, `std "(2 + 3) * 4"`.

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly. One-shot exit status: `0` success, `1` the line
produced an `Error [CODE]`, `2` bad usage. One-shot errors go to stderr; interactive errors go
to stdout.

## Test

```powershell
pwsh test/run_all.ps1
# or
pwsh test/run_cases.ps1 ../docs/release-1-cases.json
pwsh test/run_selector.ps1
```

| Program | What it checks | Count |
|---|---|---|
| `test/run_cases.ps1` | The shared cases (loaded from `../docs/release-1-cases.json`), then PowerShell extras: formatting boundaries, settled amendments, garbage input, scripted sessions, one-shot exit codes | 175 shared + extras |
| `test/run_selector.ps1` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |

## Layout

```text
powershell/
├── bin/arithmos.ps1        entry point
├── src/
│   ├── autoload.ps1        plain dot-source list, in dependency order
│   ├── cli/                io.ps1 (io object, real console), selector.ps1, pick.ps1,
│   │                       tools.ps1 (prompt loops, guided converter, menu), cli.ps1 (one-shot, entry)
│   ├── calculator/         calculator.ps1: tokenizer → parser (AST) → evaluator
│   ├── programmer/         programmer.ps1: literals, commands, output
│   ├── converter/          converter.ps1 (logic) + units.ps1 (unit tables as data)
│   └── shared/             errors.ps1, format-number.ps1
└── test/                   harness.ps1, run_cases.ps1, run_selector.ps1, run_all.ps1
```

Engines never read stdin or write stdout. They throw an exception carrying the error code in
`Exception.Data['ArCode']` (`Throw-Ar`), so they can be tested directly and reused by a later
GUI. Only the `cli` layer turns values into text and errors into `Error [CODE]: message`.
`autoload.ps1` must be dot-sourced from a script, never from inside a function.

## How the hard parts are done

**64-bit integers.** PowerShell's `[long]` is a native signed 64-bit two's-complement integer,
so `-band -bor -bxor -bnot -shl` and the arithmetic `-shr` act on the 64-bit pattern directly.
`>>>` is `(v -shr n) -band ([long]::MaxValue -shr (n-1))`, which clears exactly the `n`
sign-extended bits. Literals are parsed digit by digit into a `BigInteger`, so range checks are
exact (`0xFFFFFFFFFFFFFFFF` is `-1`, `0x10000000000000000` is `OUT_OF_RANGE`) and nothing ever
passes through `[double]`. `[Convert]::ToString(long, 2|8|16)` prints a negative value as its
unsigned 64-bit pattern, which is the spec's "full 64-bit pattern" rule.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`[double]`. `Format-ArNumber` prints the value with `ToString('E34')` (on .NET Core this is the
exact expansion, like `%.34e` in C), rounds that digit string to 12 significant digits half away
from zero by hand, trims zeros and picks plain or scientific notation (spec §2.3), so
`100000000000.5` gives `100000000001`. Spec §3.4 percent rules: a `%` that is the *direct* right
operand of `+` / `-` is relative; the parser wraps parentheses in a `group` node, so
`200 + (10%)` is plain.

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
  terminal height. Both are measured on every redraw, so resizing works.
- **Keys.** `[Console]::ReadKey($true)` reports arrows and Esc directly, so no escape-sequence
  timing is needed. `TreatControlCAsInput` is switched on only while a selector is on screen and
  restored in `finally`; the cursor is hidden only while a selector is on screen and shown again
  in `finally` and on exit.
- **Windows.** Works in Windows Terminal, cmd and the PowerShell 7 console; the console is
  switched to UTF-8 while the program runs and restored on exit. ISE is not a real console
  (key reads fail), so use `pwsh`.
- The converter is the guided flow (category → from → to → values) with the units in the prompt.
  Unit rows read `m — metre`; a symbol or the name selects them.

## Deviations from the spec

None in behaviour. Runtime note: PowerShell 7.2+ is required (see Prerequisites).

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)