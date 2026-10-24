# Arithmos — Bash edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in Bash, with awk for decimal
arithmetic. Follows [the Release 1 spec](../docs/specifications/release-1.md). Checked against the
JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.
<!-- Only keep this line after `make test` passes on your machine and the hand-test checklist is done. -->

## Prerequisites

- **Bash 4.0 or newer** (associative arrays, `${x,,}`, fractional `read -t`). macOS ships Bash 3.2:
  `brew install bash`, then run `bash bin/arithmos` with the new Bash.
- **awk**: gawk, mawk, or another POSIX awk on the `PATH`. Spec §9 says decimals in Bash need `bc`
  or `awk`; this edition uses awk. Set `AR_AWK=gawk` (or `mawk`) to choose one.
- `stty` (coreutils) for the arrow-key selector. Without a terminal, `stty` is never called.
- No packages, no build step. `make` is optional; every command below also works without it.

## Run

From this folder:

```bash
bash bin/arithmos                          # interactive menu (or: make run, or ./bin/arithmos)
bash bin/arithmos std "20% of 150"         # one calculation        → 30
bash bin/arithmos prog 0xFF AND 0x0F       # one programmer command
bash bin/arithmos convert 100 cm in        # one conversion         → 39.3700787402
bash bin/arithmos list length
```

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly. One-shot exit status: `0` success, `1` the line
produced an `Error [CODE]`, `2` bad usage. One-shot errors go to stderr; interactive errors go to
stdout.

## Test

```bash
make test
# or
bash test/run_cases.sh ../docs/release-1-cases.json
bash test/run_selector.sh
bash test/cli_session.sh
```

| Program | What it checks | Count |
|---|---|---|
| `test/run_cases.sh` | The shared cases (loaded from `../docs/release-1-cases.json` with a small awk reader, no `jq`), then Bash extras: formatting boundaries, settled amendments, garbage input | 175 shared + extras |
| `test/run_selector.sh` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |
| `test/cli_session.sh` | Whole sessions piped into the binary, one-shot mode and exit codes | see file |

`make lint` runs `shellcheck` if it is installed.

## Layout

```text
bash/
├── Makefile
├── bin/arithmos            entry point: argv → one-shot or menu
├── src/
│   ├── autoload.sh         plain source list, in dependency order
│   ├── cli/                cli.sh (menu, one-shot), tools.sh (prompt loops, tool bindings),
│   │                       pick.sh, selector.sh, terminal.sh, io.sh, style.sh (the only I/O layer)
│   ├── calculator/         calculator.awk (tokenizer → parser (AST) → evaluator), calculator.sh (session)
│   ├── programmer/         int64.sh (ops, output), parse.sh (literals), programmer.sh (commands)
│   ├── converter/          converter.sh + converter.awk (logic), units.sh (unit tables as data)
│   └── shared/             errors.sh, format_number.awk
└── test/
    ├── run_cases.sh
    ├── run_selector.sh
    └── cli_session.sh
```

Engines never read stdin or write stdout. On failure they record `AR_CODE` and `AR_MSG` and return
1; on success they leave the result in `AR_OUT` and return 0. Only `cli/` turns values into text and
errors into `Error [CODE]: message`.

## How the hard parts are done

**64-bit integers.** Bash arithmetic is a native signed 64-bit integer that wraps on overflow,
which is the spec's model, so `<<`, `>>` (arithmetic), `&`, `|`, `^` and `~` need no emulation.
`>>>` is `(v >> n) & (INT_MAX >> (n-1))`, which clears exactly the `n` sign-extended bits.
`printf '%X' / '%o'` print a negative value as its unsigned 64-bit pattern, which is the spec's
"full 64-bit pattern" rule; binary is built bit by bit. Literals are never given to `$(( ))`
as typed: they are checked as digits first, decimal text is compared with the limits as a string,
and bin/oct/hex accumulate the bit pattern digit by digit after a width check. So there is no
silent wrap-around and no arithmetic injection (`a[$(cmd)]`).

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use awk's IEEE
`double`. `ar_format` (in `src/shared/format_number.awk`) prints the value with `%.34e` (an exact
expansion), rounds the digit string to 12 significant digits half away from zero by hand, trims zeros
and picks plain or scientific notation (spec §2.3). awk's own rounding (half to even on exact ties)
is not used, so `100000000000.5` gives `100000000001`. Spec §3.4 percent rules: a `%` that is the
*direct* right operand of `+` / `-` is relative; the parser wraps parentheses in a `group` node so
`200 + (10%)` is plain. The expression travels to awk in the environment, never as awk source or
`-v`, so no character in it is interpreted as code or as an escape sequence.

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
- **Raw mode.** `stty -icanon -echo -isig` is on only while a selector is on screen. It is restored
  after every selector run and by `EXIT`, `INT`, `TERM` and `HUP` traps, so the terminal is never
  left raw.
- **Keys.** Escape sequences are read byte by byte with a 50 ms wait, so a lone Esc is told apart
  from an arrow key.
- **Windows.** Use WSL or Git Bash. This edition has not been tried on Windows; if `stty` or the
  terminal checks fail, the numbered lists are used.

## Deviations from the spec

None in behaviour. Interface and runtime notes (Bash 4+, awk dependency, `stty`) are listed above.

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)