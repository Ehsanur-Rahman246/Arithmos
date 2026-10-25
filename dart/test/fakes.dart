// dart/test/fakes.dart
// Test doubles: a scripted Io, a fake keyboard and a fake screen.
import 'package:arithmos/src/cli/io.dart';
import 'package:arithmos/src/cli/keys.dart';
import 'package:arithmos/src/cli/selector.dart';

/// Io over canned lines. `selector: false` behaves like a pipe (numbered lists).
class ScriptedIo implements Io {
  final List<String> lines;
  final List<SelResult> selects;
  final bool selector;
  final StringBuffer out = StringBuffer();
  int readCalls = 0;
  int selectCalls = 0;

  ScriptedIo({List<String>? lines, List<SelResult>? selects, this.selector = false})
      : lines = lines ?? [],
        selects = selects ?? [];

  @override
  void write(String text) => out.write(text);

  @override
  Future<String?> readLine(String prompt, {String prefill = ''}) async {
    readCalls++;
    out.write('$prompt$prefill');
    if (lines.isEmpty) return null; // end of input
    return prefill + lines.removeAt(0);
  }

  @override
  bool get hasSelector => selector;

  @override
  Future<SelResult> select(SelOpts opts) async {
    selectCalls++;
    if (selects.isEmpty) return const SelResult(SelKind.abort);
    return selects.removeAt(0);
  }

  String get text => out.toString();
}

class FakeKeys implements KeySource {
  final List<Key> keys;
  bool entered = false;
  bool left = false;
  FakeKeys(this.keys);

  @override
  void enter() => entered = true;

  @override
  void leave() => left = true;

  @override
  Future<Key> readKey() async => keys.isEmpty ? const Key(KeyType.ctrlD) : keys.removeAt(0);
}

class FakeScreen implements Screen {
  final StringBuffer out = StringBuffer();
  int cols;
  int rows;
  @override
  final bool color;
  FakeScreen({this.cols = 80, this.rows = 40, this.color = false});

  @override
  void write(String s) => out.write(s);

  @override
  ({int cols, int rows}) size() => (cols: cols, rows: rows);

  String get text => out.toString();
}