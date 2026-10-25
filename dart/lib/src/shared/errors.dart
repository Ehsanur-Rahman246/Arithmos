// The one error type. Engines throw it; only the CLI layer turns it into text.

class ArithmosError implements Exception {
  final String code; // one of the 14 codes in spec 2.2
  final String message; // wording is not normative (tests check the code)
  const ArithmosError(this.code, this.message);

  @override
  String toString() => 'Error [$code]: $message';
}