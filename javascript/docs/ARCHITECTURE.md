# Architecture — JavaScript Edition

## Goals

1. **Behavior contract first.** The code mirrors the specification section by section, so it can be reviewed against it line by line.
2. **Logic separate from I/O.** Spec Section 6 requires calculation logic to be testable without a terminal and reusable by later GUI editions. The engines never read stdin or write stdout.
3. **One place for each rule.** Number formatting, error codes, and unit data each live in exactly one module.
4. **No dependencies.** Plain Node.js (20+), ES modules.

## Layers

```text
 bin/arithmos.js            entry point (argv → main)
        │
 ┌──────▼──────────────────────────────────────────┐
 │ src/cli        menu, REPL loop, tool bindings   │  ← only layer that does I/O
 └──────┬───────────────┬───────────────┬──────────┘
        │               │               │
 ┌──────▼─────┐  ┌──────▼──────┐  ┌─────▼──────┐
 │ calculator │  │ programmer  │  │ converter  │      pure logic, no I/O
 └──────┬─────┘  └──────┬──────┘  └─────┬──────┘
        └───────────────┼───────────────┘
                 ┌──────▼──────┐
                 │   shared    │   error codes, number formatting
                 └─────────────┘
```

Dependency rule: arrows point down only. `shared` imports nothing from the other layers. Engines never import from `cli`.

## Module map

```text
src/
├── cli/
│   ├── index.js        main(argv): one-shot mode or interactive menu
│   ├── menu.js         "Arithmos 1.0 — Core CLI" menu (1/2/3/0)
│   ├── repl.js         shared prompt loop (help/back/quit, EOF, blank lines, errors)
│   └── tools/
│       ├── standard.js     binds calculator engine to REPL
│       ├── programmer.js   binds programmer engine to REPL
│       └── converter.js    binds converter engine to REPL
├── calculator/
│   ├── tokenizer.js    string → tokens
│   ├── parser.js       tokens → AST (precedence, associativity)
│   ├── evaluator.js    AST → number (percent rules, domain rules)
│   └── index.js        createStandardSession(): holds `ans`
├── programmer/
│   ├── int64.js        64-bit signed model on BigInt
│   ├── parse.js        literals, prefixes, input base, digit validation
│   ├── operations.js   AND, OR, XOR, NOT, <<, >>, >>>
│   ├── format.js       HEX/DEC/OCT/BIN output
│   └── index.js        createProgrammerSession(): holds input base
├── converter/
│   ├── units.js        data tables: categories, symbols, factors
│   ├── convert.js      value → base → target, `all`, `list`
│   ├── temperature.js  c/f/k formulas, absolute-zero check
│   └── index.js
└── shared/
    ├── errors.js       ArithmosError + the 14 codes
    ├── format-number.js  12-significant-digit display (spec 2.3)
    └── index.js
```

## Data flow

```text
user line ─► repl.js ─► tool handler ─► engine (pure) ─► result value
                                                │
                                      throws ArithmosError(code)
                                                │
user sees ◄─ repl.js prints `Error [CODE]: msg` ┘
```

- Engines return **values** (numbers, BigInts, plain objects) and throw `ArithmosError` with a `code`.
- Only the CLI layer turns values into text and errors into `Error [CODE]: message` lines.
- Any non-`ArithmosError` exception caught by the REPL is a bug; it is reported as a generic internal error and the loop continues, so invalid input never crashes the program (spec goal 4).

## Error handling

- Single class `ArithmosError { code, message }` in `shared/errors.js`.
- `code` is one of the 14 values in spec Section 2.2 (frozen list `ERROR_CODES`). A test asserts the list matches the spec exactly.
- Messages are free text and never asserted in tests.
- NaN and Infinity are never propagated: the evaluator and converter convert them to a code (`OVERFLOW`, `DOMAIN_ERROR`, `UNDEFINED`, `DIV_BY_ZERO`) before returning.

## Standard Calculator

**Pipeline:** `tokenize → parse → evaluateAst → formatNumber`.

- **Tokenizer** accepts numbers (`12`, `12.5`, `.5`, `5.`), operators `+ - * / ^`, parentheses, `%`, and identifiers `sqrt`, `abs`, `ans`, `of` (case-insensitive). Scientific notation input is not supported, so `1e5` tokenizes as `1` followed by identifier `e5` and fails with `INVALID_EXPRESSION`.
- **Parser** is recursive descent, one function per precedence level (spec 3.3):

  ```text
  expression := term (('+' | '-') term)*
  term       := unary (('*' | '/' | 'of') unary)*
  unary      := ('+' | '-') unary | power
  power      := postfix ('^' unary)?          # right-assoc; '2^-1' works via unary
  postfix    := primary '%'*
  primary    := NUMBER | 'ans' | '(' expression ')' | ('sqrt'|'abs') '(' expression ')'
  ```

  This gives `-2^2 = -(2^2) = -4` and `2^3^2 = 2^(3^2) = 512`. Two adjacent operands (`2(3)`, `2ans`) never match the grammar, so implicit multiplication is rejected automatically with `INVALID_EXPRESSION`.
