# Architecture

Every Arithmos edition follows the same layered design. Module names differ by
language convention, but the layers, the dependency rule and the error model are the
same. JavaScript is the reference edition.

## Goals

1. **Behaviour contract first.** Code mirrors the spec section by section.
2. **Logic separate from I/O.** Engines never read stdin or write stdout, so they can
   be tested directly and reused by the GUI editions (Release 5).
3. **One place per rule.** Error codes, number formatting and unit data each live in
   exactly one module.
4. **No dependencies.** Standard library only.

## Layers

```text
 entry point               argv → main
        │
 ┌──────▼───────────────────────────────────────────┐
 │ cli      menus, prompt loop, tool bindings       │  ← only layer that does I/O
 └──────┬───────────────┬───────────────┬───────────┘
 ┌──────▼─────┐  ┌──────▼──────┐  ┌─────▼──────┐
 │ calculator │  │ programmer  │  │ converter  │      pure logic
 └──────┬─────┘  └──────┬──────┘  └─────┬──────┘
        └───────────────┼───────────────┘
                 ┌──────▼──────┐
                 │   shared    │   error codes, number formatting
                 └─────────────┘
```

Arrows point down only. `shared` imports nothing from the other layers, and engines
never import from `cli`.

## Module map

| Layer | JavaScript (`javascript/src/`) | Python (`python/arithmos/`) | C (`c/src/`) | C++ (`cpp/src/`) | PHP (`php/src/`) | Java (`java/src/arithmos/`) | Bash (`bash/src/`) | PowerShell (`powershell/src/`) | Dart (`dart/lib/src/`) | TypeScript (`typescript/src/`) | Go (`go/`) | C# (`csharp/src/`) | Rust (`rust/src`) | Kotlin (`kotlin/src/main/kotlin/`) | Swift (`swift/Sources/`) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Entry point | `../bin/arithmos.js`, `cli/index.js` | `__main__.py`, `cli/app.py` | `main.c` | `main.cpp`, `cli/cli.cpp` | `../bin/arithmos.php`, `cli/cli.php` | `Main.java, cli/Cli.java` | `../bin/arithmos`, `cli/cli.sh` | `../bin/arithmos.ps1, cli/cli.ps1` | `../bin/arithmos.dart`, `cli/cli.dart` | `../bin/arithmos.js`, `main.ts`, `cli/cli.ts` | `cmd/arithmos/main.go`, `internal/cli/cli.go` | `Program.cs, cli/App.cs` | `main.rs, cli/oneshot.rs` | `Main.kt`, `cli/OneShot.kt` | `arithmos/main.swift`, `ArithmosKit/Entry.swift`, `ArithmosKit/Cli/OneShot.swift` |
| Menu | `cli/menu.js` | `cli/menu.py` | `cli/cli.c` | `cli/cli.cpp` | `cli/cli.php` | `cli/Cli.java` | `cli/cli.sh` | `cli/tools.ps1` | `cli/tools.dart` (`runMenu`) | `cli/cli.ts` (`runInteractive`) | `internal/cli/tools.go` (`RunInteractive`) | `cli/App.cs` (`RunInteractive`) | `cli/tools.rs` (`run_interactive`) | `cli/Tools.kt` (`runInteractive`) | `ArithmosKit/Cli/Tools.swift` (`runInteractive`) |
| Prompt loop | `cli/repl.js` | `cli/repl.py` | `cli/cli.c` | `cli/cli.cpp` | `cli/tools.php` (`Repl`) | `cli/Tools.java (loop)` | `cli/tools.sh` (`tool_loop`) | `cli/tools.ps1` | `cli/tools.dart` (`toolLoop`) | `cli/tools.ts` (`promptLoop`) | `internal/cli/tools.go` (`promptLoop`) | `cli/Tools.cs` (`promptLoop`) | `cli/tools.rs` (`prompt_loop`) | `cli/Tools.kt` (`promptLoop`) | `ArithmosKit/Cli/Tools.swift` (`promptLoop`) |
| Arrow-key selector | `cli/select.js`, `cli/pick.js` | `cli/selector.py`, `cli/pick.py` | `cli/select.c`, `select.h`,  `cli/pick.c`, `pick.h` | `cli/selector.{hpp,cpp}`, `cli/pick.{hpp,cpp}` | `cli/selector.php`, `cli/pick.php` | `cli/Selector.java, cli/KeyParser.java, cli/Pick.java` | `cli/selector.sh`, `cli/terminal.sh`, `cli/pick.sh` | `cli/selector.ps1, cli/pick.ps1` | `cli/selector.dart`, `cli/keys.dart`, `cli/pick.dart` | `cli/selector.ts`, `cli/keys.ts`, `cli/pick.ts` | `internal/cli/selector.go`, `internal/cli/keys.go`, `internal/cli/pick.go` | `cli/Selector.cs, cli/KeyParser.cs, cli/Pick.cs` | `cli/selector.rs`, `cli/keys.rs`, `cli/pick.rs` | `cli/Selector.kt`, `cli/Keys.kt`, `cli/Pick.kt` | `ArithmosKit/Cli/Selector.swift`, `ArithmosKit/Cli/Keys.swift`, `ArithmosKit/Cli/Pick.swift` |
| Terminal I/O, colours | `cli/io.js`, `cli/style.js` | `cli/console.py`, `cli/style.py` | `cli/cli.c + select.c` (no colour module) | `cli/terminal.{hpp,cpp}` (colour via `SelIo.color`) | `cli/terminal.php`, `cli/io.php` | `cli/Terminal.java, cli/ConsoleIo.java, cli/Style.java` | `cli/terminal.sh`, `cli/io.sh`, `cli/style.sh` | `cli/io.ps1` | `cli/terminal.dart`, `cli/io.dart` (colour via `Screen.color`) | `cli/io.ts`, `cli/style.ts` | `internal/cli/io.go`, `internal/cli/term_unix.go`, `internal/cli/term_windows.go` (colour via `Screen.Color`) | `cli/ConsoleIo.cs, cli/Terminal.cs, cli/Report.cs` (colour via `IScreen.Color`) | `cli/terminal.rs`, `cli/io.rs` | `cli/Terminal.kt`, `cli/Io.kt` (colour via `Screen.color`) | `ArithmosKit/Cli/TerminalPosix.swift`, `ArithmosKit/Cli/TerminalWindows.swift`, `ArithmosKit/Cli/Io.swift`, `ArithmosKit/Cli/Style.swift` (colour via `Screen.color`) |
| Tool bindings | `cli/tools/{standard,programmer,converter}.js` | `cli/tools/{standard,programmer,converter}.py` | `cli/cli.c` | `cli/cli.cpp` | `cli/cli.php` | `cli/Tools.java` | `cli/tools.sh` | `cli/tools.ps1` | `cli/tools.dart` | `cli/tools.ts` | `internal/cli/tools.go` | `cli/Tools.cs` | `cli/tools.rs` (`run_interactive`) | `cli/Tools.kt` | `ArithmosKit/Cli/Tools.swift` |
| Standard Calculator | `calculator/{tokenizer,parser,evaluator,index}.js` | `calculator/{tokenizer,parser,evaluator,__init__}.py` | `calculator/calculator.c` | `calculator/calculator.{hpp,cpp}` | `calculator/{tokenizer,parser,evaluator,calculator}.php` | `calculator/{Tokenizer,Node,Parser,Evaluator,Calculator}.java` | `calculator/calculator.{awk,sh}` | `calculator/calculator.ps1` | `calculator/calculator.dart` | `calculator/{tokenizer,parser,evaluator,index}.ts` | `internal/calculator/calculator.go` | `calculator/StandardCalculator.cs` | `calculator/mod.rs` | `calculator/Calculator.kt` | `ArithmosKit/Calculator/Calculator.swift` |
| Programmer Calculator | `programmer/{int64,parse,operations,format,index}.js` | `programmer/{int64,parse,operations,format,__init__}.py` | `programmer/programmer.c` | `programmer/programmer.{hpp,cpp}` | `programmer/{int64,parse,programmer}.php` | `programmer/{Base,Literal,Programmer}.java` | `programmer/{int64,parse,programmer}.sh` | `programmer/programmer.ps1` | `programmer/programmer.dart` | `programmer/{int64,parse,index}.ts` | `internal/programmer/programmer.go` | `programmer/ProgrammerCalculator.cs` | `programmer/mod.rs` | `programmer/Programmer.kt` | `ArithmosKit/Programmer/Programmer.swift` |
| Unit Converter | `converter/{units,convert,temperature,session,index}.js` | `converter/{units,convert,temperature,session,__init__}.py` | `converter/converter.c, units.c` | `converter/{converter.hpp,units.cpp,converter.cpp}` | `converter/{units,converter}.php` | `converter/{Units,Converter}.java` | `converter/{units.sh,converter.awk,converter.sh}` | `converter/{units,converter}.ps1` | `converter/{units,converter}.dart` | `converter/{units,index}.ts` | `internal/converter/{units,converter}.go` | `converter/{Units,ArithmosConverter}.cs` | `converter/{units,mod}.rs` | `converter/{Units,Converter}.kt` | `ArithmosKit/Converter/{Units,Converter}.swift` |
| Shared | `shared/{errors,format-number,index}.js` | `shared/{errors,format_number,__init__}.py` | `shared/shared.c` | `shared/{errors.hpp,text.hpp,format_number.hpp,format_number.cpp}` | `shared/{errors,format_number}.php` | `shared/{ArithmosError,FormatNumber}.java` | `shared/{errors.sh,format_number.awk}` | `shared/{errors,format-number}.ps1` | `shared/{errors,format_number}.dart` | `shared/{errors,format-number}.ts` | `internal/shared/{errors,format}.go` | `shared/{ArithmosError,FormatNumber}.cs` | `shared/{errors,format_number}.rs` | `shared/{Errors,FormatNumber}.kt` | `ArithmosKit/Shared/{Errors,FormatNumber}.swift` |

