// Pure key model and byte decoding (selector layer 1). No I/O here.
import 'dart:convert';

enum KeyType { up, down, home, end, pageUp, pageDown, enter, esc, ctrlC, ctrlD, char, other }

class Key {
  final KeyType type;
  final String ch; // only for KeyType.char
  const Key(this.type, [this.ch = '']);
  const Key.char(this.ch) : type = KeyType.char;

  /// A key that may open a typed line: a visible character (not space).
  bool get printable => type == KeyType.char && ch.isNotEmpty && ch != ' ';
}

/// Turn raw terminal bytes into a key. [first] is the first byte already read;
/// [next] returns the next byte, or -2 when none arrives in time (a lone Esc).
Key decodeKey(int first, int Function() next) {
  final b = first;
  if (b == 0x1b) {
    final c = next();
    if (c == -2) return const Key(KeyType.esc);
    if (c != 0x5b && c != 0x4f) return const Key(KeyType.other); // Alt+key
    // CSI (ESC [) or SS3 (ESC O): parameters, then one final byte 0x40..0x7E.
    var params = '';
    while (true) {
      final d = next();
      if (d == -2) return const Key(KeyType.other);
      if (d >= 0x40 && d <= 0x7e) return _csiKey(String.fromCharCode(d), params);
      params += String.fromCharCode(d);
      if (params.length > 8) return const Key(KeyType.other);
    }
  }
  if (b == 0x03) return const Key(KeyType.ctrlC);
  if (b == 0x04) return const Key(KeyType.ctrlD);
  if (b == 0x0d || b == 0x0a) return const Key(KeyType.enter);
  if (b < 0x20 || b == 0x7f) return const Key(KeyType.other); // other control keys
  if (b < 0x80) return Key.char(String.fromCharCode(b));
  if (b >= 0xC0) {
    // UTF-8 lead byte: read the continuation bytes.
    final len = b >= 0xF0 ? 4 : b >= 0xE0 ? 3 : 2;
    final bytes = <int>[b];
    for (var i = 1; i < len; i++) {
      final c = next();
      if (c < 0) return const Key(KeyType.other);
      bytes.add(c);
    }
    return Key.char(utf8.decode(bytes, allowMalformed: true));
  }
  return const Key(KeyType.other); // stray continuation byte
}

Key _csiKey(String fin, String params) {
  switch (fin) {
    case 'A':
      return const Key(KeyType.up);
    case 'B':
      return const Key(KeyType.down);
    case 'H':
      return const Key(KeyType.home);
    case 'F':
      return const Key(KeyType.end);
    case '~':
      {
        final p = params.split(';').first;
        if (p == '1' || p == '7') return const Key(KeyType.home);
        if (p == '4' || p == '8') return const Key(KeyType.end);
        if (p == '5') return const Key(KeyType.pageUp);
        if (p == '6') return const Key(KeyType.pageDown);
        return const Key(KeyType.other);
      }
  }
  return const Key(KeyType.other);
}