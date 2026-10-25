// The one small io object every screen talks to (see ARCHITECTURE.md "CLI screens"):
// write, readLine (null at end of input) and, on real terminals only, select.
import 'dart:convert';
import 'dart:io';

import 'selector.dart';
import 'terminal.dart';

abstract class Io {
  void write(String text); // no newline is added
  Future<String?> readLine(String prompt, {String prefill = ''});
  bool get hasSelector; // false = numbered lists
  Future<SelResult> select(SelOpts opts); // only called when hasSelector
}

class StdScreen implements Screen {
  @override
  final bool color;
  StdScreen(this.color);

  @override
  void write(String s) => stdout.write(s);

  @override
  ({int cols, int rows}) size() {
    try {
      return (cols: stdout.terminalColumns, rows: stdout.terminalLines);
    } catch (_) {
      return (cols: 80, rows: 24);
    }
  }
}

class ConsoleIo implements Io {
  final KeySource? _keys;
  final Screen? _screen;
  final WindowsTerminal? _win;
  ConsoleIo._(this._keys, this._screen, this._win);

  /// Selector only on a real terminal (stdin AND stdout are terminals, TERM is not
  /// "dumb", ARITHMOS_PLAIN is not 1) and only if raw mode really works.
  /// NO_COLOR removes the colours; the ❯ pointer stays.
  factory ConsoleIo.detect() {
    try {
      stdout.encoding = utf8;
    } catch (_) {}
    final env = Platform.environment;
    final plain = env['ARITHMOS_PLAIN'] == '1';
    final real = stdin.hasTerminal && stdout.hasTerminal && !plain && env['TERM'] != 'dumb';
    if (!real) return ConsoleIo._(null, null, null);
    final color = (env['NO_COLOR'] ?? '').isEmpty;
    try {
      if (Platform.isWindows) {
        final w = WindowsTerminal();
        if (!w.prepareOutput()) return ConsoleIo._(null, null, null);
        w.enter(); // probe: does raw mode work here?
        w.leave();
        return ConsoleIo._(w, StdScreen(color), w);
      }
      final p = PosixTerminal();
      p.enter(); // probe: stty on /dev/tty must work
      p.leave();
      return ConsoleIo._(p, StdScreen(color), null);
    } catch (_) {
      return ConsoleIo._(null, null, null);
    }
  }

  @override
  void write(String text) => stdout.write(text);

  @override
  Future<String?> readLine(String prompt, {String prefill = ''}) async {
    stdout.write('$prompt$prefill');
    try {
      await stdout.flush(); // make sure the prompt is out before we block
    } catch (_) {}
    String? s;
    try {
      s = stdin.readLineSync(encoding: utf8);
    } on FormatException {
      s = ''; // undecodable bytes: treat as a blank line
    }
    if (s == null) {
      if (stdout.hasTerminal) stdout.write('\n'); // keep the shell prompt tidy
      return null;
    }
    return '$prefill$s';
  }

  @override
  bool get hasSelector => _keys != null;

  @override
  Future<SelResult> select(SelOpts opts) => runSelector(opts, _keys!, _screen!);

  /// Restore console state (Windows). Safe to call twice.
  void close() => _win?.restoreOutput();
}