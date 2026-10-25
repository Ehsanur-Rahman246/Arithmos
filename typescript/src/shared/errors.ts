// The 14 error codes of spec §2.2. Tests assert the code, never the message.
export type ErrorCode =
  | 'INVALID_EXPRESSION'
  | 'INVALID_NUMBER'
  | 'DIV_BY_ZERO'
  | 'DOMAIN_ERROR'
  | 'UNDEFINED'
  | 'OVERFLOW'
  | 'INVALID_DIGIT'
  | 'INVALID_BASE'
  | 'OUT_OF_RANGE'
  | 'INVALID_SHIFT'
  | 'UNKNOWN_UNIT'
  | 'INCOMPATIBLE_UNITS'
  | 'BELOW_ABSOLUTE_ZERO'
  | 'UNKNOWN_COMMAND';

/** Thrown by every engine. Only the CLI layer turns it into text. */
export class ArithmosError extends Error {
  readonly code: ErrorCode;

  constructor(code: ErrorCode, message: string) {
    super(message);
    this.name = 'ArithmosError';
    this.code = code;
  }
}

/** Throw an ArithmosError. Returns `never`, so TypeScript narrows after it. */
export function fail(code: ErrorCode, message: string): never {
  throw new ArithmosError(code, message);
}