## Data flow

```text
user line ─► prompt loop ─► tool handler ─► engine (pure) ─► result value
                                                │
                                      raises ArithmosError(code)
                                                │
user sees ◄─ prompt loop prints `Error [CODE]: message` ┘
```

- Engines return values and raise `ArithmosError` carrying a `code`.
- Only the CLI layer turns values into text and errors into `Error [CODE]: message`.
- The prompt loop also catches unexpected exceptions, so invalid input never crashes
  the program (Release 1 goal 4).
- Error codes are the 14 in spec §2.2. Tests assert the code, never the message.
- NaN and Infinity never reach the user: they become `OVERFLOW`, `DOMAIN_ERROR`,
  `UNDEFINED` or `DIV_BY_ZERO`.

## Standard Calculator

Pipeline: `tokenize → parse (AST) → evaluate → format`.

- Precedence, high to low: parentheses and calls, postfix `%`, `^` (right-assoc),
  unary `+`/`-`, `* / of`, `+ -` (spec §3.3).
- **Percent** is its own AST node. For `+` and `-`, a `%` right operand is relative to
  the left operand (`200 + 10%` → `220`); everywhere else it is `value / 100`.
- Two adjacent operands never fit the grammar, so implicit multiplication (`2(3)`)
  is rejected as `INVALID_EXPRESSION` without special code.
