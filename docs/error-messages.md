# Arithmos — Error Messages

> **Generated file — do not edit by hand.** Regenerate with `python3 scripts/build-error-messages.py`.
> It is built from the error call sites in the JavaScript and Python editions; see the end of this file for what was compared.

Every error prints as one line:

```text
Error [CODE]: wording
```

**Tests check the code, never the wording** (spec §2.2, amendment R26). Even so, a new language should copy the wording below, so that all editions read the same to a user. Wording in `{braces}` is a placeholder for the value shown in the key below; everything else is literal, including punctuation and spacing.

The JavaScript edition is the reference. Where the editions disagree, the row shows the JavaScript wording and is marked †.

## Placeholders

| Placeholder | Meaning |
|---|---|
| `{input}` | The text exactly as the user typed it, case preserved (a unit symbol, base name, category name, or number). |
| `{word}` | An unrecognised or misplaced word from an expression, case preserved (a keyword in `Unexpected '…'` is shown in lower case). |
| `{char}` | The single unexpected character. |
| `{fn}` | A function name: `sqrt` or `abs`. |
| `{digit}` | The offending digit, uppercased. |
| `{base}` | The base being read: `bin`, `oct`, `dec` or `hex`. |
| `{from_category}` | Category name of the source unit, lowercase (`length`, `mass`, ...). |
| `{to_category}` | Category name of the target unit, lowercase. |
| `{op}` | An operator symbol (JavaScript-only message). |

## Messages

