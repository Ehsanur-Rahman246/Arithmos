# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/). Versions are
project-wide: each completed language edition bumps the minor version.
Each version is tagged `vX.Y.Z`.

## [Unreleased]

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