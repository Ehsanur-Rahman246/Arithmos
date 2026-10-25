# Arithmos — TypeScript edition (Release 1)

Standard Calculator, Programmer Calculator and Unit Converter in TypeScript, Node.js standard
library only at run time. Follows [the Release 1 spec](../docs/specifications/release-1.md).
Checked against the JavaScript reference edition. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

**Status:** complete, passes all 175 shared cases and the selector tests SL1–SL21.
<!-- Only keep this line after `npm test` passes on your machine and the hand-test checklist is done. -->

## Prerequisites

- **Node.js 20 or newer** (developed for 22).
- **TypeScript 5.6+ and `@types/node`** as *build-time* devDependencies (`npm install` once).
  Nothing is imported at run time except Node's own modules. This is the only edition that needs
  `npm install`, because TypeScript has to be compiled.

## Run

From this folder:

```bash
npm install                                  # once: installs typescript and @types/node
npm start                                    # builds, then the interactive menu
node bin/arithmos.js std "20% of 150"        # one calculation        → 30
node bin/arithmos.js prog "0xFF AND 0x0F"    # one programmer command
node bin/arithmos.js convert 100 cm in       # one conversion         → 39.3700787402
node bin/arithmos.js list length
```

After the first `npm run build`, `node bin/arithmos.js` runs without rebuilding.

In any tool: `help` (or `?`) shows commands, `back` goes back, `quit` exits (all
case-insensitive). End-of-input exits cleanly. One-shot exit status: `0` success, `1` the line
produced an `Error [CODE]`, `2` bad usage. One-shot errors go to stderr; interactive errors go to
stdout.

## Test

```bash
npm test                  # build, then all three test files
npm run test:cases        # shared cases + extras
npm run test:selector     # SL1–SL21 + X2 + X3
npm run typecheck         # tsc --noEmit
```

| File | What it checks | Count |
|---|---|---|
| `test/run-cases.test.ts` | The shared cases, loaded from `../docs/release-1-cases.json` | 175 shared |
| `test/extras.test.ts` | Formatting boundaries, settled amendments, garbage input, one-shot exit codes, scripted sessions | extras |
| `test/select.test.ts` | Selector tests SL1–SL21 over a fake keyboard and screen, plus X2 and X3 | 21 + 2 |

Uses Node's built-in test runner (`node:test`) on the compiled output in `dist/test/`.

## Layout

```text
typescript/
├── package.json  tsconfig.json
├── bin/arithmos.js          launcher for dist/src/main.js
├── src/
│   ├── main.ts              entry point
│   ├── cli/                 cli.ts (menu, one-shot), tools.ts (prompt loops, guided converter),
│   │                        pick.ts, selector.ts, keys.ts, io.ts, style.ts, report.ts (the only I/O layer)
│   ├── calculator/          tokenizer.ts → parser.ts (AST) → evaluator.ts, index.ts (session)
│   ├── programmer/          int64.ts (model, output), parse.ts (literals), index.ts (commands)
│   ├── converter/           index.ts (logic) + units.ts (unit tables as data)
│   └── shared/              errors.ts, format-number.ts
└── test/                    fakes.ts, run-cases.test.ts, extras.test.ts, select.test.ts
```

Engines never read stdin or write stdout. They throw `ArithmosError` (code + message), so they can
be tested directly and reused by a later GUI. Only the `cli` layer turns values into text and
errors into `Error [CODE]: message`.

## How the hard parts are done

**64-bit integers.** Every value is a `bigint` normalized with `BigInt.asIntN(64, …)`. `>>>` and the
HEX/OCT/BIN display of negative values use `BigInt.asUintN(64, …)` (`src/programmer/int64.ts`).
Literals are accumulated digit by digit into a `bigint`, so range checks are exact
(`0xFFFFFFFFFFFFFFFF` is `-1`, `0x10000000000000000` is `OUT_OF_RANGE`) and nothing passes
through `number`.

**Decimal arithmetic and 12-digit formatting.** Standard Calculator and Converter use IEEE
`number`. `formatNumber` formats the magnitude with `toExponential(11)`, which rounds exact ties up
on the magnitude, i.e. half away from zero (spec §2.3), so `100000000000.5` gives `100000000001`. It
then trims zeros and picks plain or scientific notation from the rounded exponent. Spec §3.4 percent
rules: a `%` that is the *direct* right operand of `+` / `-` is relative; the parser wraps parentheses
in a `group` node, so `200 + (10%)` is plain.

## Interface

- **On a real terminal** (stdin and stdout are terminals, `TERM` is not `dumb`, and
  `ARITHMOS_PLAIN` is not `1`) the menus and converter pickers are arrow-key selectors:
  ↑↓ move (wrapping), Home/End/PgUp/PgDn jump, Enter selects, Esc or `b` goes back, `q` quits,
  Ctrl-C / Ctrl-D ends the input. Lists longer than 10 rows scroll. The selected row is a full
  reverse-video bar with `❯`; a chosen row leaves `✔ <title>: <label>` behind.
- **Typing still works.** Any other printable key opens a typed line (number, name, symbol or
  one-line command such as `100 cm in`). Names that start with `b` or `q` (`bit`, `byte`, `bar`,
  `btu`, `qt`) must be picked with the arrows or a number, because `b` and `q` act at once.
- **Everywhere else** (pipes, files, tests, dumb terminals) and with **`ARITHMOS_PLAIN=1`** the
  same screens are numbered lists (`  1) length`), answered by typing a number, a name or a symbol.
- `NO_COLOR=1` removes the colours (the `❯` pointer stays).
- Esc works in the selectors, and at the converter's values prompt. Other prompts read whole
  lines, so use `back` there. The line editor supports typing, Backspace and Enter only (no cursor
  movement or history).
- Every drawn line is at most (terminal width − 1) columns and the list window shrinks to fit the
  terminal height. Both are measured on every redraw, so resizing works.
- **Keys.** Raw stdin bytes are parsed by `parseKeys` (pure, test X3); a lone Esc is told from an
  arrow key because a terminal delivers an arrow as one chunk. One persistent key reader serves the
  whole session. Raw mode is on only while a selector or a line is being read, and is restored in a
  `finally` and by `exit` / SIGTERM / SIGHUP handlers, so the terminal is never left raw.
- **Windows.** Node's raw mode delivers the same VT sequences in cmd, PowerShell and Windows
  Terminal. Git Bash (mintty) is not a console: use `winpty node bin/arithmos.js`, otherwise the
  numbered lists are shown.
- The converter is the guided flow (category → from → to → values) with the units in the prompt.
  Unit rows read `m — metre`; a symbol or the name selects them.

## Deviations from the spec

None in behaviour. Build note: TypeScript must be compiled (`npm install`, then `npm run build`).

## Documentation

[Architecture](../ARCHITECTURE.md) · [Spec](../docs/specifications/release-1.md) ·
[Test cases](../docs/test-cases.md) · [Error messages](../docs/error-messages.md) ·
[Spec amendments](../docs/spec-amendments.md) · [Workflow](../docs/development-workflow.md)