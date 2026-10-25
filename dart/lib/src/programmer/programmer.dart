// Programmer Calculator. Dart's native int is a signed 64-bit two's-complement
// integer on the VM, so & | ^ ~ << >> >>> need no emulation. (Not for dart2js.)
// Literals are parsed with BigInt so range checks are exact.
import '../shared/errors.dart';

const _bases = {'bin': 2, 'oct': 8, 'dec': 10, 'hex': 16};

String _baseName(int radix) =>
    radix == 2 ? 'bin' : radix == 8 ? 'oct' : radix == 10 ? 'dec' : 'hex';

final _ws = RegExp(r'\s+');
// Spaces are optional around shift operators (amendment R29): 1<<3 == 1 << 3
final _shiftRe = RegExp(r'^(\S+?)\s*(>>>|>>|<<)\s*(\S+)$');

/// What one command produced. The CLI renders it; tests read the fields.
class ProgResult {
  final String? text; // convert result
  final Map<String, String>? bases; // HEX/DEC/OCT/BIN (in that order)
  final String? inputBase; // result of `base <name>`
  const ProgResult.single(this.text)
      : bases = null,
        inputBase = null;
  const ProgResult.table(this.bases)
      : text = null,
        inputBase = null;
  const ProgResult.baseSet(this.inputBase)
      : text = null,
        bases = null;

  String render() {
    if (text != null) return text!;
    if (inputBase != null) return 'Input base: $inputBase';
    return bases!.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }
}

/// Full 64-bit pattern, no minus sign (spec 4.4).
String _unsigned(int v, int radix) =>
    BigInt.from(v).toUnsigned(64).toRadixString(radix).toUpperCase();

int _digitValue(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x41 && c <= 0x5A) return c - 0x41 + 10;
  return c - 0x61 + 10; // a-z (caller guarantees alphanumeric)
}

/// Parse one literal. Order (spec 4.3): prefix -> digit check -> range.
int _parse(String raw, String inBase) {
  var s = raw;
  var neg = false;
  if (s.startsWith('-')) {
    neg = true;
    s = s.substring(1);
  }
  var radix = _bases[inBase]!;
  // A prefix counts only when something follows it (R30): `0B1` is binary 1 even
  // in hex mode, but a bare `0B` in hex mode is the number 11.
  if (s.length > 2 && s[0] == '0') {
    final p = s[1].toLowerCase();
    final pr = p == 'b' ? 2 : p == 'o' ? 8 : p == 'd' ? 10 : p == 'x' ? 16 : 0;
    if (pr != 0) {
      radix = pr;
      s = s.substring(2);
    }
  }
  if (s.isEmpty || !RegExp(r'^[0-9A-Za-z]+$').hasMatch(s)) {
    throw ArithmosError('INVALID_NUMBER', "'$raw' is not a number");
  }
  var mag = BigInt.zero;
  final r = BigInt.from(radix);
  for (final c in s.codeUnits) {
    final d = _digitValue(c);
    if (d >= radix) {
      throw ArithmosError('INVALID_DIGIT',
          "'${String.fromCharCode(c).toUpperCase()}' is not a ${_baseName(radix)} digit");
    }
    mag = mag * r + BigInt.from(d);
  }
  final two63 = BigInt.one << 63;
  final two64 = BigInt.one << 64;
  if (neg) {
    if (mag > two63) {
      throw const ArithmosError('OUT_OF_RANGE', 'That number does not fit in 64 bits');
    }
    return (-mag).toSigned(64).toInt();
  }
  if (radix == 10) {
    if (mag >= two63) {
      throw const ArithmosError('OUT_OF_RANGE', 'That number does not fit in 64 bits');
    }
    return mag.toInt();
  }
  // bin/oct/hex without a minus: a raw bit pattern, reinterpreted as signed.
  if (mag >= two64) {
    throw const ArithmosError('OUT_OF_RANGE', 'That number needs more than 64 bits');
  }
  return mag.toSigned(64).toInt();
}

/// Shift count: always a plain decimal 0..63, whatever the input base.
int _shiftCount(String t) {
  const msg = 'A shift count must be a whole number from 0 to 63';
  if (!RegExp(r'^\d+$').hasMatch(t) || BigInt.parse(t) > BigInt.from(63)) {
    throw const ArithmosError('INVALID_SHIFT', msg);
  }
  return int.parse(t);
}

class Programmer {
  String base = 'dec'; // current input base

  ProgResult run(String line) {
    final s = line.trim();
    if (s.isEmpty) {
      throw const ArithmosError('UNKNOWN_COMMAND', 'Type a number or a command. Try help');
    }

    // One operation per line: shifts first, since they may have no spaces.
    final sh = _shiftRe.firstMatch(s);
    if (sh != null) {
      final v = _parse(sh.group(1)!, base);
      final op = sh.group(2)!;
      final n = _shiftCount(sh.group(3)!);
      final r = op == '<<' ? v << n : op == '>>' ? v >> n : v >>> n;
      return _show(r);
    }

    final w = s.split(_ws);
    final first = w[0].toLowerCase();

    if (first == 'base') {
      if (w.length != 2) {
        throw const ArithmosError('INVALID_BASE', 'Use: base bin | oct | dec | hex');
      }
      final name = w[1].toLowerCase();
      if (!_bases.containsKey(name)) _badBase(w[1]);
      base = name;
      return ProgResult.baseSet(name);
    }

    if (first == 'convert') {
      if (w.length != 4) {
        throw const ArithmosError('UNKNOWN_COMMAND', 'Use: convert <value> <from> <to>');
      }
      return _convert(w[1], w[2], w[3]);
    }

    if (first == 'not') {
      if (w.length != 2) throw const ArithmosError('UNKNOWN_COMMAND', 'Use: NOT <value>');
      return _show(~_parse(w[1], base));
    }

    if (w.length == 1) return _show(_parse(w[0], base));

    if (w.length == 3) {
      // The operator is always the MIDDLE word, so hex words like FACE or DEC
      // are still numbers (R11).
      final m = w[1].toLowerCase();
      if (m == 'and' || m == 'or' || m == 'xor') {
        final a = _parse(w[0], base);
        final b = _parse(w[2], base);
        return _show(m == 'and' ? a & b : m == 'or' ? a | b : a ^ b);
      }
      // `255 dec hex`: the word `convert` is optional (R24).
      if (_bases.containsKey(m) && _bases.containsKey(w[2].toLowerCase())) {
        return _convert(w[0], m, w[2]);
      }
    }
    throw const ArithmosError('UNKNOWN_COMMAND', 'Not a command. Try help');
  }

  Never _badBase(String input) => throw ArithmosError(
      'INVALID_BASE', "'$input' is not a base. Use bin, oct, dec or hex");

  ProgResult _convert(String value, String from, String to) {
    final f = from.toLowerCase();
    final t = to.toLowerCase();
    if (!_bases.containsKey(f)) _badBase(from);
    if (!_bases.containsKey(t)) _badBase(to);
    final v = _parse(value, f); // uses the explicit FROM base
    return ProgResult.single(t == 'dec' ? v.toString() : _unsigned(v, _bases[t]!));
  }

  ProgResult _show(int v) => ProgResult.table({
        'HEX': _unsigned(v, 16),
        'DEC': v.toString(),
        'OCT': _unsigned(v, 8),
        'BIN': _unsigned(v, 2),
      });
}