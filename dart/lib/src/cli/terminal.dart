// Real-terminal key sources. Dart has no raw-mode API with timeouts, so:
//   POSIX   : `stty` on /dev/tty (raw only while a selector is on screen) and libc
//             read() through dart:ffi. VMIN=0/VTIME=1 makes read() return after 0.1 s
//             with no data, which is how a lone Esc is told from an arrow key.
//   Windows : _getwch and the console mode through dart:ffi. _getwch reports Esc and
//             arrows as distinct codes, so no timing is needed.
// If anything here fails, ConsoleIo falls back to numbered lists.
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'keys.dart';
import 'selector.dart';

class PosixTerminal implements KeySource {
  late final int Function(int, Pointer<Uint8>, int) _read;
  late final Pointer<Uint8> _buf;
  String? _saved; // saved `stty -g` state; non-null = raw mode is on
  final List<StreamSubscription<ProcessSignal>> _subs = [];

  PosixTerminal() {
    final lib = DynamicLibrary.process(); // libc is already loaded
    _read = lib.lookupFunction<IntPtr Function(Int32, Pointer<Uint8>, IntPtr),
        int Function(int, Pointer<Uint8>, int)>('read');
    final malloc = lib.lookupFunction<Pointer<Void> Function(IntPtr),
        Pointer<Void> Function(int)>('malloc');
    _buf = malloc(16).cast<Uint8>();
  }

  @override
  void enter() {
    if (_saved != null) return;
    final g = Process.runSync('sh', ['-c', 'stty -g < /dev/tty']);
    final s = (g.stdout as String).trim();
    if (g.exitCode != 0 || !RegExp(r'^[A-Za-z0-9:=,._-]+$').hasMatch(s)) {
      throw StateError('cannot read the terminal state');
    }
    _saved = s;
    // -isig: Ctrl-C arrives as a key (byte 3) instead of killing the process.
    final r = Process.runSync('sh', ['-c', 'stty -icanon -echo -isig min 0 time 1 < /dev/tty']);
    if (r.exitCode != 0) {
      leave();
      throw StateError('cannot enter raw mode');
    }
    // SIGTERM / SIGHUP: restore the terminal, then exit. These handlers run because
    // readKey() yields to the event loop every few milliseconds.
    _watch(ProcessSignal.sigterm, 143);
    _watch(ProcessSignal.sighup, 129);
  }

  void _watch(ProcessSignal sig, int code) {
    try {
      _subs.add(sig.watch().listen((_) {
        leave();
        stdout.write('\x1b[?25h');
        exit(code);
      }));
    } catch (_) {}
  }

  @override
  void leave() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    final s = _saved;
    if (s == null) return;
    _saved = null;
    Process.runSync('sh', ['-c', 'stty $s < /dev/tty']);
  }

  @override
  Future<Key> readKey() async {
    var errors = 0;
    while (true) {
      final n = _read(0, _buf, 1); // returns 0 after 0.1 s without input
      if (n == 1) return decodeKey(_buf[0], _nextByte);
      if (n < 0 && ++errors > 5) return const Key(KeyType.ctrlD); // terminal gone
      await Future<void>.delayed(const Duration(milliseconds: 1)); // let signals run
    }
  }

  int _nextByte() {
    final n = _read(0, _buf, 1);
    return n == 1 ? _buf[0] : -2;
  }
}

class WindowsTerminal implements KeySource {
  late final int Function() _getwch;
  late final int Function(int) _getStdHandle;
  late final int Function(int, Pointer<Uint32>) _getMode;
  late final int Function(int, int) _setMode;
  late final int Function() _getOutCp;
  late final int Function(int) _setOutCp;
  late final Pointer<Uint32> _tmp;
  int _inH = 0;
  int _outH = 0;
  int? _savedIn;
  int? _savedOut;
  int? _savedCp;

  WindowsTerminal() {
    final k32 = DynamicLibrary.open('kernel32.dll');
    DynamicLibrary crt;
    try {
      crt = DynamicLibrary.open('ucrtbase.dll');
    } catch (_) {
      crt = DynamicLibrary.open('msvcrt.dll');
    }
    _getwch = crt.lookupFunction<Uint16 Function(), int Function()>('_getwch');
    final malloc = crt.lookupFunction<Pointer<Void> Function(IntPtr),
        Pointer<Void> Function(int)>('malloc');
    _tmp = malloc(8).cast<Uint32>();
    _getStdHandle = k32.lookupFunction<IntPtr Function(Uint32), int Function(int)>('GetStdHandle');
    _getMode = k32.lookupFunction<Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)>('GetConsoleMode');
    _setMode = k32.lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'SetConsoleMode');
    _getOutCp = k32.lookupFunction<Uint32 Function(), int Function()>('GetConsoleOutputCP');
    _setOutCp = k32.lookupFunction<Int32 Function(Uint32), int Function(int)>('SetConsoleOutputCP');
  }

  /// ANSI escapes + UTF-8 output while the program runs. False = no selector.
  bool prepareOutput() {
    try {
      _outH = _getStdHandle(4294967285); // STD_OUTPUT_HANDLE (-11)
      if (_getMode(_outH, _tmp) == 0) return false;
      _savedOut = _tmp.value;
      // 0x1 processed output | 0x4 virtual terminal processing
      if (_setMode(_outH, _savedOut! | 0x5) == 0) return false;
      _savedCp = _getOutCp();
      _setOutCp(65001);
      return true;
    } catch (_) {
      return false;
    }
  }

  void restoreOutput() {
    try {
      if (_savedOut != null) _setMode(_outH, _savedOut!);
      if (_savedCp != null) _setOutCp(_savedCp!);
    } catch (_) {}
  }

  @override
  void enter() {
    if (_savedIn != null) return;
    _inH = _getStdHandle(4294967286); // STD_INPUT_HANDLE (-10)
    if (_getMode(_inH, _tmp) == 0) throw StateError('no console input');
    final old = _tmp.value;
    // Clear ENABLE_PROCESSED_INPUT (0x1): Ctrl-C arrives as a key (code 3).
    if (_setMode(_inH, old & ~0x1) == 0) throw StateError('cannot change console mode');
    _savedIn = old;
  }

  @override
  void leave() {
    final old = _savedIn;
    if (old == null) return;
    _savedIn = null;
    _setMode(_inH, old);
  }

  @override
  Future<Key> readKey() async {
    await Future<void>.delayed(Duration.zero);
    final c = _getwch();
    if (c == 0xE0 || c == 0) {
      switch (_getwch()) {
        case 72:
          return const Key(KeyType.up);
        case 80:
          return const Key(KeyType.down);
        case 71:
          return const Key(KeyType.home);
        case 79:
          return const Key(KeyType.end);
        case 73:
          return const Key(KeyType.pageUp);
        case 81:
          return const Key(KeyType.pageDown);
      }
      return const Key(KeyType.other);
    }
    if (c == 27) return const Key(KeyType.esc);
    if (c == 3) return const Key(KeyType.ctrlC);
    if (c == 4) return const Key(KeyType.ctrlD);
    if (c == 13 || c == 10) return const Key(KeyType.enter);
    if (c < 32 || c == 127) return const Key(KeyType.other);
    if (c >= 0xD800 && c <= 0xDBFF) {
      return Key.char(String.fromCharCodes([c, _getwch()])); // surrogate pair
    }
    return Key.char(String.fromCharCode(c));
  }
}