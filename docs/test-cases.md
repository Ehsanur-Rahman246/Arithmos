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

## Adding a case

1. Add it to the spec's Section 8 table with the next id.
2. Regenerate the JSON.
3. Run every completed edition. Every bug found in any language becomes a shared case.

Editions also keep their own non-shared tests (formatting boundaries, selector,
scripted CLI sessions). Those never replace shared cases.