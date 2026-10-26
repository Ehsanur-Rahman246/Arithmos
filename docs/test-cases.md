# Shared Test Cases

All editions run the same data file, [release-1-cases.json](release-1-cases.json):
175 cases (S1–S33 standard, P1–P32 programmer, C1–C110 converter).

**The spec is the source of truth.** The JSON is generated from the Section 8 tables
of [release-1.md](specifications/release-1.md):

```bash
python scripts/build-cases.py docs/specifications/release-1.md docs/release-1-cases.json
```

To change a case, edit the spec table and regenerate. Never hand-edit the JSON.
The script asserts 33 / 32 / 110 cases, unique ids, and exactly one outcome per case.

## Case format

```json
{ "id": "S1",  "tool": "standard",   "input": "25 + 17", "expected": "42" }
{ "id": "S3",  "tool": "standard",   "input": "10 / 0",  "error": "DIV_BY_ZERO" }
{ "id": "P9",  "tool": "programmer", "input": "NOT 5",
  "expected": { "DEC": "-6", "HEX": "FFFFFFFFFFFFFFFA" } }
{ "id": "P19", "tool": "programmer", "input": "-FF", "setup": ["base hex"],
  "expected": { "DEC": "-255" } }
{ "id": "C105", "tool": "converter",  "input": "convert 1 km all",
  "expectedContains": ["m: 1000", "mi: 0.621371192237"] }
{ "id": "S33", "tool": "standard", "steps": [
  { "input": "7", "expected": "7" },
  { "input": "10 / 0", "error": "DIV_BY_ZERO" },
  { "input": "ans", "expected": "7" } ] }
```

| Field | Meaning |
|---|---|
| `id`, `tool` | Case id and `standard`, `programmer` or `converter` |
| `input` | The line typed at the prompt (absent when `steps` is used) |
| `setup` | Lines run first in the same session (P19) |
| `steps` | Multi-line session cases (S32, S33); each step has its own outcome |
| `expected` | A **string**, or an **object** of `HEX`/`DEC`/`OCT`/`BIN` for programmer cases |
| `expectedContains` | Lines that must all appear in the output (C105, C106) |
| `error` | Expected error code. Only the code is asserted, never the message |

Exactly one of `expected`, `expectedContains`, `error` is present per case or step.

## Loader contract

1. Branch on whether `expected` is a string or an object.
2. Run `setup` lines first, then `input`, or run `steps` in order in one session.
3. Assert results and codes, not prompt text or terminal formatting.
4. Do not skip or mark any shared case as todo.

## Running

| Edition | Command (from its folder) |
|---|---|
| JavaScript | `npm test` |
| Python | `python -m unittest discover -s tests -t .` |
| C | `make test` (from `c/`; `make` needs w64devkit/MinGW on Windows, see c/README.md) |
| C++ | `make test` from `cpp/`, or the g++ commands in cpp/README.md |
| PHP | `make test` from `php/`, or `php test/run_cases.php ../docs/release-1-cases.json` and `php test/run_selector.php` |
| Java | `make test` from `java/`, or the `javac` / `java` commands in java/README.md |
| Bash | `make test` from `bash/`, or `bash test/run_cases.sh ../docs/release-1-cases.json` and `bash test/run_selector.sh` |
| PowerShell | `pwsh test/run_all.ps1` from `powershell/`, or `pwsh test/run_cases.ps1 ../docs/release-1-cases.json` and `pwsh test/run_selector.ps1` |
| Dart | `dart run test/run_cases.dart ../docs/release-1-cases.json` and `dart run test/run_selector.dart` from `dart/` |
| TypeScript | `npm test` from `typescript/` (builds, then runs `dist/test/*.test.js`) |
| Go | `go test ./...` from `go/` |
| C# | `dotnet run --project test -- ../docs/release-1-cases.json` from `csharp/` |
| Rust | `cargo test` from `rust/` |

## Adding a case

1. Add it to the spec's Section 8 table with the next id.
2. Regenerate the JSON.
3. Run every completed edition. Every bug found in any language becomes a shared case.
4. Selector tests are separate: see "Selector tests (SL1–SL21)".

Editions also keep their own non-shared tests (formatting boundaries, selector,
scripted CLI sessions). Those never replace shared cases.

## Selector tests (SL1–SL21)

