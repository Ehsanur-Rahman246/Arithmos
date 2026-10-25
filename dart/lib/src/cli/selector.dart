// The arrow-key selector in three layers (spec 2.1, tests SL1-SL15):
//   1. key handling (pure)   handleKey / moveTo / windowSize
//   2. drawing (pure)        drawLines / hint / fit
//   3. draw/read loop        runSelector over an injectable KeySource and Screen
// pick() (layer 4) lives in pick.dart.
import 'keys.dart';

const int selWindow = 10; // rows shown at once

class SelOpts {
  final String title;
  final List<String> labels;
  final bool back; // Esc and b mean back
  final bool quit; // q means quit
  final bool typing; // another printable key opens a typed line
  const SelOpts({
    required this.title,
    required this.labels,
    this.back = false,
    this.quit = true,
    this.typing = true,
  });
}

class SelState {
  final int index; // highlighted row
  final int top; // first visible row
  const SelState([this.index = 0, this.top = 0]);
}

enum SelKind { none, chosen, back, quit, abort, typed }

class SelResult {
  final SelKind kind;
  final int index; // for chosen
  final String ch; // for typed
  const SelResult(this.kind, [this.index = -1, this.ch = '']);
}

class SelStep {
  final SelState state;
  final SelResult result; // SelKind.none = keep going
  const SelStep(this.state, this.result);
}

/// Keyboard and screen are injected, so tests drive the loop with fakes.
abstract class KeySource {
  void enter(); // raw mode on (only while a selector is on screen)
  void leave(); // restore the terminal; safe to call twice
  Future<Key> readKey();
}

abstract class Screen {
  void write(String s);
  ({int cols, int rows}) size();
  bool get color;
}

// ------------------------------------------------------ layer 1: key handling

/// Window size: at most 10 rows, shrunk so title + rows + hint fit the terminal.
int windowSize(int n, int rows) {
  var w = n < selWindow ? n : selWindow;
  final avail = rows - 3;
  if (avail < w) w = avail;
  return w < 1 ? 1 : w;
}

/// Move the highlight to [idx] and scroll just enough to keep it visible.
SelState moveTo(SelState s, int idx, int n, int win) {
  var top = s.top;
  if (idx < top) top = idx;
  if (idx >= top + win) top = idx - win + 1;
  if (top > n - win) top = n - win;
  if (top < 0) top = 0;
  return SelState(idx, top);
}

SelStep handleKey(SelState s, Key k, SelOpts o, int win) {
  final n = o.labels.length;
  const none = SelResult(SelKind.none);
  SelStep go(int idx) => SelStep(moveTo(s, idx, n, win), none);

  switch (k.type) {
    case KeyType.up:
      return go((s.index - 1 + n) % n); // wraps
    case KeyType.down:
      return go((s.index + 1) % n);
    case KeyType.home:
      return go(0);
    case KeyType.end:
      return go(n - 1);
    case KeyType.pageUp:
      return go(s.index - win < 0 ? 0 : s.index - win);
    case KeyType.pageDown:
      return go(s.index + win > n - 1 ? n - 1 : s.index + win);
    case KeyType.enter:
      return SelStep(s, SelResult(SelKind.chosen, s.index));
    case KeyType.esc:
      return SelStep(s, o.back ? const SelResult(SelKind.back) : none);
    case KeyType.ctrlC:
    case KeyType.ctrlD:
      return SelStep(s, const SelResult(SelKind.abort));
    case KeyType.char:
      final lc = k.ch.toLowerCase();
      // b and q act at once, but only when offered.
      if (lc == 'b' && o.back) return SelStep(s, const SelResult(SelKind.back));
      if (lc == 'q' && o.quit) return SelStep(s, const SelResult(SelKind.quit));
      if (o.typing && k.printable) return SelStep(s, SelResult(SelKind.typed, -1, k.ch));
      return SelStep(s, none);
    case KeyType.other:
      return SelStep(s, none);
  }
}

// -------------------------------------------------------------- layer 2: draw

/// Cut a line to [max] columns; longer lines end with an ellipsis (rule 6).
String fit(String s, int max) {
  final r = s.runes.toList();
  if (r.length <= max) return s;
  if (max <= 1) return '…';
  return '${String.fromCharCodes(r.take(max - 1))}…';
}

/// The hint lists only the keys that are on offer.
String hint(SelOpts o) {
  final parts = <String>['↑↓ move', 'Enter select'];
  if (o.back) parts.add('Esc/b back');
  if (o.quit) parts.add('q quit');
  if (o.typing) parts.add('or type');
  return parts.join(' · ');
}

/// One logical line = one screen line: no line is wider than cols - 1.
List<String> drawLines(SelOpts o, SelState s, int cols, int rows, bool color) {
  final width = cols - 1 < 1 ? 1 : cols - 1;
  final n = o.labels.length;
  final win = windowSize(n, rows);
  final lines = <String>[];
  final title = fit(o.title, width);
  lines.add(color ? '\x1b[1m$title\x1b[0m' : title);
  for (var i = s.top; i < s.top + win && i < n; i++) {
    final sel = i == s.index;
    var text = fit('${sel ? '❯' : ' '} ${o.labels[i]}', width);
    // Selected row: a full reverse-video bar. Without colour the ❯ pointer remains.
    if (sel && color) text = '\x1b[7m${text.padRight(width)}\x1b[0m';
    lines.add(text);
  }
  final h = fit(hint(o), width);
  lines.add(color ? '\x1b[2m$h\x1b[0m' : h);
  return lines;
}

// ------------------------------------------------------------- layer 3: loop

Future<SelResult> runSelector(SelOpts o, KeySource kb, Screen sc) async {
  final n = o.labels.length;
  var state = const SelState();
  var drawn = 0; // lines currently on screen

  void draw() {
    final z = sc.size(); // measured on every redraw, so resizing works
    state = moveTo(state, state.index, n, windowSize(n, z.rows));
    final lines = drawLines(o, state, z.cols, z.rows, sc.color);
    sc.write(lines.map((l) => '$l\n').join());
    drawn = lines.length;
  }

  void erase() {
    // Move up by the number of lines drawn, then clear to the end of the screen.
    if (drawn > 0) sc.write('\x1b[${drawn}A\r\x1b[J');
    drawn = 0;
  }

  kb.enter();
  try {
    sc.write('\x1b[?25l'); // hide cursor
    draw();
    while (true) {
      final key = await kb.readKey();
      final z = sc.size();
      final step = handleKey(state, key, o, windowSize(n, z.rows));
      final r = step.result;
      if (r.kind == SelKind.none) {
        if (step.state.index != state.index || step.state.top != state.top) {
          state = step.state;
          erase();
          draw();
        }
        continue;
      }
      state = step.state;
      erase();
      if (r.kind == SelKind.chosen) {
        // A chosen row leaves a summary line behind.
        final w = sc.size().cols - 1;
        sc.write('${fit('✔ ${o.title}: ${o.labels[r.index]}', w)}\n');
      }
      return r;
    }
  } finally {
    sc.write('\x1b[?25h'); // cursor visible again, whatever happened
    kb.leave();
  }
}