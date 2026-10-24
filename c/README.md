# Arithmos — C edition (Release 1)

Release 1 (Standard Calculator, Programmer Calculator, Unit Converter) in C99,
standard library only. Follows [the Release 1 spec](../docs/specifications/release-1.md).

## Prerequisites

- A C99 compiler (gcc, clang) and `make`
- The C math library (`-lm`, linked by the Makefile)
- A `printf` that prints exact decimal expansions of doubles (glibc, musl, UCRT, macOS libc)

## Run

```bash
cd c
make
./arithmos                          # interactive menu
./arithmos std "20% of 150"         # one-shot (exit 0 / 1 on Error / 2 on bad usage)
./arithmos prog 0xFF AND 0x0F
./arithmos convert 100 cm in
./arithmos list length
```

## Test

```bash
make test    # 175 shared cases + extra tests + 21 selector tests + scripted CLI sessions
make asan    # the shared cases and the selector tests under AddressSanitizer + UBSan
```

`make test` runs three things:

| Program | What it checks | Count |
|---|---|---|
| `run_tests` (`test/run_cases.c`) | The shared cases (loaded from `../docs/release-1-cases.json` with a small built-in JSON reader), then the C extras (formatting boundaries, unit-table sanity, garbage input, settled amendments) | 175 shared + 176 extra = 351 |
| `run_selector` (`test/run_selector.c`) | Selector tests SL1–SL21: key handling, drawing, the draw/read loop and `pick()` over a fake keyboard and screen | 21 |
| `test/cli_session.sh` | Whole sessions piped into the binary, plus one-shot mode and exit codes | 27 |

Pass another case file with `make test CASES=path/to/cases.json`. The selector tests are the same 21
behaviours, with the same numbers, as the JavaScript and Python editions
([docs/test-cases.md](../docs/test-cases.md)).

## Layout

```text
c/
├── Makefile
├── src/
│   ├── main.c
│   ├── cli/          cli.c (menus, prompt loops, one-shot mode: the only I/O),
│   │                 select.c (arrow-key selector), pick.c (pick(): one question, many answers)
│   ├── calculator/   tokenizer -> parser (AST) -> evaluator
│   ├── programmer/   64-bit parsing, bases, bitwise ops, shifts
│   ├── converter/    converter.c (logic) + units.c (unit tables as data)
│   └── shared/       error codes, number formatting
└── test/
    ├── run_cases.c     shared cases + extra tests
    ├── run_selector.c  selector tests SL1-SL21
    └── cli_session.sh
```

Engines never read stdin or write stdout. Each returns `0` on success or `-1` with an
`ArError` (`code` + `message`), so they can be tested directly and reused by a later GUI.

## How the hard parts are done

**64-bit integers.** `int64_t` / `uint64_t` from `<stdint.h>`. Bitwise operations and shifts
run on `uint64_t`, so there is no signed overflow or implementation-defined shifting. Results are
converted back with `u2i()`, which does not depend on how the compiler converts out-of-range
unsigned values. `>>` is built from `>>` on a non-negative value (`~((~v) >> n)` for negatives),
`>>>` is a plain unsigned shift.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`double`. `ar_format_number` prints the value with `%.34e` (an exact expansion), rounds that digit
string to 12 significant digits half away from zero, trims zeros and picks plain or scientific
notation (spec 2.3). Binary `printf` rounding (half to even on exact ties) is not used, so
`100000000000.5` gives `100000000001`. Spec §3.4 percent rules: a `%` that is the *direct* right
operand of `+` / `-` is relative; the evaluator carries a flag that grouping, negation and
every other operator clear.

## Interface

- On a real terminal the menus and converter pickers are arrow-key selectors: ↑↓ move,
  Home/End/PgUp/PgDn jump, Enter selects, Esc or `b` goes back, `q` quits, Ctrl-C / Ctrl-D
  ends the input. Any other printable key opens a typed line, so numbers, names, symbols
  and one-line commands (`100 cm in`) still work. Names that start with `b` or `q`
  (`bit`, `byte`, `bar`, `btu`, `qt`) must be picked with the arrows or a number, because `b`
  and `q` act at once. The selector layers are the same as in the other editions: pure key
  handling and drawing, a loop over an injectable keyboard and screen, and `pick()` over an
  injectable `PickIo`.
- Pipes, files, tests, dumb terminals and `ARITHMOS_PLAIN=1` get numbered lists (`  1) length`).
  Typed words: a number, a name or symbol, a one-line command, `help` / `?`, `quit`, and `back`
  where a screen can go back.
- `NO_COLOR=1` removes the colours (the `❯` pointer stays).
- Esc works in the selectors only; the prompts (`standard>`, `converter (m → yd)>`) read whole
  lines, so use `back` there.
- Windows: the console is switched to UTF-8 while the program runs and restored on exit.
- Converter is the guided flow (category → from → to → values) with the units in the prompt.
- One-shot errors go to stderr; interactive errors go to stdout.

## Deviations

None. All 175 shared cases pass, including under ASan/UBSan.

## Documentation links

- [Release 1 spec](../docs/specifications/release-1.md)
- [Shared test cases](../docs/test-cases.md)
- [Error message wording](../docs/error-messages.md)
- [Architecture](../ARCHITECTURE.md)
- [Spec amendments](../docs/spec-amendments.md)