- **Percent** is a `Percent` AST node. The evaluator checks, for `+` and `-`, whether the right operand is a `Percent` node: if so it computes relative to the left operand (`200 + 10%` → `200 + 200*0.10`). In every other position a `Percent` node is simply `value / 100`.
- **Domain rules** (spec 3.5) are applied in the evaluator for `^` and `sqrt`; the result is checked for `Infinity` (→ `OVERFLOW`) and `NaN`.
- **Session** keeps `ans`. It is updated only after a fully successful evaluation, so a failed line leaves it unchanged (test S33).

## Programmer Calculator

- **Integer model:** every value is a `BigInt` normalized with `BigInt.asIntN(64, v)`. Constants `INT64_MIN` / `INT64_MAX` are in `int64.js`.
- **Literal parsing** (`parse.js`):
  - Prefix (`0b`, `0o`, `0d`, `0x`) overrides the session input base.
  - Digits are validated against the base first (`INVALID_DIGIT`), then range.
  - Decimal values must fit the signed range (`OUT_OF_RANGE`).
  - Bin/oct/hex without a minus sign are read as raw bit patterns up to 64 bits and reinterpreted as signed (`0xFFFFFFFFFFFFFFFF` → `-1`); more than 64 bits is `OUT_OF_RANGE`.
  - A leading `-` negates the magnitude, which must not exceed 2^63.
- **Operations** (`operations.js`) work on `BigInt`:
  - `AND`, `OR`, `XOR`, `NOT` use BigInt bitwise operators, then `asIntN(64, …)`.
  - `<<` shifts then wraps with `asIntN` (bits past bit 63 silently discarded).
  - `>>` is arithmetic (native BigInt `>>` is sign-extending).
  - `>>>` shifts `asUintN(64, a)` and then reinterprets as signed.
  - The shift count is parsed as a decimal in all bases and must be 0–63 (`INVALID_SHIFT`).
- **Output** (`format.js`): HEX uppercase, no prefix, no padding or grouping. For negative values, HEX/OCT/BIN are produced from `asUintN(64, v)`, DEC from the signed value.
- **Session** keeps the current input base (`base bin|oct|dec|hex`; unknown name → `INVALID_BASE`).
- One operation per line; chaining is not required in Release 1.

## Unit Converter

- **Data-driven.** `units.js` holds `CATEGORIES`: `{ name, base, units: [{ symbol, name, factor }] }`. Adding a unit is a one-line data change; no logic changes.
- **Categories:** length, mass, area, volume, time, speed, digital, energy, power, pressure, angle (factor-based) and temperature (formula-based).
- **Lookup:** a map from lowercase symbol → `{ category, unit }` is built once at load time and checked for duplicate symbols (spec requires every symbol to be unique across categories). Lookup lowercases the input, so symbols are case-insensitive.
- **Conversion:** `value × from.factor / to.factor`, using the exact ratio expressions from the spec where it asks for them (`1000/3600`, `1852/3600`, `101325/760`, `1055.05585262/60`, `180/Math.PI`, …). Different categories → `INCOMPATIBLE_UNITS`; unknown symbol → `UNKNOWN_UNIT`.
- **Temperature** (`temperature.js`) converts through Celsius and rejects inputs and results below absolute zero with `BELOW_ABSOLUTE_ZERO`.
- **`all` target:** returns every unit of the source's category in table order, including the source unit.
- **Output** is always run through `formatNumber`.

## Number formatting (`shared/format-number.js`)

The single implementation of spec 2.3, used by the Standard Calculator and the Converter:

1. Reject `Infinity` with `OVERFLOW`.
2. Normalize `-0` to `0`.
3. Round to 12 significant digits using `Number.prototype.toPrecision(12)` (which rounds ties away from zero for the magnitude), then re-parse and re-format digits manually so output never depends on JavaScript's own exponent formatting.
4. Trim trailing zeros and a trailing decimal point.
5. Use plain notation for `1e-6 ≤ |x| < 1e15`, otherwise `<mantissa>e<sign><exponent>` (e.g. `1.5e+20`, `2e-7`).

`toPrecision` behavior at exact ties is verified by dedicated tests in `test/shared.test.js`; if it ever disagrees with the spec, the formatter is changed, not the spec.

## CLI layer

- `repl.js` implements the behaviors common to all three tools (spec 2.1, 2.4): trim input, ignore blank lines, `help` / `back` / `quit` case-insensitive, clean exit on EOF, `UNKNOWN_COMMAND` for anything the tool does not recognize.
- Tool bindings supply: the prompt (`standard> `, `programmer> `, `converter> `), a `handle(line)` function, and help text.
- I/O is passed in (`io = { readLine, write }`) rather than using `process.stdin` / `process.stdout` directly, so CLI tests can drive it with scripted input.
- One-shot mode (`arithmos convert 100 cm in`) reuses the same handlers.

## Testing strategy

See [`TESTING.md`](TESTING.md). In short: shared data-driven cases from `../docs/release-1-cases.json`, plus unit tests for formatting and CLI behavior.

## Design decisions

| Decision | Reason |
|---|---|
| `number` (double) for Standard/Converter | Spec allows IEEE 754; 12-digit display hides binary noise (`0.1 + 0.2 → 0.3`) |
| `BigInt` for Programmer | Exact 64-bit behavior, native `>>`, easy masking |
| Throw `ArithmosError` instead of returning error objects | Keeps engine code linear; the CLI is the only catch site |
| Unit table is data, not code | Matches the spec tables 1:1 and is easy to diff |
| Formatting in one module | Guarantees identical output across tools |
| ES modules, no build step | Simplest possible run/test story |