The arrow-key selector is required on a real terminal (spec §2.1), so every edition runs the same
21 numbered tests with the same numbers. They are not shared data cases: each edition keeps them in
its own test folder and asserts behaviour only (never terminal formatting beyond the strings below).

| # | Behaviour |
|---|---|
| SL1 | up/down move, wrap around, home/end |
| SL2 | long lists scroll in a window of 10 |
| SL3 | Enter selects; Esc / b / q only work when offered |
| SL4 | Ctrl-C / Ctrl-D abort; other control keys are ignored |
| SL5 | typing on: a printable key ends the selector and carries the character |
| SL6 | typing off: printable keys are ignored |
| SL7 | typing on: Esc, b, q, arrows and Enter keep their meaning |
| SL8 | typing on: space and control keys do not start a typed line |
| SL9 | the selected row is highlighted as a full bar |
| SL10 | plain mode still marks the selected row with the pointer |
| SL11 | hint line lists only the keys on offer |
| SL12 | hint shows Esc/b back and or type when typing is on |
| SL13 | loop: keys in, index out, summary left behind, cursor restored |
| SL14 | loop: Esc, ignored keys, Ctrl-C |
| SL15 | loop: a typed key returns its character and restores the cursor |
| SL16 | pick() uses the selector when present and maps its results |
| SL17 | pick(): a typed name or number selects it |
| SL18 | pick(): a typed one-line command runs and the list comes back |
| SL19 | pick(): an unknown typed word is an error and the list comes back |
| SL20 | pick(): b, q and Esc act at once, with no prompt line |
| SL21 | pick(): without a selector (pipes) the numbered list works as before |
| X2 | lines never wider than the terminal; the window shrinks on a short terminal; erase moves up by the drawn line count | C++ (`test/run_selector.cpp`), PHP (`test/run_selector.php`), Java (`test/arithmos/RunSelector.java`), Bash (`test/run_selector.sh`), PowerShell (`test/run_selector.ps1`), Dart (`test/run_selector.dart`), TypeScript (`test/select.test.ts`), Go (`test/selector_test.go`), C# (`test/RunSelector.cs`), Rust (`tests/selector.rs`) |
| X3 | raw terminal bytes become keys (arrows, Esc, Home/End, PgUp/PgDn, Ctrl-C/D, UTF-8) | PHP (`test/run_selector.php`), Java (`test/arithmos/RunSelector.java`), Bash (`test/run_selector.sh`), PowerShell (`test/run_selector.ps1`, input is ConsoleKeyInfo instead of bytes), Dart (`test/run_selector.dart`, input is bytes), TypeScript (`test/select.test.ts`), Go (`test/selector_test.go`), , C# (`test/RunSelector.cs`, input is ConsoleKeyInfo, as in PowerShell.), Rust (`tests/selector.rs`) |


| Edition | File | Tests |
|---|---|---|
| JavaScript | `test/select.test.js` | SL1–SL21 + X1 (key queue, JavaScript only) = 22 |
| Python | `tests/test_select.py` | SL1–SL21 = 21 |
| C | `test/run_selector.c` | SL1–SL21 = 21 |
| C++ | `test/run_selector.cpp` | SL1–SL21 = 21 + X2 |
| PHP | test/run_selector.php | SL1–SL21 + X2 + X3 = 23 |
| Java | `test/arithmos/RunSelector.java` | SL1–SL21 + X2 + X3 = 23 |
| Bash | `test/run_selector.sh` | SL1–SL21 + X2 + X3 = 23 |
| PowerShell | `test/run_selector.ps1` | SL1–SL21 + X2 + X3 = 23 |
| Dart | `test/run_selector.dart` | SL1–SL21 + X2 + X3 = 23 |
| TypeScript | `test/select.test.ts` | SL1–SL21 + X2 + X3 = 23 |
| Go | `test/selector_test.go` | SL1–SL21 + X2 + X3 = 23 |
| C# | `test/RunSelector.cs` | SL1–SL21 + X2 + X3 = 23 |
| Rust | `tests/selector.rs` | SL1–SL21 + X2 + X3 = 23 |

Rules: every new edition must add all 21 under these numbers (unless it is exempt under release-1.md §9) (the C runner fails if
the count is not 21). Behaviour that exists in only one edition gets an `X<n>` id and is listed here,
never a number inside SL1–SL21.