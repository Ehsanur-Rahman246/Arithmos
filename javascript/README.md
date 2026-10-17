# Arithmos — JavaScript Edition (Release 1)

**Reference implementation** of Arithmos Release 1 in Node.js. Every other language edition is checked against this one, so any ambiguity found here is resolved by amending the specification, never by diverging (see [`docs/SPEC-REVIEW.md`](docs/SPEC-REVIEW.md)).

Behavior contract: [`../docs/specifications/release-1.md`](../docs/specifications/release-1.md) · Shared tests: [`../docs/test-cases.md`](../docs/test-cases.md)

## Status

| Std | Prog | Conv | Docs |
|:-:|:-:|:-:|:-:|
| ☐ | ☐ | ☐ | ◐ |

Legend: ☐ not started · ◐ in progress · ☑ complete and verified against Section 8 of the spec.
Update this table and the language table in the spec (Section 9) together.

## 1. Prerequisites

- **Node.js 20 or newer** (uses ES modules, `BigInt`, and the built-in `node:test` runner).
- No third-party dependencies. `npm install` is not required.

## 2. Build

None. The code runs directly from source.

## 3. Run

```bash
# Interactive menu (baseline required by the spec)
npm start
# or
node bin/arithmos.js

# One-shot mode
node bin/arithmos.js convert 100 cm in
node bin/arithmos.js std "25 + 17"
node bin/arithmos.js prog "5 AND 3"
```

See [`docs/USAGE.md`](docs/USAGE.md) for every command.

## 4. Test

```bash
npm test               # everything
npm run test:std       # Standard Calculator cases (S1–S33)
npm run test:prog      # Programmer Calculator cases (P1–P28)
npm run test:conv      # Unit Converter cases (C1–C109)
```

The tests load the shared cases from `../docs/release-1-cases.json`. See [`docs/TESTING.md`](docs/TESTING.md).

## 5. 64-bit signed integers

Programmer mode stores every value as a `BigInt` normalized with `BigInt.asIntN(64, …)`. Logical right shift (`>>>`) and the HEX/OCT/BIN display of negative values use `BigInt.asUintN(64, …)` to expose the raw 64-bit pattern. Details in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#programmer-calculator).

## 6. Decimal arithmetic and 12-digit formatting

Standard Calculator and Converter compute with IEEE 754 doubles (JavaScript `number`). Display is handled centrally by `src/shared/format-number.js`, which rounds to 12 significant digits (half away from zero), trims zeros, and applies the plain/scientific notation thresholds from spec Section 2.3. No computation code formats numbers itself.

## 7. Known deviations from the specification

None recorded yet. Any deviation must be listed in [`docs/DEVIATIONS.md`](docs/DEVIATIONS.md) with a reason, and copied to the Notes column in spec Section 9.

## 8. Non-standard delivery model

None. Standalone command-line program on Node.js.

## Documentation map

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layers, modules, data flow, design decisions |
| [`docs/FEATURES.md`](docs/FEATURES.md) | Feature checklist mirroring the spec's required-behavior lists |
| [`docs/USAGE.md`](docs/USAGE.md) | Commands, syntax, and examples for each tool |
| [`docs/ERROR-CODES.md`](docs/ERROR-CODES.md) | The 14 error codes and where each is raised |
| [`docs/TESTING.md`](docs/TESTING.md) | Shared case format, how to run, how to add cases |
| [`docs/DEVIATIONS.md`](docs/DEVIATIONS.md) | Deviations from the spec (required by Section 6) |
| [`docs/SPEC-REVIEW.md`](docs/SPEC-REVIEW.md) | Ambiguities found while implementing; feeds spec amendments |
| [`CHANGELOG.md`](CHANGELOG.md) | Change history of this edition |
