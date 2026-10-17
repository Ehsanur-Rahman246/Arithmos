# Error Codes — JavaScript Edition

All errors are thrown as `ArithmosError { code, message }` (`src/shared/errors.js`) and printed by the CLI as:

```text
Error [CODE]: human-readable message
```

Tests check **code**, never message text. The list below must match spec Section 2.2 exactly.

| Code | Raised by | Example |
|---|---|---|
| `INVALID_EXPRESSION` | calculator tokenizer/parser | `(2 + 3`, `2 +`, `2(3)`, `abc` |
| `INVALID_NUMBER` | programmer parse, converter | `convert abc m cm`, garbage literal |
| `DIV_BY_ZERO` | calculator evaluator | `10 / 0`, `0^-1` |
| `DOMAIN_ERROR` | calculator evaluator | `sqrt(-1)`, `(-8)^(1/3)` |
| `UNDEFINED` | calculator evaluator | `0^0` |
| `OVERFLOW` | formatNumber, evaluator, converter | `10^400` |
| `INVALID_DIGIT` | programmer parse | `convert 102 bin dec` |
| `INVALID_BASE` | programmer `base` command | `base xyz` |
| `OUT_OF_RANGE` | programmer parse | `9223372036854775808` |
| `INVALID_SHIFT` | programmer operations | `1 << 64`, `1 << -1` |
| `UNKNOWN_UNIT` | converter lookup | `convert 5 xyz m` |
| `INCOMPATIBLE_UNITS` | converter | `convert 5 m kg` |
| `BELOW_ABSOLUTE_ZERO` | converter temperature | `convert -1 k c` |
| `UNKNOWN_COMMAND` | CLI repl | any unrecognized command |

## Rules

- Every failure path in an engine throws one of these codes. Nothing else escapes to the user.
- NaN is never displayed: it is mapped to a code (`DOMAIN_ERROR`, `UNDEFINED`, or `INVALID_EXPRESSION`) before formatting.
- Infinity is always `OVERFLOW`.
- A failed standard-calculator line does not change `ans`.
- Messages may be reworded freely.
