# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/). Versions are
project-wide: each completed language edition bumps the minor version.
Each version is tagged `vX.Y.Z`.

## [Unreleased]

## [0.14.0] — 2026-10-26

### Added
- Rust edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases, plus Rust extras. Programmer Calculator on native `i64`/`u64`
  with saturating `u128` literal parsing; 12-digit formatting from the exact `{:.60e}` expansion.
- Rust: arrow-key selector for the menus and pickers (POSIX `stty` on `/dev/tty`, Windows
  `_getwch` + console mode through hand-declared `extern`), typed fallback, `ARITHMOS_PLAIN=1`,
  `NO_COLOR=1`.
- Selector tests SL1–SL21 for Rust (21), plus X2 and X3 (23 in total).

## [0.13.0] — 2026-10-26

### Added
- C# edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases, plus C# extras. Programmer Calculator on native `long` with
  `BigInteger` literal parsing and the built-in `>>>`; 12-digit formatting from the exact
  `BigInteger` expansion of the double.
- C#: arrow-key selector for the menus and pickers (`Console.ReadKey`, Ctrl-C read as a key only
  while a selector is on screen, ANSI escapes enabled on Windows), typed fallback,
  `ARITHMOS_PLAIN=1`, `NO_COLOR=1`.
- Selector tests SL1–SL21 for C# (21), plus X2 and X3 (23 in total).

## [0.12.0] — 2026-10-26

### Added
- Go edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases, plus Go extras. Programmer Calculator on native `int64`/`uint64`
  with `math/big` literal parsing; 12-digit formatting from the exact `big.Float` expansion.
- Go: arrow-key selector for the menus and pickers (POSIX `stty` + `syscall.Read`, Windows
  `_getwch` + console mode through `syscall.NewLazyDLL`), typed fallback, `ARITHMOS_PLAIN=1`,
  `NO_COLOR=1`.
- Selector tests SL1–SL21 for Go (21), plus X2 and X3 (23 in total).

## [0.11.0] — 2026-10-26

### Added
- TypeScript edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases, plus TypeScript extras. Programmer Calculator on `BigInt` with
  `asIntN(64, …)`; 12-digit formatting with `toExponential(11)`.
- TypeScript: arrow-key selector for the menus and pickers (raw stdin bytes parsed by `parseKeys`,
  raw mode only while a key is read), typed fallback, `ARITHMOS_PLAIN=1`, `NO_COLOR=1`.
- Selector tests SL1–SL21 for TypeScript (21), plus X2 and X3 (23 in total).

## [0.10.0] — 2026-10-26

### Added
- Dart edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases, plus Dart extras. Programmer Calculator on native `int`
  (64-bit on the Dart VM) with `BigInt` literal parsing; 12-digit formatting from the
  exact `BigInt` expansion of the double.
- Dart: arrow-key selector for the menus and pickers (POSIX `stty` + libc `read` through
  `dart:ffi`, Windows `_getwch` + console mode through `dart:ffi`), typed fallback,
  `ARITHMOS_PLAIN=1`, `NO_COLOR=1`.
- Selector tests SL1–SL21 for Dart (21), plus X2 and X3 (23 in total).

## [0.9.0] — 2026-10-25

### Added
- PowerShell edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases, plus PowerShell extras. Programmer Calculator on native `[long]`
  with `BigInteger` literal parsing; 12-digit formatting from the exact `ToString('E34')` expansion.
- PowerShell: arrow-key selector for the menus and pickers (`[Console]::ReadKey`, Ctrl-C read as a
  key only while a selector is on screen), typed fallback, `ARITHMOS_PLAIN=1`, `NO_COLOR=1`.
- Selector tests SL1–SL21 for PowerShell (21), plus X2 and X3 (23 in total).

## [0.8.0] — 2026-10-24

### Added
- Bash edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases, plus Bash extras. Pure-Bash Programmer Calculator on native
  64-bit arithmetic; awk for Standard Calculator and Converter (documented dependency).
- Bash: arrow-key selector for the menus and pickers (`stty`, raw mode only while a selector
  is on screen, restored by traps), typed fallback, `ARITHMOS_PLAIN=1`, `NO_COLOR=1`.
- Selector tests SL1–SL21 for Bash (21), plus X2 and X3 (23 in total).

### Fixed
- README: removed a stray "Layout: add php/ PHP edition" line from the quick start.
- docs/roadmap.md: "PH" is now "PHP" in the progress table.

## [0.7.0] — 2026-10-24

### Added
- Java edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases, plus 126 Java extras.
- Java: arrow-key selector for the menus and pickers (POSIX `stty`, Windows foreign-function
  console calls), typed fallback, `ARITHMOS_PLAIN=1`, `NO_COLOR=1`.
- Selector tests SL1–SL21 for Java (21), plus X2 and X3 (23 in total).

## [0.6.0] — 2026-10-24

### Added
- PHP edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases.
- PHP: arrow-key selector for the menus and pickers (POSIX `stty`, Windows PowerShell key
  reads), typed fallback, `ARITHMOS_PLAIN=1`, `NO_COLOR=1`.
- Selector tests SL1–SL21 for PHP (21), plus X2 (also in C++) and X3 (key-byte parsing, PHP only).

