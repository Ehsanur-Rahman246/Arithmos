// Spec Section 2.2 — the 14 error codes. Tests assert on `code`, never on `message`.
export const ERROR_CODES = Object.freeze([
  'INVALID_EXPRESSION', 'INVALID_NUMBER', 'DIV_BY_ZERO', 'DOMAIN_ERROR',
  'UNDEFINED', 'OVERFLOW', 'INVALID_DIGIT', 'INVALID_BASE', 'OUT_OF_RANGE',
  'INVALID_SHIFT', 'UNKNOWN_UNIT', 'INCOMPATIBLE_UNITS', 'BELOW_ABSOLUTE_ZERO',
  'UNKNOWN_COMMAND',
]);

export class ArithmosError extends Error {
  constructor(code, message) {
    super(message ?? code);
    this.name = 'ArithmosError';
    this.code = code;
  }
}

export const fail = (code, message) => {
  throw new ArithmosError(code, message);
};

// CLI layer prints errors as a single line: `Error [CODE]: message`.
export const formatError = (err) => `Error [${err.code}]: ${err.message}`;
