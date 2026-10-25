// Unit Converter logic: value x from.factor / to.factor, temperature by formula.
// Pure logic: no stdin/stdout. Throws ArithmosError.
import '../shared/errors.dart';
import '../shared/format_number.dart';
import 'units.dart';

final _ws = RegExp(r'\s+');
// plain decimal only: 12  -5  5.  .5  +3   (no 1e3, no 1,000)
final _numRe = RegExp(r'^([+-]?)(\d*)(?:\.(\d*))?$');

class Converter {
  /// True when a typed line should be run as a one-line command rather than
  /// matched against a picker's options (convert..., list..., "<v> <from> <to>").
  static bool looksLikeCommand(String line) {
    final w = line.trim().split(_ws);
    final first = w[0].toLowerCase();
    return first == 'list' || first == 'convert' || w.length == 3;
  }

  /// Run one line: `convert 100 cm in`, `100 cm in`, `list`, `list length`.
  String run(String line) {
    final s = line.trim();
    if (s.isEmpty) throw const ArithmosError('UNKNOWN_COMMAND', 'Type a value, e.g. 100');
    final w = s.split(_ws);
    final first = w[0].toLowerCase();
    if (first == 'list') {
      if (w.length == 1) return categories.map((c) => c.name).join(', ');
      if (w.length == 2) {
        final name = w[1].toLowerCase();
        for (final c in categories) {
          if (c.name == name) return c.units.map((u) => u.symbol).join(', ');
        }
        throw ArithmosError('UNKNOWN_COMMAND', "'${w[1]}' is not a category. Try: list");
      }
      throw const ArithmosError('UNKNOWN_COMMAND', 'Use: list  or  list <category>');
    }
    if (first == 'convert') {
      if (w.length != 4) {
        throw const ArithmosError('UNKNOWN_COMMAND', 'Use: convert <value> <from> <to>');
      }
      return convert(w[1], w[2], w[3]);
    }
    if (w.length == 3) return convert(w[0], w[1], w[2]);
    throw const ArithmosError('UNKNOWN_COMMAND', 'Not a command. Try: convert 100 cm in');
  }

  /// Guided flow: the units are already chosen, the user typed only a value.
  String guided(String valueText, Unit from, Unit to) {
    final shown = formatNumber(parseValue(valueText));
    final result = convert(valueText, from.symbol, to.symbol);
    return '$shown ${from.symbol} = $result ${to.symbol}';
  }

  double parseValue(String text) {
    final m = _numRe.firstMatch(text);
    final ip = m?.group(2) ?? '';
    final fp = m?.group(3) ?? '';
    if (m == null || (ip.isEmpty && fp.isEmpty)) {
      throw ArithmosError('INVALID_NUMBER', "'$text' is not a number");
    }
    final v = double.parse('${m.group(1)}${ip.isEmpty ? '0' : ip}.${fp.isEmpty ? '0' : fp}');
    if (v.isInfinite) throw const ArithmosError('OVERFLOW', 'That number is too large');
    return v;
  }

  UnitRef _find(String symbol) {
    final r = unitIndex[symbol.toLowerCase()];
    if (r == null) {
      throw ArithmosError('UNKNOWN_UNIT', "'$symbol' is not a known unit. Try: list");
    }
    return r;
  }

  String convert(String valueText, String fromSym, String toSym) {
    final v = parseValue(valueText);
    final f = _find(fromSym);
    if (toSym.toLowerCase() == 'all') {
      // Compute every line first: any overflow fails the whole command (R18).
      final lines = <String>[];
      for (final u in f.cat.units) {
        lines.add('${u.symbol}: ${formatNumber(_conv(v, f.cat, f.unit, u))}');
      }
      return lines.join('\n');
    }
    final t = _find(toSym);
    if (!identical(f.cat, t.cat)) {
      throw ArithmosError('INCOMPATIBLE_UNITS', 'Cannot convert ${f.cat.name} to ${t.cat.name}');
    }
    return formatNumber(_conv(v, f.cat, f.unit, t.unit));
  }

  double _conv(double v, Category cat, Unit from, Unit to) {
    if (cat.name == 'temperature') return _temp(v, from.symbol, to.symbol);
    final r = v * from.factor / to.factor;
    if (r.isInfinite || r.isNaN) {
      throw const ArithmosError('OVERFLOW', 'Result is too large to represent');
    }
    return r;
  }

  // Temperature goes through degrees Celsius. Only the INPUT is checked against
  // absolute zero; a valid input cannot produce an invalid result, and checking
  // the result would let float noise reject -459.67 F.
  double _temp(double v, String from, String to) {
    final limit = from == 'c' ? -273.15 : from == 'f' ? -459.67 : 0.0;
    if (v < limit) {
      throw const ArithmosError('BELOW_ABSOLUTE_ZERO', 'That is below absolute zero');
    }
    final c = from == 'c' ? v : from == 'f' ? (v - 32) * 5 / 9 : v - 273.15;
    return to == 'c' ? c : to == 'f' ? c * 9 / 5 + 32 : c + 273.15;
  }
}