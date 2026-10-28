// The 14 error codes of spec §2.2 (plus INTERNAL, outside the spec list).
enum ErrorCode: String {
    case invalidExpression = "INVALID_EXPRESSION"
    case invalidNumber = "INVALID_NUMBER"
    case divByZero = "DIV_BY_ZERO"
    case domainError = "DOMAIN_ERROR"
    case undefined = "UNDEFINED"
    case overflow = "OVERFLOW"
    case invalidDigit = "INVALID_DIGIT"
    case invalidBase = "INVALID_BASE"
    case outOfRange = "OUT_OF_RANGE"
    case invalidShift = "INVALID_SHIFT"
    case unknownUnit = "UNKNOWN_UNIT"
    case incompatibleUnits = "INCOMPATIBLE_UNITS"
    case belowAbsoluteZero = "BELOW_ABSOLUTE_ZERO"
    case unknownCommand = "UNKNOWN_COMMAND"
    case internalError = "INTERNAL"
}

/// Engines throw this; only the CLI layer turns it into text.
struct ArithmosError: Error {
    let code: ErrorCode
    let message: String
    init(_ code: ErrorCode, _ message: String) {
        self.code = code
        self.message = message
    }
    /// The one-line form shown to the user (spec §2.2).
    var line: String { "Error [\(code.rawValue)]: \(message)" }
}