- The session holds `ans`. It changes only after a fully successful evaluation.

## Programmer Calculator

- Every value is a signed 64-bit two's-complement integer. Native 64-bit types are
  used where they exist; otherwise values are masked and sign-converted.
- Literal parsing order: prefix (`0b 0o 0d 0x`) overrides the input base → digit
  validation (`INVALID_DIGIT`) → range (`OUT_OF_RANGE`). Bin/oct/hex without a minus
  are raw bit patterns reinterpreted as signed.
- `>>` is arithmetic, `>>>` is logical, and the shift count is always decimal, 0–63.
- Output shows HEX, DEC, OCT, BIN. For negative values HEX/OCT/BIN show the full
  64-bit pattern and DEC the signed value.
- The session holds the input base.

## Unit Converter

- **Data-driven.** `units` holds categories as `{ name, base, units: [{symbol, name,
  factor}] }`. Adding a unit is a data change.
- Symbols are unique across all categories and matched case-insensitively, so the
  category is inferred from the symbols.
- Conversion is `value × from.factor ÷ to.factor`, using the exact ratios the spec
  names (`1000/3600`, `101325/760`, `180/π`, …).
- Temperature is formula-based, goes through °C, and rejects anything below absolute
  zero.
- The `all` target lists every unit of the source's category, in table order.

## Number formatting (spec §2.3)

One implementation per edition, used by the Standard Calculator and the Converter:
12 significant digits rounded half away from zero, trailing zeros trimmed, `-0` → `0`,
plain notation for `1e-6 ≤ |x| < 1e15`, otherwise `<mantissa>e<sign><exponent>`.

