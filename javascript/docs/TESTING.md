# Testing — JavaScript Edition

## Principles (spec Section 7)

- Tests assert **results and error codes**, not prompt text or terminal formatting.
- Every shared case in spec Section 8 must pass; the edition cannot be marked complete otherwise.
- Cases live in one language-neutral file so every language runs the same data.

## Layout

```text
docs/release-1-cases.json      (repo level, shared by all languages)
javascript/test/
├── helpers/load-cases.js      loads the shared JSON
├── standard.test.js           S1–S33
├── programmer.test.js         P1–P28
├── converter.test.js          C1–C109
├── shared.test.js             formatNumber edge cases, error-code list
└── cli.test.js                menu, help/back/quit, EOF, one-shot
```

## Running

```bash
npm test
npm run test:std
npm run test:prog
npm run test:conv
```

Uses Node's built-in runner (`node --test`), no dependencies.

## Shared case format

One JSON array in `docs/release-1-cases.json`. Each case:

```json
{ "id": "S1", "tool": "standard", "input": "25 + 17", "expected": "42" }
```

| Field | Meaning |
|---|---|
| `id` | Case id from spec Section 8 (`S1`, `P9`, `C37`, …) |
| `tool` | `standard`, `programmer`, or `converter` |
| `input` | The line typed at the prompt |
| `setup` | Optional lines run first (for example `["base hex"]` for P19) |
| `steps` | For multi-line cases (S32, S33): array of `{ input, expected }` / `{ input, error }` |
| `expected` | Expected output string, **or** an object for programmer cases, e.g. `{ "DEC": "-6", "HEX": "FFFFFFFFFFFFFFFA" }` |
| `expectedContains` | For `convert … all`: lines that must appear (for example `["m: 1000"]`) |
| `error` | Expected error code instead of a result |

Exactly one of `expected`, `expectedContains`, or `error` is present per case (or per step).

## Examples

```json
{ "id": "S3",  "tool": "standard",   "input": "10 / 0", "error": "DIV_BY_ZERO" }
{ "id": "P9",  "tool": "programmer", "input": "NOT 5",  "expected": { "DEC": "-6", "HEX": "FFFFFFFFFFFFFFFA" } }
{ "id": "C105","tool": "converter",  "input": "convert 1 km all", "expectedContains": ["m: 1000", "mi: 0.621371192237"] }
{ "id": "S33", "tool": "standard",   "steps": [
    { "input": "7", "expected": "7" },
    { "input": "10 / 0", "error": "DIV_BY_ZERO" },
    { "input": "ans", "expected": "7" } ] }
```

## Additional tests (not shared)

- `formatNumber`: 12-digit rounding, trailing-zero trimming, the `1e15` and `1e-6` boundaries, negative zero, tie rounding behavior of `toPrecision`.
- `ERROR_CODES`: equals the list in spec 2.2.
- Unit table integrity: every symbol unique across categories; every factor finite and positive.
- CLI: scripted-input sessions covering menu, `help`/`back`/`quit` in each tool, EOF, `UNKNOWN_COMMAND`, and invalid input not crashing.

## Adding a case

1. Add it to spec Section 8 (`docs/test-cases.md`) with the next id.
2. Add it to `docs/release-1-cases.json`.
3. Run `npm test` here, then in every other language edition.

Never add a case only to the JavaScript tests.

## Definition of done

- [ ] `npm test` passes with no skipped or `todo` shared cases
- [ ] No test asserts on message text
- [ ] Case ids in the JSON match spec Section 8 one-to-one
