# Arithmos — Complete Project Roadmap

## Progress

| Release | Status |
|---|---|
| 1 — Core CLI | 15 of 43 languages complete (JavaScript, Python, C, C++, PHP, Java, Bash, PowerShell, Dart, TypeScript, Go, C#, Rust, Kotlin, Swift). Per-language table: [release-1.md §9](specifications/release-1.md) |
| 2 — Advanced Calculations | Not started |
| 3 — Extra Utilities | Not started |
| 4 — Mini-Games | Not started |
| 5 — GUI Editions | Not started |


> **One specification. Many languages. CLI first, GUI next.**
 
Arithmos is a multi-language computational toolkit. It begins with three practical tools—a standard calculator, a programmer calculator, and a unit converter—implemented across a selected set of programming languages. Once the core release is complete across those languages, the project expands through advanced calculations, extra utilities, mini-games, and eventually graphical interfaces. The long-term goal for the calculator is a **Windows Calculator–style experience**: one application with Standard, Scientific, Graphing, Programmer, Date Calculation, and Converter modes, plus memory and history.
 
Arithmos is a **new, separate project**. It does not replace the original CodeAtlas project; CodeAtlas is being kept for possible future work.
 
---
 
## 1. Project Identity
 
- **Project name:** Arithmos
- **Suggested repository/root folder:** `Arithmos/`
- **Project type:** Multi-language computational toolkit
- **Initial interface:** Command-line interface (CLI)
- **Later interface:** Graphical user interface (GUI), using an appropriate framework or toolkit for each language
- **Initial scope:** Standard Calculator, Programmer Calculator, Unit Converter
- **Long-term scope:** A full Windows Calculator–style calculator (Standard, Scientific, Graphing, Programmer, Date Calculation, and Converter modes with memory and history), additional utilities, seven mini-games, and GUI editions
### Project description
 
Arithmos is a multi-language computational toolkit featuring a Windows Calculator–style set of calculator modes (standard, scientific, graphing, programmer, and date calculation), unit and currency conversion, additional utilities, and interactive mini-games, with CLI and desktop interfaces.
 
### Guiding principles
 
1. **One specification, many implementations.** Define behavior centrally, then implement it idiomatically in each language.
2. **CLI first.** Establish reliable, testable command-line applications before making GUI editions.
3. **Release by release across languages.** Complete a release in every selected language before moving to the next release.
4. **Keep implementations appropriate to each language.** Do not force identical internal designs or workflows on languages with different runtimes and ecosystems.
5. **Test behavior, not just output appearance.** Use common test cases and document expected results, edge cases, and limitations.
6. **Keep modules separate.** Calculator logic, conversion logic, CLI interaction, and future GUI code should not become one tightly coupled block.
7. **Defer specialized languages when necessary.** Keep them on the long-term roadmap, but do not let their limitations block the main implementation track.
8. **Do not overbuild early.** Add folders and abstractions when they become useful instead of designing a large framework before the first release works.
---
 
## Final Calculator Target: Windows Calculator Parity
 
Arithmos' calculator will **eventually work like the Windows Calculator**: a single calculator application with switchable modes, rather than a loose collection of separate tools. The CLI releases build the capabilities one release at a time, and the GUI phase (Release 5) brings them together in a unified calculator window.
 
| Windows Calculator mode / feature | Arithmos release |
|---|---|
| Standard | Release 1 |
| Programmer (base conversion, bitwise operations, shifts) | Release 1 |
| Converter (length, mass, area, volume, temperature, time, speed, data) | Release 1 |
| Scientific | Release 2 |
| Graphing | Release 2 |
| Date Calculation | Release 2 |
| Memory (MC, MR, M+, M-, MS) and calculation history | Release 2 |
| Currency conversion | Release 3 |
| Programmer extras: word sizes (BYTE/WORD/DWORD/QWORD), arithmetic in programmer mode, rotate shifts, bit view | Release 3 |
| Additional converter categories (energy, power, pressure, angle) | Release 3 |
| Unified multi-mode calculator window, keyboard support | Release 5 |
 
Parity means matching the **scope and behavior** of these modes, not copying Microsoft's code, branding, or exact visual design. Each parity feature is still specified, tested, and released like any other feature. The quality of the parity claim is checked per language: do not claim a mode exists in a language until it passes the shared tests.
 
---
 
## 2. Release-Based Development Strategy
 
Arithmos is organized **by release first, then by language**.
 
For example, complete Release 1 in JavaScript, Python, C++, and every other selected language before beginning Release 2. Do not start a later release just because one language has finished its implementation.
 
Each release should have:
 
- A clear specification
- A defined feature checklist
- Shared or equivalent test cases
- Input validation and error handling
- A working CLI for CLI releases
- Documentation of language-specific differences and limitations
- A completion review before the project advances
### Language implementation policy
 
The goal is to implement the same supported features across all selected languages, but not every language can provide a conventional, standalone CLI in the same way. Some languages need a host runtime, specialized tooling, or a different integration model. Those cases should be documented rather than hidden or forced into an unsuitable design.
 
The selected full-CLI implementation track is listed in Section 4. Other folders from the original language collection are deferred for later specialized or complementary implementations.
 
---
 
## 3. Release Roadmap
 
## Release 1 — Core CLI
 
**Priority: First implementation milestone**
 
Implement all three tools in every selected language before moving to Release 2.
 
> The detailed behavior contract, error codes, unit factors, shared test cases, and per-language progress table for this release are in **`Arithmos-Release-1.md`** (`docs/specifications/release-1.md`).
 
### 1. Standard Calculator
 
Initial features:
 
- Addition
- Subtraction
- Multiplication
- Division
- Decimal and negative numbers
- Percentages
- Parentheses and expression evaluation, where supported by the chosen implementation
- Basic scientific operations, such as square roots and powers, only to the extent included in the agreed initial specification
- Clear error messages for invalid input
- Division-by-zero handling
- Repeated calculations without restarting the application
**Scope control:** Advanced scientific functionality, graphing, and statistics remain in Release 2. The initial standard calculator should stay focused.
 
### 2. Programmer Calculator
 
Initial features:
 
- Binary, octal, decimal, and hexadecimal number systems
- Convert values between number bases
- Display values in the selected base
- Bitwise AND, OR, XOR, and NOT
- Left and right bit shifts
- Input validation for each base
- Clear handling of negative values and invalid digits
Document how each implementation handles integer width, signed and unsigned values, overflow, and bitwise NOT. These behaviors can vary between languages, so the shared specification must define the intended behavior.
 
### 3. Unit Converter
 
Initial features:
 
- Length
- Mass/weight
- Area
- Volume
- Temperature
- Time
- Speed
- Digital information units, such as bits and bytes
- Consistent rounding and precision rules
- Invalid-unit and invalid-value handling
Currency conversion is a later feature in Release 3 because it requires exchange-rate data and a policy for rate timestamps and unavailable services.
 
### Release 1 completion criteria
 
- All three tools work in each selected language.
- Every implementation follows the shared specifications.
- Common test cases pass, including edge cases.
- Invalid input is handled predictably.
- Each CLI is documented with instructions to build/run and test it.
- Differences caused by language semantics or runtime limitations are documented.
- Only after all selected languages meet the release criteria should Release 2 begin.
---
 
## Release 2 — Advanced Calculations
 
Complete this release across all selected languages before moving to Release 3.
 
### 1. Scientific Calculator
 
- Trigonometric functions
- Inverse trigonometric functions, where supported
- Logarithms and natural logarithms
- Factorials
- Scientific notation
- Constants such as π and e
- Degree and radian modes
- Powers and roots beyond the initial basic set
- Domain and precision error handling
### 2. Graphing Calculator
 
- Evaluate supported mathematical functions
- Generate plot points
- Plot common functions such as lines, quadratics, and trigonometric functions
- Define graph ranges and sampling intervals
- Report invalid or undefined regions where practical
A terminal edition can produce an ASCII plot or output plot data. A GUI edition can later provide interactive graphs. The exact plotting capability may vary by language and available libraries, but its supported mathematical behavior should be documented.
 
### 3. Statistics Calculator
 
- Mean
- Median
- Mode
- Range
- Variance
- Standard deviation
- Basic descriptive summaries for a list of values
Define whether variance and standard deviation are calculated as population or sample statistics, and test those choices consistently.
 
### 4. Date and Time Calculator
 
- Difference between dates
- Add or subtract days from a date
- Time duration calculations
- Basic time-unit conversions
- Leap-year handling
- Invalid-date handling
Timezone-aware calculations can be considered if needed, but should be specified separately from simple date arithmetic.
 
### 5. Calculator Memory and History
 
Part of the Windows Calculator–style experience.
 
- Memory operations: memory clear (MC), recall (MR), add (M+), subtract (M-), and store (MS)
- Calculation history for the current session
- Reuse a previous result or history entry in a new calculation
- Clear history
- Memory and history available in Standard and Scientific modes
- Clear behavior when memory is empty
### Release 2 completion criteria
 
- All advanced features included in the agreed specification are implemented in each selected language.
- Standard, Scientific, Graphing, and Date Calculation modes are all available, with memory and history.
- Mathematical edge cases and date boundaries are tested.
- CLI behavior remains available and functional.
- Language-specific limitations and dependencies are documented.
---
 
## Release 3 — Extra Utilities
 
Complete this release across all selected languages before moving to Release 4.
 
### 1. Currency Converter
 
- Convert between supported currencies
- Use a documented exchange-rate source
- Show the rate timestamp or retrieval date
- Handle unavailable or stale rates
- Separate fixed unit conversions from exchange-rate-based conversions
Do not present hard-coded sample rates as live rates. If a language implementation cannot access a network service directly, document the required input or supporting mechanism.
 
### 2. Equation Solver
 
- Solve linear equations
- Solve quadratic equations
- Report real roots and, where supported, complex roots
- Handle degenerate equations and invalid input
Keep the supported equation forms explicit; a general-purpose symbolic algebra system is outside the initial scope unless added as a separate future project decision.
 
### 3. Expanded Number System Tools
 
- More detailed base conversion
- Binary grouping and formatting
- Signed integer representations
- Two's-complement explanations or displays
- Integer-width-aware views
These features extend the base conversion and bitwise functionality introduced in Release 1.
 
### 4. Data and File-Size Tools
 
- Convert bits and bytes
- Convert decimal and binary storage units
- Explain the difference between KB/MB/GB and KiB/MiB/GiB
- Convert common file-size values
### 5. Percentage Tools
 
- Find a percentage of a value
- Calculate percentage change
- Calculate discounts
- Calculate markup
- Find the original value before a percentage increase or decrease
### 6. Programmer Calculator Parity Features
 
Further steps toward the Windows Calculator's Programmer mode:
 
- Selectable word sizes: BYTE (8-bit), WORD (16-bit), DWORD (32-bit), and QWORD (64-bit)
- Arithmetic in programmer mode (add, subtract, multiply, divide, modulo) with defined overflow behavior
- Arithmetic shift, logical shift, rotate, and rotate-through-carry operations
- A bit-level view showing individual bits of the current value
- Bit toggling
### 7. Converter Expansion
 
Brings the converter in line with the Windows Calculator's converter categories:
 
- Energy
- Power
- Pressure
- Angle
- Any other categories added to the agreed specification
### Release 3 completion criteria
 
- All utilities follow documented formulas and conversion rules.
- Currency results identify the source and freshness of rates.
- Invalid values and unavailable data are handled explicitly.
- Shared test cases pass in every selected implementation.
---
 
## Release 4 — Mini-Games
 
Complete the seven selected games across the selected languages before moving to Release 5.
 
### 1. Tic-tac-toe
 
- Two-player mode
- Win detection
- Draw detection
- Input validation
- Replay option
- Optional computer opponent as a later enhancement
### 2. Number Guessing
 
- Generate a secret number
- Higher/lower hints
- Attempt tracking or limits
- Difficulty levels
- Replay option
### 3. Rock-paper-scissors
 
- Player versus computer
- Randomized computer choice
- Win/loss/draw logic
- Score tracking
- Multi-round matches
### 4. Math Quiz
 
- Questions using supported arithmetic operations
- Difficulty levels
- Score tracking
- Optional timed rounds
- Clear feedback for correct and incorrect answers
### 5. 2048
 
- Number-tile grid
- Keyboard controls for CLI versions
- Tile merging
- Score tracking
- Win/loss detection
- New-game and replay options
### 6. Word Guess
 
A Wordle-style game: the player guesses a hidden word within a limited number of attempts.
 
- Secret word chosen from a bundled word list (default: 5 letters)
- Limited number of attempts (default: 6)
- Guess validation: correct length, letters only, and optionally a check against a valid-word list
- Per-letter feedback after each guess: correct letter in the correct position, correct letter in the wrong position, or letter not in the word
- Correct handling of repeated letters in the guess and in the secret word
- Display of previous guesses and their feedback
- Win and loss detection, with the answer revealed on loss
- Replay option
### 7. Hangman
 
The player guesses a hidden word one letter at a time before running out of wrong guesses.
 
- Secret word chosen from a bundled word list
- Masked word display with correctly guessed letters revealed
- Limited wrong guesses (default: 6) with a text-based hangman drawing for CLI versions
- Tracking of guessed letters, with repeated guesses rejected without penalty
- Input validation: single letters only, case-insensitive
- Optional categories or difficulty levels (by word length)
- Win and loss detection, with the word revealed on loss
- Replay option
The word lists for Word Guess and Hangman should be shared data files kept in one central location (for example `docs/data/`) so every language uses the same words, and so seeded tests can pick a known word.
 
### Release 4 completion criteria
 
- Each game has clearly defined rules and input behavior.
- Game logic is separated from terminal interaction where practical.
- Randomized behavior is testable, using controlled or seeded randomness where appropriate.
- Win, loss, draw, and boundary conditions are tested.
- Word Guess feedback is tested for repeated letters, invalid guesses, and attempt limits; Hangman is tested for repeated guesses, wrong-guess limits, and word reveal.
- Word lists load correctly in every language, and seeded or injected word selection makes both word games testable.
- All selected language editions are complete before the GUI phase begins.
---
 
## Release 5 — GUI Editions
 
Build graphical interfaces using suitable frameworks or toolkits for each language while preserving the CLI implementations.
 
The GUI phase is planned after the CLI releases, but it is acceptable to prototype a GUI for a language once its core CLI is stable, provided this does not derail the release-by-language completion strategy.
 
### GUI goals
 
- A polished calculator display and input controls
- Navigation between Standard, Programmer, Converter, and later modes
- Keyboard support
- Clear validation and error messages
- Calculation history where appropriate
- Accessible and consistent interaction patterns
- A visual design that is recognizable across editions
- Reuse of the language edition's core logic wherever practical
### Possible GUI technology choices
 
These are examples, not mandatory choices:
 
| Language/ecosystem | Possible GUI approach |
|---|---|
| JavaScript / TypeScript | Electron or another suitable desktop framework |
| Python | PySide/Qt or Tkinter |
| C# / VB.NET | WPF or WinUI where appropriate |
| C++ | Qt |
| Java | JavaFX or Swing |
| Dart | Flutter or another suitable desktop toolkit |
| Swift | SwiftUI or AppKit on supported Apple platforms |
| Objective-C | AppKit on macOS |
| Other languages | Select a compatible framework based on the language, target OS, ecosystem, and project needs |
 
Not every language necessarily needs a GUI edition. For languages that are specialized, host-dependent, or unsuitable for a conventional desktop application, document the limitation and decide on a suitable complementary approach later.
 
### GUI completion criteria
 
- The original CLI remains functional.
- The GUI uses the same specifications and core behavior.
- Core operations have automated tests independent of the GUI.
- GUI-specific interaction is tested where practical.
- Build and run instructions are documented for each supported target platform.
---
 
## 4. Selected Language Track for the Initial CLI Releases
 
The following languages were selected for the main full-CLI implementation track. This is a practical project selection, not a claim that every language has identical runtime capabilities or is equally suited to every feature.
 
1. ABAP
2. Ada
3. Apex
4. Assembly (ASM)
5. Bash
6. C
7. C++
8. C#
9. Clojure
10. COBOL
11. Dart
12. Elixir
13. Erlang
14. F#
15. Fortran
16. Go
17. Groovy
18. Haskell
19. Java
20. JavaScript
21. Julia
22. Kotlin
23. Lisp
24. Lua
25. MATLAB
26. Nim
27. Objective-C
28. OCaml
29. Perl
30. PHP
31. PowerShell
32. Prolog
33. Python
34. R
35. Ruby
36. Rust
37. Scala
38. Solidity
39. Swift
40. TypeScript
41. VBA
42. VB.NET
43. Zig
### Important language-specific notes
 
- **Apex:** Requires the Salesforce environment and associated tooling; treat it as a specialized CLI workflow rather than assuming a conventional standalone executable.
- **Assembly:** Feasible but highly platform- and architecture-dependent; implementation and test setup will be more involved.
- **Solidity:** Designed for smart contracts. A calculator-like implementation can be created as contract logic and tested through development tools, but this is not equivalent to a normal standalone CLI app.
- **VBA:** Usually runs within a host such as Microsoft Office. A host-dependent workflow may be needed instead of a standalone terminal executable.
- **ABAP:** Usually depends on an ABAP runtime or platform.
- **MATLAB and R:** Strong for numerical work, but CLI packaging and interactive behavior depend on their runtime environments.
- **Other languages:** Select the most idiomatic CLI approach and document required compilers, interpreters, libraries, or external services.
If a selected language cannot reasonably support a particular feature or a conventional standalone CLI, record the limitation and decide whether to implement a reduced version, use a host environment, or defer that edition. Do not silently claim feature parity when it is not present.
 
### Languages deferred for a later specialized or complementary phase
 
These folders were present in the original language collection but are not part of the main selected full-CLI track for now:
 
- CSS
- DAX
- GDScript
- HTML
- Mojo
- Nix
- PL/SQL
- Regex
- SQL
- SystemVerilog
- Terraform
- T-SQL
- VHDL
- WASM
These are not necessarily excluded from Arithmos forever. Some are best suited to interface work, database-backed calculations, configuration, game-engine integration, hardware-oriented arithmetic, or compilation/runtime targets. Revisit them after the main track is established.
 
---
 
## 5. Recommended Repository Structure
 
Use the language folders at the repository root. Keep the documentation and shared specifications in one central location.
 
```text
Arithmos/
├── README.md
├── .gitignore
├── .editorconfig
│
├── docs/
│   ├── roadmap.md
│   ├── language-support.md
│   ├── development-workflow.md
│   ├── specifications/
│   │   ├── release-1.md
│   │   ├── standard-calculator.md
│   │   ├── programmer-calculator.md
│   │   ├── converter.md
│   │   ├── advanced-calculations.md
│   │   ├── extra-utilities.md
│   │   └── mini-games.md
│   ├── data/                    # Shared data, such as word lists (Release 4)
│   │   ├── wordguess-words.txt
│   │   └── hangman-words.txt
│   └── test-cases.md
│
├── javascript/
│   ├── package.json
│   ├── src/
│   │   ├── cli/
│   │   │   ├── index.js
│   │   │   └── menu.js
│   │   ├── calculator/
│   │   ├── programmer/
│   │   ├── converter/
│   │   └── shared/
│   ├── test/
│   └── gui/                 # Add during the GUI phase
│
├── python/
├── c/
├── cpp/
├── csharp/
├── go/
├── rust/
└── ...                      # Remaining selected language folders
```
 
### Structure guidelines
 
- The `docs/` folder defines intended behavior across languages.
- Each language folder contains its own implementation, build/run instructions, and tests as appropriate.
- Within an implementation, keep CLI interaction separate from calculation and conversion logic.
- Create `advanced/`, `utilities/`, `games/`, and `gui/` directories only when those features are actually being implemented.
- Do not force every language to use the same internal folder layout if that conflicts with its conventions.
- Avoid adding unnecessary abstractions or dependencies before the project needs them.
---
 
## 6. Shared Specifications and Test Strategy
 
The project needs a language-neutral behavior contract. Every suitable implementation should use it.
 
### Example shared test cases
 
| Feature | Input | Expected result |
|---|---|---|
| Addition | `25 + 17` | `42` |
| Division | `10 / 4` | `2.5` |
| Division by zero | `10 / 0` | A documented error or result policy |
| Temperature | `0 °C` to Fahrenheit | `32 °F` |
| Base conversion | Decimal `255` to hexadecimal | `FF` |
| Bitwise AND | `5 AND 3` | `1` |
| Invalid base digit | `102` interpreted as binary | Input rejected |
| Percentage | 20% of 150 | `30` |
 
These are illustrative examples; expand the test specification as each feature is designed.
 
### Test principles
 
- Define expected behavior before implementing it in many languages.
- Test valid inputs, invalid inputs, boundary cases, and error handling.
- Define numeric precision and rounding explicitly.
- Test division by zero and other mathematical domain errors.
- Specify programmer-calculator integer widths and signedness.
- Test temperature conversion offsets and negative temperatures.
- For date calculations, test leap years and date boundaries.
- For currency conversion, test unavailable rates and stale data.
- For games, test win/loss/draw conditions and randomized behavior.
- For word games, test repeated-letter handling, invalid guesses, attempt limits, and word-list loading.
- For memory and history, test empty-memory behavior and clearing.
- Keep tests independent of terminal formatting wherever possible.
Some languages may need different test frameworks. Equivalent tests and expected behavior matter more than using the same testing tool everywhere.
 
---
 
## 7. Development Workflow
 
Follow this workflow for each language and release.
 
1. **Read the specification.** Confirm what the feature must do.
2. **Design the implementation.** Choose idiomatic data types, modules, and libraries.
3. **Implement the core logic.** Keep it separate from CLI input/output where practical.
4. **Add CLI interaction.** Create the menu, input prompts, and output formatting.
5. **Write and run tests.** Cover normal behavior and edge cases.
6. **Document the language edition.** Include prerequisites, setup, run commands, tests, and known limitations.
7. **Review against the shared specification.** Record any intentional differences.
8. **Mark the language/release complete.** Move to the next language within the same release.
9. **Advance only after the release is complete across the selected track.**
A tracking table can be maintained in `docs/roadmap.md` or a separate progress file. Track each release and language independently so unfinished implementations remain visible.
 
---
 
## 8. Scope and Project Management Rules
 
To prevent Arithmos from becoming unnecessarily large:
 
- Do not add mini-games to Release 1.
- Do not claim Windows Calculator parity for a language until its Standard, Scientific, Graphing, Programmer, Date Calculation, and Converter modes all pass the shared tests.
- Copy the scope and behavior of Windows Calculator modes, not Microsoft's code, assets, or branding.
- Do not implement graphing before the advanced-calculation release.
- Do not add currency conversion to the initial fixed-unit converter.
- Do not build a universal cross-language framework unless a concrete need appears.
- Do not require all languages to share the same GUI framework.
- Do not discard the CLI when GUI work begins.
- Do not mark a language complete merely because it compiles; verify behavior against the specification.
- Do not let a specialized language block progress on the main implementation track indefinitely. Document it, defer it when necessary, and continue according to the agreed policy.
- Keep CodeAtlas separate. Reuse general lessons or ideas when useful, but do not merge the two projects unless that decision is made deliberately.
---
 
## 9. Immediate Next Steps
 
The first work should be limited to Release 1.
 
1. Create the `Arithmos/` repository and root documentation.
2. Add the final language support list and release roadmap.
3. Review and adopt `Arithmos-Release-1.md` as the Release 1 specification covering the Standard Calculator, Programmer Calculator, and Unit Converter.
4. Define shared test cases and numeric/error-handling rules.
5. Set up the JavaScript edition as the reference CLI implementation.
6. Implement and test all three core tools in JavaScript.
7. Move through the remaining selected languages, completing the same Release 1 features in each.
8. Begin Release 2 only when the selected Release 1 track is complete or any deferred language exceptions are explicitly documented.
---
 
## 10. Definition of Success
 
Arithmos succeeds when it provides a well-documented set of consistent computational tools across many language ecosystems, with:
 
- A clearly specified feature set
- Reliable CLI implementations
- Shared behavioral tests
- Documented language-specific choices and limitations
- Modular, maintainable code
- A path to suitable graphical interfaces
- A calculator that grows into a Windows Calculator–style multi-mode application
- Room for later utilities and games (including the seven mini-games) without destabilizing the core
**Final direction:** Arithmos is a release-driven, multi-language project. Finish the agreed scope of each release across the selected language track before advancing, preserve the CLI as a permanent interface, and add GUI editions and later features in controlled stages.
 
