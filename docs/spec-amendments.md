# Spec Amendments

Running log of ambiguities found in the Release 1 spec and how they were settled.
Release 1 spec §10 requires ambiguities to be resolved by amending the spec, not by
per-language behaviour.

**Checked on 2026-10-18** against the JavaScript and Python editions. Both editions
agree on every item marked "Settled". Settled items are **not yet shared test cases**,
so a new language is not forced to match them. Next step for each: amend the spec text
and add a case to Section 8.

| # | Topic | Question | Behaviour in both editions | Status |
|---|---|---|---|---|
| R1 | Percent | `200 + (10%)`: relative or plain? | Plain: `200.1` | Settled |
| R2 | Percent | `200 + 5 * 10%` | `10%` is `0.1`: `200.5` | Settled |
| R3 | Percent | `2^50%` | `%` binds tighter than `^`: `1.41421356237` | Settled |
| R4 | Percent | `50%%` | Allowed: `0.005` | Settled |
| R5 | `of` | `5 of 10` | Sugar for `*`: `50` | Settled |
| R6 | `ans` | Is `ANS` case-insensitive? | Yes | Settled |
| R7 | Tokenizer | `1e5` | `INVALID_EXPRESSION` | Settled |
| R8 | Number input | `.` / `5.5.5` | `INVALID_EXPRESSION` in the calculator; `INVALID_NUMBER` in the converter (`1e3`) | Settled |
| R9 | Overflow | `10^-400` | `0`, no error | Settled |
| R10 | Formatting | `100000000000.5` | `100000000001` (half away from zero) | Settled |
| R11 | Programmer | Hex input vs keywords (`A AND F`) | The operator is always the middle word; words made of hex digits are numbers: with `base hex`, `A AND F` → `A`, `DEC` → `3564`, `FACE XOR BEEF` → `4421`. A prefix still wins (`0B1` is binary `1`). Shared cases P31, P32 | Settled |
| R12 | Programmer | `NOT 0xFF`, `NOT -1` | Accepted: `-256`, `0` | Settled |
| R13 | Programmer | `1 << 0x3`, `1 << 2.5` | `INVALID_SHIFT` | Settled |
| R14 | Programmer | `-0x80` | Leading minus allowed with prefixes: `-128` | Settled |
| R15 | Programmer | `convert FFFFFFFFFFFFFFFF hex dec` | `-1` | Settled |
| R16 | Converter | `1e3` as a value | `INVALID_NUMBER` | Settled |
| R17 | Converter | Value so large the result is Infinity | `OVERFLOW`, for an over-large input and for an over-large result alike. Nothing is printed | Settled |
| R18 | Converter | `all` layout, overflow handling | `symbol: value` per line in table order, source unit included. Any overflow fails the whole command with `OVERFLOW`; no partial lines | Settled |
| R19 | Converter | `list foo` | `UNKNOWN_COMMAND` | Settled |
| R20 | Converter | Temperature `all` below absolute zero | `BELOW_ABSOLUTE_ZERO`; exactly at the limit (`0 k`, `-273.15 c`, `-459.67 f`) is allowed and lists all three | Settled |
| R21 | Shell | One-shot exit codes | Both editions use 0 / 1 / 2 | Settled (optional guidance) |
| R22 | Converter | Guided flow instead of a bare `converter>` prompt | Guided flow (category → from → to → values). The values prompt shows the units: `converter (m → yd)>`. One-line forms still work there. Amended in spec §5.1 | Settled |
| R23 | Shell | `back` semantics | `back` goes back one screen (so does Esc, where the edition reads single keys); from a tool's first screen it returns to the main menu. Amended in spec §2.1 | Settled |
| R24 | Programmer | Is `convert` optional? | Optional (`255 dec hex`). Amended in spec §4.5 | Settled |
| R25 | Shell | Help alias | `help` or `?` prints the command list. Amended in spec §2.1 | Settled |
| R26 | Shell | Error message wording | Both editions use identical wording. Wording is not normative (tests check codes only), but new languages should reuse it where the language allows | Settled |
| R27 | Shell | Optional arrow-key selector: keys | Esc / `b` back, `q` quit, other printable key opens a typed line (number, name, symbol or one-line command); plain mode unchanged. Same in JavaScript, Python and C | Settled |
| R28 | Shell | Converter screens | Titles: `Unit Converter — choose a category`, `<Category> — convert from`, `<Category> — convert from <unit> to`. Plain list rows: two spaces, the number, `)`, a space, the label (`  1) length`). The selected row is a full bar with `❯`; a chosen row leaves `✔ <title>: <label>` behind. Same in JavaScript, Python and C | Settled |

R22–R28 were behaviours of the reference edition that differed from the original
spec text. They are now spec behaviour, so every language implements them and none
is a deviation. R24 is also covered by shared cases P29, P30 and P32.