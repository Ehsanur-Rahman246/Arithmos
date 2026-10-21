# Language Support

Runtime and delivery model for each completed edition. One row is added
when a language is marked complete. Progress for languages in progress is tracked in
[release-1.md §9](specifications/release-1.md).

## Release 1 editions

| Language | Version | Runtime | 64-bit integers | Delivery | Deviations |
|---|---|---|---|---|---|
| JavaScript (reference) | 0.2.0 | Node.js 20+ | `BigInt` + `asIntN(64, …)` | Standalone CLI, no dependencies | None |
| Python | 0.3.0 | Python 3.9+ | Mask with `2**64 − 1` and sign-convert | Standalone CLI, no dependencies | None |
| C | 0.4.0 | C99 compiler (gcc/clang) + libm | int64_t / uint64_t | Standalone CLI, no dependencies | None |

## Interface extras (not deviations)

- On a real terminal the menus and converter pickers are arrow-key selectors: ↑↓ move, Enter selects,
  Esc or `b` goes back, `q` quits. Any other printable key opens a typed line, so numbers, names, symbols
  and one-line commands still work. Pipes, files and tests get the same screens as numbered lists.
- `ARITHMOS_PLAIN=1` forces numbered lists on a real terminal (JavaScript, C).
- `NO_COLOR=1` disables colour.
- One-shot mode exits `0` on success, `1` on an `Error [CODE]` result, `2` on bad usage.