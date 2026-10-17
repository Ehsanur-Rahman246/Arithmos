# Specification Review Log — JavaScript Edition

Spec Section 10 requires the JavaScript reference implementation to be reviewed against the specification, with every ambiguity resolved **by amending the spec**, not by language-specific behavior.

This file is the working log. Each entry is decided once, written back into the spec (and a shared test case where possible), and then marked resolved.

## How to use

1. When implementation hits a situation the spec does not clearly cover, add an entry below.
2. Propose a decision. Prefer the behavior that matches the spec's stated principles.
3. Amend the spec and add a shared test case. Mark the entry resolved with the spec section changed.

## Open questions to settle before or during implementation

These are places where the current spec text can be read more than one way. They are listed up front so they get decided deliberately instead of by whichever language implements them first.

| # | Topic | Question | Suggested resolution | Status |
|---|---|---|---|---|
| R1 | Percent | Is `200 + (10%)` (parenthesized) relative like `200 + 10%`, or plain `0.1`? | Treat only a *directly attached* `%` as relative; parenthesized is plain division by 100. Add test. | Open |
| R2 | Percent | What does `200 + 5 * 10%` mean (right operand of `+` is a product)? | Not relative; `10%` is `0.1` inside `*`. Result `200.5`. Add test. | Open |
| R3 | Percent | Behavior of `%` with `^`, e.g. `2^50%` | `%` binds tighter than `^`, so `2^(0.5)`. Add test. | Open |
| R4 | Percent | Chained postfix `%`, e.g. `50%%` | Allowed, `0.005`; or `INVALID_EXPRESSION`. Pick one. | Open |
| R5 | `of` | Is `of` allowed after a non-percent operand, e.g. `5 of 10`? | Allowed as `5 * 10` per "sugar for `*`". Add test. | Open |
| R6 | `ans` | Is `ans` case-insensitive (`ANS`)? Spec 2.4 says keywords are. | Yes. Add test. | Open |
| R7 | Tokenizer | `1e5` currently tokenizes as `1` then `e5`; confirm the expected code. | `INVALID_EXPRESSION`. Add test. | Open |
| R8 | Number input | Does a lone `.` or `5.5.5` raise `INVALID_EXPRESSION` (calculator) or `INVALID_NUMBER` (converter/programmer)? | `INVALID_EXPRESSION` in calculator, `INVALID_NUMBER` elsewhere. Add tests. | Open |
| R9 | Overflow | `10^400` is `OVERFLOW`. What about results that underflow to `0`, e.g. `10^-400`? | Display `0` (no error). Add test. | Open |
| R10 | Formatting | Behavior of 12-digit rounding on exact binary ties (e.g. `100000000000.5`). | Half away from zero per spec 2.3. Add test. | Open |
| R11 | Programmer | Hex input in `base hex` where a value begins with a letter (`FF`, `AB`): how to tell it from a keyword? | Keywords are `AND OR XOR NOT`; none is a valid hex literal, so no clash. Add test for `A AND F` in hex. | Open |
| R12 | Programmer | Does `NOT` accept a prefixed literal (`NOT 0xFF`) and negative input (`NOT -1`)? | Yes, same literal rules as everywhere. Add tests. | Open |
| R13 | Programmer | Shift count rules for non-decimal text, e.g. `1 << 0x3` or `1 << 2.5` | Decimal integer only; anything else `INVALID_SHIFT`. Add tests. | Open |
| R14 | Programmer | `-0x80` / `-0b101`: is a leading minus allowed with prefixes? | Yes, negates the magnitude. Add test. | Open |
| R15 | Programmer | `convert` target `dec` for a negative input in bin/oct/hex without minus | Reinterpreted as signed (spec 4.3). Add test, e.g. `convert FFFFFFFFFFFFFFFF hex dec` → `-1`. | Open |
| R16 | Converter | Value token forms: is `1e3` accepted as a value? Spec says only plain decimals elsewhere. | `INVALID_NUMBER`. Add test. | Open |
| R17 | Converter | Value so large the result is `Infinity` (e.g. 400-digit number) | `OVERFLOW`. Add test. | Open |
| R18 | Converter | `all` output format: exact line layout, and whether units whose result is `OVERFLOW` are skipped or fail the whole command. | `symbol: value`, one per line; any overflow fails the whole command. Add test. | Open |
| R19 | Converter | `list <category>` with an unknown category | `UNKNOWN_COMMAND`, or a new code. Pick one. | Open |
| R20 | Converter | Temperature `all` when a result would fall below absolute zero | Cannot happen if the input is valid; document. | Open |
| R21 | Shell | One-shot exit codes (0/1/2) are idiomatic but not in the spec. | Add as optional guidance or leave language-specific. | Open |

## Resolved

| # | Resolution | Spec section changed | Test case added |
|---|---|---|---|
| — | — | — | — |

## Findings during implementation

Add new entries here with the same columns. Number them `R22`, `R23`, …
