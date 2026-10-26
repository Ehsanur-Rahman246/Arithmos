# Arithmos — Rust edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in Rust, standard library
only (no crates). Follows [the Release 1 spec](../docs/specifications/release-1.md). Checked
against the JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.
<!-- Only keep this line after `cargo test` passes on your machine and the hand-test checklist is done. -->

## Prerequisites

- **Rust 1.75 or newer** (`rustc --version`), stable toolchain. Cargo only; `Cargo.lock` has no entries.
- POSIX: `stty` (coreutils) for the arrow-key selector. Windows: a real console (cmd,
  PowerShell, Windows Terminal).

## Run

From this folder:

```bash
cargo run --release                              # interactive menu
cargo run --release -- std "20% of 150"          # one calculation        → 30
cargo run --release -- prog 0xFF AND 0x0F        # one programmer command
cargo run --release -- convert 100 cm in         # one conversion         → 39.3700787402
cargo run --release -- list length
cargo build --release                            # optional: target/release/arithmos
```

Quote expressions the shell would interpret: `-- prog "-8 >>> 1"`, `-- std "(2 + 3) * 4"`.

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly. One-shot exit status: `0` success, `1` the
line produced an `Error [CODE]`, `2` bad usage. One-shot errors go to stderr; interactive
errors go to stdout.

## Test

```bash
cargo test
```

| File | What it checks | Count |
|---|---|---|
| `tests/cases.rs` | The shared cases (loaded from `../docs/release-1-cases.json`; `CASES=path` overrides) | 175 shared |
| `tests/extras.rs` | Formatting boundaries, settled amendments, garbage input, one-shot exit codes | extras |
| `tests/selector.rs` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |

## Layout

```text
rust/
├── Cargo.toml
├── src/
│   ├── main.rs, lib.rs
│   ├── cli/          mod.rs, io.rs (Io trait, ConsoleIo), selector.rs, keys.rs, pick.rs,
│   │                 terminal.rs (stty / kernel32), tools.rs (menus, prompt loops, guided converter),
│   │                 oneshot.rs  (the only I/O layer)
│   ├── calculator/   mod.rs: tokenizer → parser (AST) → evaluator
│   ├── programmer/   mod.rs: literals, commands, output
│   ├── converter/    mod.rs (logic) + units.rs (unit tables as data)
│   └── shared/       errors.rs, format_number.rs
└── tests/            cases.rs, extras.rs, selector.rs
```

Engines never read stdin or write stdout. They return `Err(ArithmosError)` (code + message),
so they can be tested directly and reused by a later GUI. Only the `cli` module turns values
into text and errors into `Error [CODE]: message`. A panic inside an engine is caught by the
prompt loop and printed as `Error [INTERNAL]`.

## How the hard parts are done

**64-bit integers.** Rust's `i64` is a native two's-complement integer. `& | ^ !` and the
arithmetic `>>` act on it directly; `<<` and `>>>` run on `u64` (`>>>` is a plain unsigned
shift), so shifts never overflow-panic. Literals are accumulated digit by digit into a
saturating `u128`, so range checks are exact (`0xFFFFFFFFFFFFFFFF` is `-1`,
`0x10000000000000000` is `OUT_OF_RANGE`) and nothing passes through `f64`.
`{:X}`, `{:o}`, `{:b}` on `v as u64` print a negative value as its unsigned 64-bit pattern,
which is the spec's "full 64-bit pattern" rule.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`f64`. `format_number` prints the value with `format!("{:.60e}", x)` (Rust's exact,
correctly rounded expansion), rounds that digit string to 12 significant digits half away
from zero by hand, trims zeros and picks plain or scientific notation (spec §2.3), so
`100000000000.5` gives `100000000001`. Rust's shorter float formatting is not used. Spec §3.4
percent rules: a `%` that is the *direct* right operand of `+` / `-` is relative; the parser
wraps parentheses in a `Group` node, so `200 + (10%)` is plain.

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
  the terminal height. Both are measured on every redraw (cached for 150 ms), so resizing works.
- **Raw mode (POSIX).** Rust's standard library has no raw-mode API, so the selector calls `stty`
  on `/dev/tty` (`-icanon -echo -isig min 0 time 1`) and reads keys from `/dev/tty` directly.
  Raw mode is on only while a selector is on screen. It is restored in `leave()`, in `Drop`, and
  after SIGTERM/SIGHUP (handlers installed only while a selector is on screen set a flag that the
  0.1 s read timeout notices), so the terminal is never left raw. A lone Esc is told from an
  arrow key because an arrow arrives as one chunk.
- **Windows.** Keys come from `_getwch` and the console mode from kernel32, both declared by hand
  with `extern`; ANSI escapes and UTF-8 are switched on while the program runs and restored on
  exit. The selector needs a real console (cmd, PowerShell, Windows Terminal). Git Bash (mintty)
  is not a console, so it shows numbered lists; run `winpty cargo run` to get the selector there.
- The converter is the guided flow (category → from → to → values) with the units in the prompt.
  Unit rows read `m — metre`; a symbol or the name selects them.

## Deviations from the spec

None in behaviour. Runtime notes: a Standard Calculator line longer than 20 000 characters is
rejected with `INVALID_EXPRESSION` (the program runs on a 256 MB-stack thread, so deep nesting
below that limit is safe). Only Unix and Windows targets are supported by the selector code.

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)