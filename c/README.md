# Arithmos — C edition

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
make test    # 175 shared cases + extra tests + scripted CLI sessions
make asan    # the same cases under AddressSanitizer + UBSan
```

`make test` runs `test/run_cases.c` (loads `../docs/release-1-cases.json` with a small built-in
JSON reader, then runs the extra tests) and `test/cli_session.sh` (whole sessions piped into the binary).
Pass another file with `make test CASES=path/to/cases.json`.

## Layout

```text
c/
├── Makefile
├── src/
│   ├── main.c
│   ├── cli/          select.c, select.h, menus, prompt loops, one-shot mode (the only I/O)
│   ├── calculator/   tokenizer -> parser (AST) -> evaluator
│   ├── programmer/   64-bit parsing, bases, bitwise ops, shifts
│   ├── converter/    converter.c (logic) + units.c (unit tables as data)
│   └── shared/       error codes, number formatting
└── test/
    ├── run_cases.c   shared cases + extra tests
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
  Home/End/PgUp/PgDn jump, Enter selects, Esc goes back, Ctrl-C / Ctrl-D exits. Typing any
  printable key switches to a typed line, so numbers, names, symbols and one-line commands
  (`100 cm in`) still work.
- Pipes, files, tests, dumb terminals and `ARITHMOS_PLAIN=1` get numbered lists.
- `NO_COLOR=1` removes the highlight colour (the `>` marker stays).
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
