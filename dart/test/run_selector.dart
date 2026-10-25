// Selector tests SL1-SL21 (same numbers as every edition), plus X2 and X3.
//   dart run test/run_selector.dart
import 'dart:io';

import 'package:arithmos/src/cli/keys.dart';
import 'package:arithmos/src/cli/pick.dart';
import 'package:arithmos/src/cli/selector.dart';

import 'fakes.dart';

int _pass = 0;
int _fail = 0;

void t(String id, bool ok, [String detail = '']) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    stderr.writeln('FAIL $id $detail');
  }
}

const up = Key(KeyType.up);
const down = Key(KeyType.down);
const enter = Key(KeyType.enter);
const esc = Key(KeyType.esc);

List<String> labels(int n) => [for (var i = 0; i < n; i++) 'item$i'];
String strip(String s) => s.replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '');

SelStep press(SelOpts o, SelState s, Key k, [int win = 10]) => handleKey(s, k, o, win);

Future<void> main() async {
  final o3 = SelOpts(title: 'T', labels: ['a', 'b', 'c'], back: true, quit: true, typing: true);
  final plain3 = SelOpts(title: 'T', labels: ['a', 'b', 'c'], back: false, quit: false, typing: false);

  // SL1 up/down move, wrap around, home/end
  t('SL1 up wraps', press(o3, const SelState(0, 0), up, 3).state.index == 2);
  t('SL1 down wraps', press(o3, const SelState(2, 0), down, 3).state.index == 0);
  t('SL1 end', press(o3, const SelState(0, 0), const Key(KeyType.end), 3).state.index == 2);
  t('SL1 home', press(o3, const SelState(2, 0), const Key(KeyType.home), 3).state.index == 0);

  // SL2 long lists scroll in a window of 10
  final big = SelOpts(title: 'T', labels: labels(25));
  var s = const SelState();
  for (var i = 0; i < 10; i++) {
    s = press(big, s, down).state;
  }
  t('SL2 scrolls by one', s.index == 10 && s.top == 1, '${s.index}/${s.top}');
  t('SL2 end shows the tail', press(big, const SelState(), const Key(KeyType.end)).state.top == 15);
  t('SL2 window is 10', windowSize(25, 40) == 10 && windowSize(5, 40) == 5);

  // SL3 Enter selects; Esc / b / q only work when offered
  t('SL3 enter', press(o3, const SelState(1, 0), enter, 3).result.kind == SelKind.chosen &&
      press(o3, const SelState(1, 0), enter, 3).result.index == 1);
  t('SL3 esc not offered', press(plain3, const SelState(), esc, 3).result.kind == SelKind.none);
  t('SL3 b not offered', press(plain3, const SelState(), const Key.char('b'), 3).result.kind == SelKind.none);
  t('SL3 q not offered', press(plain3, const SelState(), const Key.char('q'), 3).result.kind == SelKind.none);

  // SL4 Ctrl-C / Ctrl-D abort; other control keys are ignored
  t('SL4 ctrl-c', press(plain3, const SelState(), const Key(KeyType.ctrlC), 3).result.kind == SelKind.abort);
  t('SL4 ctrl-d', press(plain3, const SelState(), const Key(KeyType.ctrlD), 3).result.kind == SelKind.abort);
  t('SL4 other ignored', press(plain3, const SelState(), const Key(KeyType.other), 3).result.kind == SelKind.none);

  // SL5 typing on: a printable key ends the selector and carries the character
  final typ = SelOpts(title: 'T', labels: ['a', 'b'], typing: true);
  final r5 = press(typ, const SelState(), const Key.char('x'), 3).result;
  t('SL5 typed', r5.kind == SelKind.typed && r5.ch == 'x');

  // SL6 typing off: printable keys are ignored
  t('SL6 typing off', press(plain3, const SelState(), const Key.char('x'), 3).result.kind == SelKind.none);

  // SL7 typing on: Esc, b, q, arrows and Enter keep their meaning
  t('SL7 esc', press(o3, const SelState(), esc, 3).result.kind == SelKind.back);
  t('SL7 b', press(o3, const SelState(), const Key.char('b'), 3).result.kind == SelKind.back);
  t('SL7 q', press(o3, const SelState(), const Key.char('q'), 3).result.kind == SelKind.quit);
  t('SL7 arrow', press(o3, const SelState(), down, 3).state.index == 1);
  t('SL7 enter', press(o3, const SelState(), enter, 3).result.kind == SelKind.chosen);

  // SL8 typing on: space and control keys do not start a typed line
  t('SL8 space', press(o3, const SelState(), const Key.char(' '), 3).result.kind == SelKind.none);
  t('SL8 control', press(o3, const SelState(), const Key(KeyType.other), 3).result.kind == SelKind.none);

  // SL9 the selected row is highlighted as a full bar
  final l9 = drawLines(o3, const SelState(1, 0), 30, 40, true);
  final bar = l9.firstWhere((l) => l.startsWith('\x1b[7m'));
  t('SL9 full bar', strip(bar).length == 29 && strip(bar).startsWith('❯ b'), strip(bar));

  // SL10 plain mode still marks the selected row with the pointer
  final l10 = drawLines(o3, const SelState(1, 0), 30, 40, false);
  t('SL10 pointer', l10.contains('❯ b') && l10.every((l) => !l.contains('\x1b')), '$l10');

  // SL11 hint line lists only the keys on offer
  final h11 = hint(plain3);
  t('SL11 minimal hint', h11.contains('↑↓ move') && h11.contains('Enter select') &&
      !h11.contains('Esc/b') && !h11.contains('q quit') && !h11.contains('or type'), h11);

  // SL12 hint shows Esc/b back and "or type" when typing is on
  final h12 = hint(o3);
  t('SL12 full hint', h12.contains('Esc/b back') && h12.contains('q quit') && h12.contains('or type'), h12);

  // SL13 loop: keys in, index out, summary left behind, cursor restored
  final k13 = FakeKeys([down, enter]);
  final s13 = FakeScreen();
  final r13 = await runSelector(o3, k13, s13);
  t('SL13 index out', r13.kind == SelKind.chosen && r13.index == 1);
  t('SL13 summary', s13.text.contains('✔ T: b'));
  t('SL13 cursor restored', s13.text.endsWith('\x1b[?25h') && s13.text.contains('\x1b[?25l'));
  t('SL13 raw mode left', k13.entered && k13.left);

  // SL14 loop: Esc, ignored keys, Ctrl-C
  final r14 = await runSelector(o3, FakeKeys([const Key(KeyType.other), esc]), FakeScreen());
  t('SL14 esc', r14.kind == SelKind.back);
  final k14 = FakeKeys([const Key(KeyType.ctrlC)]);
  final r14b = await runSelector(o3, k14, FakeScreen());
  t('SL14 ctrl-c', r14b.kind == SelKind.abort && k14.left);

  // SL15 loop: a typed key returns its character and restores the cursor
  final s15 = FakeScreen();
  final r15 = await runSelector(o3, FakeKeys([const Key.char('z')]), s15);
  t('SL15 typed', r15.kind == SelKind.typed && r15.ch == 'z' && s15.text.endsWith('\x1b[?25h'));

  final opts = [
    const PickOption(label: 'length', value: 'length', names: ['length']),
    const PickOption(label: 'mass', value: 'mass', names: ['mass']),
  ];

  // SL16 pick() uses the selector when present and maps its results
  var io = ScriptedIo(selector: true, selects: [const SelResult(SelKind.chosen, 1)]);
  var p = await pick(io, 'T', opts, back: true);
  t('SL16 chosen', p.kind == PickKind.chosen && p.option!.value == 'mass');
  io = ScriptedIo(selector: true, selects: [const SelResult(SelKind.back)]);
  t('SL16 back', (await pick(io, 'T', opts, back: true)).kind == PickKind.back);
  io = ScriptedIo(selector: true, selects: [const SelResult(SelKind.quit)]);
  t('SL16 quit', (await pick(io, 'T', opts)).kind == PickKind.quit);
  io = ScriptedIo(selector: true, selects: [const SelResult(SelKind.abort)]);
  t('SL16 abort -> eof', (await pick(io, 'T', opts)).kind == PickKind.eof);

  // SL17 pick(): a typed name or number selects it
  io = ScriptedIo(selector: true, selects: [const SelResult(SelKind.typed, -1, 'l')], lines: ['ength']);
  p = await pick(io, 'T', opts);
  t('SL17 typed name', p.kind == PickKind.chosen && p.option!.value == 'length');
  io = ScriptedIo(selector: true, selects: [const SelResult(SelKind.typed, -1, '2')], lines: ['']);
  p = await pick(io, 'T', opts);
  t('SL17 typed number', p.kind == PickKind.chosen && p.option!.value == 'mass');

  // SL18 pick(): a typed one-line command runs and the list comes back
  io = ScriptedIo(
      selector: true,
      selects: [const SelResult(SelKind.typed, -1, '1'), const SelResult(SelKind.chosen, 0)],
      lines: ['00 cm in']);
  p = await pick(io, 'T', opts, command: (l) async => l == '100 cm in' ? 'OUT' : null);
  t('SL18 command output', io.text.contains('OUT\n'));
  t('SL18 list came back', io.selectCalls == 2 && p.kind == PickKind.chosen);

  // SL19 pick(): an unknown typed word is an error and the list comes back
  io = ScriptedIo(
      selector: true,
      selects: [const SelResult(SelKind.typed, -1, 'z'), const SelResult(SelKind.chosen, 0)],
      lines: ['z']);
  p = await pick(io, 'T', opts);
  t('SL19 error shown', io.text.contains('UNKNOWN_COMMAND'));
  t('SL19 list came back', io.selectCalls == 2 && p.kind == PickKind.chosen);

  // SL20 pick(): b, q and Esc act at once, with no prompt line
  io = ScriptedIo(selector: true, selects: [const SelResult(SelKind.back)]);
  p = await pick(io, 'T', opts, back: true);
  t('SL20 no prompt line', p.kind == PickKind.back && io.readCalls == 0);

  // SL21 pick(): without a selector (pipes) the numbered list works as before
  io = ScriptedIo(lines: ['2']);
  p = await pick(io, 'Title', opts);
  t('SL21 numbered list', p.kind == PickKind.chosen && p.option!.value == 'mass' &&
      io.text.contains('Title\n  1) length\n  2) mass\n'), io.text);
  io = ScriptedIo(lines: ['length']);
  t('SL21 by name', (await pick(io, 'T', opts)).option!.value == 'length');
  io = ScriptedIo(lines: ['quit']);
  t('SL21 quit word', (await pick(io, 'T', opts)).kind == PickKind.quit);
  io = ScriptedIo(lines: ['back']);
  t('SL21 back word', (await pick(io, 'T', opts, back: true)).kind == PickKind.back);
  io = ScriptedIo(lines: []);
  t('SL21 eof', (await pick(io, 'T', opts)).kind == PickKind.eof);

  // X2 lines never wider than the terminal; window shrinks on a short terminal;
  //    erase moves up by the drawn line count
  final wide = SelOpts(title: 'A very long title ' * 5, labels: ['x' * 100, 'short']);
  final l2 = drawLines(wide, const SelState(), 40, 40, false);
  t('X2 never wider than cols-1',
      l2.every((l) => l.runes.length <= 39) && l2.any((l) => l.endsWith('…')), '$l2');
  final shortSc = FakeScreen(cols: 40, rows: 8);
  await runSelector(big, FakeKeys([down, enter]), shortSc);
  final drawnLines = drawLines(big, const SelState(), 40, 8, false).length;
  t('X2 window shrinks', drawnLines == 7 && windowSize(25, 8) == 5, '$drawnLines');
  t('X2 erase moves up by drawn count', shortSc.text.contains('\x1b[${drawnLines}A'));

  // X3 raw terminal bytes become keys
  Key keyOf(List<int> bytes) {
    final rest = bytes.skip(1).toList();
    var i = 0;
    return decodeKey(bytes.first, () => i < rest.length ? rest[i++] : -2);
  }

  t('X3 up', keyOf([0x1b, 0x5b, 0x41]).type == KeyType.up);
  t('X3 down (SS3)', keyOf([0x1b, 0x4f, 0x42]).type == KeyType.down);
  t('X3 lone Esc', keyOf([0x1b]).type == KeyType.esc);
  t('X3 home', keyOf([0x1b, 0x5b, 0x48]).type == KeyType.home);
  t('X3 end', keyOf([0x1b, 0x5b, 0x46]).type == KeyType.end);
  t('X3 PgUp', keyOf([0x1b, 0x5b, 0x35, 0x7e]).type == KeyType.pageUp);
  t('X3 PgDn', keyOf([0x1b, 0x5b, 0x36, 0x7e]).type == KeyType.pageDown);
  t('X3 Home (1~)', keyOf([0x1b, 0x5b, 0x31, 0x7e]).type == KeyType.home);
  t('X3 modified arrow', keyOf([0x1b, 0x5b, 0x31, 0x3b, 0x35, 0x41]).type == KeyType.up);
  t('X3 ctrl-c / ctrl-d',
      keyOf([3]).type == KeyType.ctrlC && keyOf([4]).type == KeyType.ctrlD);
  t('X3 enter', keyOf([0x0d]).type == KeyType.enter);
  t('X3 letter', keyOf([0x78]).ch == 'x');
  t('X3 UTF-8 é', keyOf([0xC3, 0xA9]).ch == 'é');
  t('X3 control ignored', keyOf([0x01]).type == KeyType.other);

  stdout.writeln('passed $_pass, failed $_fail');
  exit(_fail == 0 ? 0 : 1);
}