| Code | Situation | Wording |
|---|---|---|
| `INVALID_EXPRESSION` | Standard — a word that is not `sqrt`, `abs`, `ans` or `of` (matching is case-insensitive). | `Unknown word '{word}'` |
| `INVALID_EXPRESSION` | Standard — a character that is not a digit, letter, `+ - * / ^`, parenthesis or `%`: `2 $ 3`, `=`, `,`. | `Unexpected character '{char}'` |
| `INVALID_EXPRESSION` | Standard — the line stops where an operand was required: `2 +`, `3 *`, `-`. | `The expression ends too early` |
| `INVALID_EXPRESSION` | Standard — `sqrt` or `abs` not followed by `(`: `sqrt 4`. | `{fn} needs parentheses, like {fn}(4)` |
| `INVALID_EXPRESSION` | Standard — a `(`, `sqrt(` or `abs(` that is never closed: `(2 + 3`, `sqrt(4`. | `Missing closing parenthesis` |
| `INVALID_EXPRESSION` | Standard — a keyword where an operand was expected: `of 5`. (`ans`, `sqrt` and `abs` are accepted there.) | `Unexpected '{word}'` |
| `INVALID_EXPRESSION` | Standard — a token that cannot start an operand (`)`, `*`, `%`), or tokens left over after a complete expression. Implicit multiplication lands here: `2(3)`, `2 3`. | `Unexpected symbol` |
| `INVALID_EXPRESSION` | Standard — the engine is handed an empty expression. The CLI ignores blank lines, so only a direct engine call reaches this. | `Nothing to calculate` |
| `INVALID_EXPRESSION` | Shared number formatter handed NaN. Unreachable in normal use: the evaluator and converter turn NaN into an error first. | `Result is not a number` |
| `INVALID_NUMBER` | Programmer — a literal that is empty after its sign/prefix, or contains a character that is not a letter or digit: `1.5`, `-`, `FF!`. Converter — a value that is not a plain decimal: `abc`, `1e3`, `1,000`. | `'{input}' is not a number` |
| `DIV_BY_ZERO` | Standard — `0^-1`. | `Zero cannot be raised to a negative power` |
| `DIV_BY_ZERO` | Standard — the right side of `/` is zero: `10 / 0`, `1 / (2 - 2)`. | `Cannot divide by zero` |
| `DOMAIN_ERROR` | Standard — safety net if an operation produces NaN. No input reaches it today; every NaN-producing case is rejected earlier with a more specific code. | `The result is not a number` |
| `DOMAIN_ERROR` | Standard — a negative base with a non-integer exponent: `(-8)^(1/3)`. | `A negative number cannot have a fractional power` |
| `DOMAIN_ERROR` | Standard — `sqrt(-1)`. | `Cannot take the square root of a negative number` |
| `UNDEFINED` | Standard — `0^0`. | `0^0 is undefined` |
| `OVERFLOW` | Standard — a result beyond the double-precision range: `10^400`. | `The result is too large` |
| `OVERFLOW` | Converter — the typed value is fine but the converted result overflows. (The shared number formatter also raises it for Standard, but the evaluator rejects overflow first.) | `Result is too large to represent` |
| `OVERFLOW` | Converter — the typed value itself exceeds the double-precision range (about 309+ digits). | `That number is too large` |
| `INVALID_DIGIT` | Programmer — a digit that does not exist in the base being read: `2` in binary, `8` in octal, `G` in hex. A prefix chooses the base (`0b102`). | `'{digit}' is not a {base} digit` |
| `INVALID_BASE` | Programmer — an unknown base name in `base <name>` or `convert <value> <from> <to>`. | `'{input}' is not a base. Use bin, oct, dec or hex` |
| `INVALID_BASE` | Programmer — `base` with no name, or with extra words. | `Use: base bin \| oct \| dec \| hex` |
| `OUT_OF_RANGE` | Programmer — a decimal above 9223372036854775807, or any literal with a leading `-` whose magnitude exceeds 2^63. | `That number does not fit in 64 bits` |
| `OUT_OF_RANGE` | Programmer — a bin/oct/hex literal without a minus sign that is wider than 64 bits: `0x10000000000000000`. | `That number needs more than 64 bits` |
| `INVALID_SHIFT` | Programmer — a shift count that is negative, above 63, or not a plain decimal integer: `1 << 64`, `1 << -1`, `1 << 2.5`. | `A shift count must be a whole number from 0 to 63` |
| `UNKNOWN_UNIT` | Converter — a unit symbol that is not in the tables (`pascal`, `xyz`). | `'{input}' is not a known unit. Try: list` |
| `INCOMPATIBLE_UNITS` | Converter — source and target units are in different categories: `convert 5 m kg`. | `Cannot convert {from_category} to {to_category}` |
| `BELOW_ABSOLUTE_ZERO` | Converter — a temperature below 0 K, -273.15 C or -459.67 F, as the input of `convert` or of the `all` target. | `That is below absolute zero` |
| `UNKNOWN_COMMAND` | Programmer — the engine is handed an empty line. The CLI ignores blank lines, so only a direct engine call reaches this. | `Type a number or a command. Try help` |
| `UNKNOWN_COMMAND` | Programmer and Converter — `convert` with the wrong number of arguments: `convert 1 dec`, `convert 1 m`. | `Use: convert <value> <from> <to>` |
| `UNKNOWN_COMMAND` | Programmer — `NOT` with no operand or with extra words. | `Use: NOT <value>` |
| `UNKNOWN_COMMAND` | Programmer — a line that matches no pattern: `1 foo 2`, `5 AND`. | `Not a command. Try help` |
| `UNKNOWN_COMMAND` | Converter — the engine is handed an empty line. The CLI ignores blank lines, so only a direct engine call reaches this. | `Type a value, e.g. 100` |
| `UNKNOWN_COMMAND` | Converter — `list` with more than one argument. (The two spaces are part of the wording.) | `Use: list  or  list <category>` |
| `UNKNOWN_COMMAND` | Converter — a line that does not start with `convert` or `list` and is not exactly `<value> <from> <to>`: `foo bar`. | `Not a command. Try: convert 100 cm in` |
| `UNKNOWN_COMMAND` | Converter — `list <name>` where the name is not one of the twelve categories. | `'{input}' is not a category. Try: list` |
| `UNKNOWN_COMMAND` | Main menu and the converter's guided pickers — the typed answer matches no option and is not a one-line command. | `Pick one from the list` |

## Outside the spec code list

Both editions print `Error [INTERNAL]: <detail>` if an unexpected exception escapes an engine, and keep the prompt loop running. `INTERNAL` is not a spec §2.2 code, no shared test expects it, and a new language does not need to reproduce it.

## Where the editions differ

**Present in one edition only** (not in the table above; a new language does not need these):

| Edition | Code | Wording | Note |
|---|---|---|---|
| JavaScript | `INVALID_EXPRESSION` | `Unknown operator {op}` | Defensive branch for an AST node the parser cannot produce. Python's evaluator has no such branch. New languages do not need it. |
| JavaScript | `INVALID_EXPRESSION` | `Malformed expression` | Defensive branch for an unknown AST node type. Python's evaluator has no such branch. New languages do not need it. |

## What was compared

37 distinct wordings across 10 module pairs. Call sites found: 45 in JavaScript, 43 in Python. `python3 scripts/build-error-messages.py --verify` runs both engines on at least one example for each reachable wording and checks the real output against this table.