| Edition | How half-away-from-zero is achieved |
|---|---|
| JavaScript | `toExponential(11)` on the exact binary value |
| Python | `Decimal(float)` rounded with `ROUND_HALF_UP` (Python's own float formatting rounds ties to even) |
| C | `printf("%.34e")` gives the exact expansion, and the digit string is rounded by hand. |
| C++ | Same as C: `printf("%.34e")` gives the exact expansion, and the digit string is rounded by hand. |
| PHP | `sprintf('%.34e')` gives the exact expansion, and the digit string is rounded by hand (as in C). |
| Java | `new BigDecimal(double)` is the exact value; `round(new MathContext(12, RoundingMode.HALF_UP))` (HALF_UP is away from zero on BigDecimal) |
| Bash | awk `sprintf("%.34e")` gives the exact expansion, and the digit string is rounded by hand (as in C). |
| PowerShell | `ToString('E34')` on a `[double]` gives the exact expansion (.NET Core), and the digit string is rounded by hand (as in C) |
| Dart | `BigInt` exact expansion of the double (`mantissa × 5^k`); the digit string is rounded half-up by hand (Dart's own float formatting is not used) |
| TypeScript | `toExponential(11)` on the magnitude, exact binary value (as in JavaScript) |
| Go | `big.Float.Text('e', 800)` gives the exact expansion; the digit string is rounded half-up by hand (Go's `strconv` is not used) |
| C# | `BigInteger` exact expansion of the double (`mantissa × 5^k`); the digit string is rounded half-up by hand (.NET's own double formatting is not used) |
| Rust | `format!(“{:.60e}”)` gives the exact expansion; the digit string is rounded half-up by hand (Rust’s shorter float formatting is not used) |
| Kotlin | `BigDecimal(double)` is the exact value; `round(MathContext(12, RoundingMode.HALF_UP))` (HALF_UP is away from zero on BigDecimal, as in Java) |
| Swift | `String(format: "%.34e")` gives the exact expansion; the digit string is rounded half-up by hand (Swift's own description and `round` are not used) |

## CLI screens

Every edition talks to the terminal through one small `io` object and builds
screens from one helper:

- `io`: `write(text)`, `readLine(prompt)` (null at end of input), `style`
  (colours; plain for pipes and tests) and, on real terminals only, `select(...)`.
- `pick(io, title, options, back, quit)`: one question, many answers. 
Each edition has the same four selector layers, so the same tests (SL1–SL21) apply: key handling
(pure), drawing (pure), a draw/read loop over an injectable keyboard and screen, and `pick()` over an
injectable io. The C edition passes them as `SelIo` and `PickIo` structs of function pointers; the C++ edition uses the same structs with `std::function` members.
On a real
  terminal it is an arrow-key selector with a highlighted row; everywhere else
  it is a numbered list answered by typing a number, a name or a symbol. The selector is the default on a real terminal and the numbered list is used everywhere else (spec §2.1). Both are required.
- Prompt loop (calculators): `help`/`?`, `back`, `quit`, blank lines ignored,
  EOF exits cleanly, every error printed as `Error [CODE]: message`.
- Guided converter: a four-stage state machine (category, from, to, values).
  `back` steps back one stage and leaves to the main menu from the first.
  One-line commands are accepted at every stage.
- The Java edition uses `Selector.Keyboard` and `Selector.Screen` interfaces and `Io.SelectFn`.
- The Bash edition uses function names instead of objects: `IO_WRITE`, `IO_READLINE`, `IO_PREFILL`
  and `IO_SELECT` form the io object (empty `IO_SELECT` means numbered lists), and the selector loop
  takes `SEL_KEYFN`, `SEL_OUTFN` and `SEL_SIZEFN`. Engines return a status and leave the result in
  `AR_OUT` or the error in `AR_CODE` / `AR_MSG` instead of raising.
- The PowerShell edition uses a hashtable io object whose members are scriptblocks (`Write`, `ReadLine`, `Select`) and a `Color` flag. The selector loop takes a `$ReadKey` scriptblock and a `$Screen` hashtable (`Write`, `Size`, `Color`). Engines throw an exception whose `Data['ArCode']` carries the code.
- The Dart edition uses an abstract `Io` class (`write`, `readLine`, `hasSelector`, `select`) whose
  reading methods return `Future`s. The selector loop takes a `KeySource` (`enter`, `leave`, `readKey`)
  and a `Screen` (`write`, `size`, `color`). Engines are synchronous and throw `ArithmosError`; only the
  CLI layer is `async`, so a SIGTERM can run its handler and restore the terminal while a selector waits.
- The TypeScript edition uses an `Io` interface (`write`, `readLine`, optional `select`, `close`, `style`).
  The selector loop takes a `KeySource` (`enter`, `leave`, `readKey`) and a `Screen` (`write`, `size`);
  raw bytes become keys in the pure `parseKeys`. Engines throw `ArithmosError`; the CLI layer is `async`.
- The Go edition uses an `Io` interface (`Write`, `ReadLine`, `ReadLinePrefill`, `HasSelector`, `Select`).
  The selector loop takes a `KeySource` (`Enter`, `Leave`, `ReadKey`) and a `Screen` (`Write`, `Size`, `Color`);
  raw bytes become keys in the pure `ParseKey`. Engines `panic` with `*shared.Error` internally and
  `shared.Guard` turns it into a returned `error` at every public entry point.
- The C# edition uses an `IIo` interface (`Write`, `ReadLine`, `ReadLinePrefill`, `HasSelector`, `Select`).
  The selector loop takes an `IKeys` (`Enter`, `Leave`, `Read`) and an `IScreen` (`Write`, `Size`, `Color`);
  a `ConsoleKeyInfo` becomes a `Key` in the pure `KeyParser.FromConsole`. Engines throw `ArithmosError`;
  everything is synchronous.
- The Rust edition uses an `Io` trait (`write`, `read_line`, `read_line_prefill`, `has_selector`, `select`). The selector loop takes a `KeySource` (`enter`, `leave`, `read_key`) and a `Screen` (`write`, `size`, `color`); raw bytes become keys in the pure `parse_keys`. Engines return `Err(ArithmosError)`; everything is synchronous.
- The Kotlin edition uses an `Io` interface (`write`, `readLine`, `readLinePrefill`, `hasSelector`, `select`). The selector loop takes a `KeySource` (`enter`, `leave`, `read`) and a `Screen` (`write`, `size`, `color`); raw bytes become keys in the pure `parseKeys` (POSIX) and parseWinKey (Windows). Selector results are the sealed Outcome (Chosen, GoBack, GoQuit, EndOfInput, Typed). Engines throw ArithmosError; everything is synchronous.
- The Swift edition uses an `Io` protocol (`write`, `writeError`, `readLine`, `readLinePrefill`, `hasSelector`, `select`). The selector loop takes a `KeySource` (`enter`, `leave`, `readKey`) and a `Screen` (`write`, `size`, `color`); raw bytes become keys in the pure `parseKeys`. Engines throw `ArithmosError`; everything is synchronous.

Selector rules (every edition that can run an interactive terminal program):
1. Only on a real terminal; otherwise the numbered list (the required baseline).
2. ↑↓ move, Enter selects, Esc or `b` = `back`, `q` = `quit`, Ctrl-C / Ctrl-D = end of input.
   `b` and `q` act immediately, with no prompt line.
3. Any other printable key switches to a typed line (number, name, symbol or one-line
   command): the prompt shows the key and the rest of the line is read. A name starting with `b`
   or `q` is picked with the arrows or a number. After an error or a one-line command the list
   is shown again.
4. `ARITHMOS_PLAIN=1` forces the numbered list.
5. Raw key reading is on only while a key is read, so the terminal is never left raw.
6. A redraw moves the cursor up by the number of lines drawn, so one logical line must be one
   screen line: every drawn line is at most (terminal width − 1) columns (longer lines end with
   "…"), and the list window shrinks so the block fits the terminal height. Both are measured
   on every redraw, so resizing works.

## Design decisions

| Decision | Reason |
|---|---|
| IEEE double for Standard and Converter | Allowed by the spec; 12-digit display hides binary noise (`0.1 + 0.2` → `0.3`) |
| Exact 64-bit model for Programmer | `>>` / `>>>` and wrap-around must match across languages |
| Raise errors instead of returning error objects | Keeps engine code linear; the CLI is the only catch site |
| Unit table is data | Matches the spec tables one-to-one and diffs cleanly |
| One formatting module | Identical output across tools |