## [0.5.0] — 2026-10-23

### Added
- C++ edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases, also under AddressSanitizer and UBSan.
- C++: arrow-key selector for the menus and pickers (POSIX termios, Windows `_getch` with
  ANSI escape processing), typed fallback, `ARITHMOS_PLAIN=1`, `NO_COLOR=1`.
- Selector tests SL1–SL21 for C++ (21).

### Changed
- Spec §2.1, §9, §11, ARCHITECTURE.md, docs/test-cases.md, docs/development-workflow.md and
  docs/language-support.md: the arrow-key selector is now required on a real terminal in every
  edition that can run an interactive terminal program (amendment R34).

## [0.4.2] — 2026-10-22

### Fixed
- C: hex-mode `0B`/`0D` literals, space-less shifts (`1<<3`), silent `base`, tokenizer wording and
  UTF-8 error output, one-shot mode (case-insensitive command word, `standard`/`programmer`, stdout),
  tool intros, help text, converter values header, prompts, EOF newline, unit display names:
  C now matches JavaScript and Python byte for byte.
- Python: `ARITHMOS_PLAIN=1` is honoured.

### Changed
- Spec amendments R29–R33.
- JavaScript, Python: one-shot errors and usage-after-bad-input now go to stderr (as C already did).
- JavaScript, Python, C: unit display names follow the spec exactly.

## [0.4.1] — 2026-10-21

### Added
- C: arrow-key selector for the menus and pickers (POSIX termios, Windows `_getch`).
- Selector tests SL1–SL21 in all three editions (JavaScript 22 with X1, Python 21, C 21),
  documented in docs/test-cases.md.

### Changed
- JavaScript, Python: at an arrow-key selector, any printable key other than `b` and `q` now opens a typed
  line (number, name, symbol or one-line command), as in C. Esc / `b` and `q` stay direct.
- C: the menus and pickers now go through `pick()` like the other editions. Screen titles and the plain
  list format match them (R28). Typed `b` / `q` lines are no longer accepted (use `back` / `quit`, or the
  keys at a selector), as in JavaScript and Python. The main-menu hint no longer offers back.

## [0.4.0] — 2026-10-20

### Added
- C edition of Release 1 (Standard Calculator, Programmer Calculator, Unit Converter).
  Passes all 175 shared cases, also under AddressSanitizer and UBSan.
- C: arrow-key selector for the menus and pickers (POSIX termios, Windows `_getch`),
  typed fallback, `ARITHMOS_PLAIN=1`.

## [0.3.3] — 2026-10-20

### Added
- `scripts/build-error-messages.py` generates `docs/error-messages.md` (code, situation, wording) from the JavaScript and Python engines. `--check` fails if the file is stale or the editions disagree; `--verify` runs both engines against the table.

### Changed
- JavaScript: the evaluator's NaN safety net now says `The result is not a number`, matching Python and amendment R26.

## [0.3.2] — 2026-10-19

### Added
- Shared cases P29–P32 and C110 (175 cases): optional `convert` word, hex-mode keyword words, `convert 1 ly pm`.
- `scripts/build-cases.py` now asserts the case counts, unique ids and one outcome per case.

### Changed
- JavaScript, Python: the converter's values prompt shows the units: `converter (m → yd)>`.
- Spec §2.1, §4.5 and §5.1 amended (R22–R25); deviations D1–D3 removed.

### Fixed
- JavaScript, Python: `list` typed at the converter's values prompt failed with INVALID_NUMBER.
- `.gitignore` no longer excludes `javascript/bin/`.
- Renamed `docs/development-wrokflow.md` to `docs/development-workflow.md`; all links resolve.

## [0.3.1] — 2026-10-18

### Fixed
- JavaScript: the interactive menus could freeze on Windows (cmd, Node 24) after
  repeated Esc/back navigation, leaving the terminal unresponsive to every key,
  Ctrl+C included. The terminal is now read by one persistent key reader for the
  whole session instead of switching raw mode and opening a new `readline`
  interface on every screen.
- JavaScript: Esc presses closer than 500 ms apart were merged into a single
  "back". Esc is now reported after 50 ms, so each press goes back one screen.

### Changed
- JavaScript: Esc now goes back in the converter's values prompt, as the
  other screens already did.
- JavaScript: the line editor in interactive mode supports typing, Backspace and
  Enter only (no cursor movement or history).

### Added
- JavaScript: `ARITHMOS_PLAIN=1` forces numbered-list mode on a real terminal.

## [0.3.0] — 2026-10-18

### Added
- Python edition of Release 1 (Standard Calculator, Programmer Calculator, Unit
  Converter). Passes all 170 shared cases (S1–S33, P1–P28, C1–C109).

## [0.2.0] — 2026-10-17

### Added
- JavaScript edition of Release 1 (reference implementation). Passes all 170 shared
  cases.
- Shared test-case file `docs/release-1-cases.json` and its generator
  `scripts/build-cases.py`.
- Interactive arrow-key menus on a real terminal, numbered lists when piped.
- One-shot mode (`std`, `prog`, `convert`, `list`) with exit codes 0 / 1 / 2.

## [0.1.0] — 2026-10-16

### Added
- Project start: repository created.