// Prompt loops, tool bindings, the guided converter and the main menu.
// This file and io.dart are the only places that turn values into text.
import '../calculator/calculator.dart';
import '../converter/converter.dart';
import '../converter/units.dart';
import '../programmer/programmer.dart';
import '../shared/errors.dart';
import 'io.dart';
import 'pick.dart';

enum Leave { back, quit }

/// Run [f]; turn any error into its printable line. Unexpected exceptions become
/// Error [INTERNAL] so the loop never crashes (Release 1 goal 4).
String runGuarded(String Function() f) {
  try {
    return f();
  } on ArithmosError catch (e) {
    return e.toString();
  } catch (e) {
    return 'Error [INTERNAL]: $e';
  }
}

const _stdHelp = '''Operators: + - * / ^   unary + -   parentheses   % (postfix)   of
Functions: sqrt(x)  abs(x)    Previous result: ans
Examples:  2 + 3 * 4    20% of 150    200 + 10%    sqrt(16)    ans * 2
Commands:  help (or ?), back, quit''';

const _progHelp = '''A value shows in HEX, DEC, OCT and BIN. Prefixes: 0b 0o 0d 0x
base <bin|oct|dec|hex>      set the input base
[convert] <value> <from> <to>    e.g. convert 255 dec hex   or   255 dec hex
<a> AND|OR|XOR <b>     NOT <a>     <a> << n    <a> >> n (arithmetic)    <a> >>> n (logical)
Shift count is decimal 0-63. Values are 64-bit signed.
Commands:  help (or ?), back, quit''';

const _convHelp = '''One-line forms: convert 100 cm in   100 cm in   convert 1 km all   list   list length
Guided: pick a category, a "from" unit and a "to" unit, then type values.
Commands:  help (or ?), back (one step), quit''';

const _menuHelp = '''Pick with the arrow keys and Enter, or type a number or a name.
Esc/b goes back, q quits (at a list). Typed words: help, quit.''';

/// The calculator-style prompt loop shared by the Standard and Programmer tools.
Future<Leave> toolLoop(Io io, String prompt, String intro, String help,
    String Function(String line) handle) async {
  io.write('$intro\n');
  while (true) {
    final line = await io.readLine(prompt);
    if (line == null) return Leave.quit; // end of input exits cleanly
    final s = line.trim();
    if (s.isEmpty) continue; // blank input is ignored
    final lc = s.toLowerCase();
    if (lc == 'back') return Leave.back;
    if (lc == 'quit') return Leave.quit;
    if (lc == 'help' || lc == '?') {
      io.write('$help\n');
      continue;
    }
    io.write('${runGuarded(() => handle(s))}\n');
  }
}

Future<Leave> standardTool(Io io) {
  final calc = Calculator();
  return toolLoop(io, 'standard> ',
      'Standard Calculator — type an expression (help for commands).', _stdHelp, calc.evaluate);
}

Future<Leave> programmerTool(Io io) {
  final prog = Programmer();
  return toolLoop(io, 'programmer> ',
      'Programmer Calculator — 64-bit signed (help for commands).', _progHelp,
      (line) => prog.run(line).render());
}

String _cap(String s) => s[0].toUpperCase() + s.substring(1);

List<PickOption> _unitOptions(Category c) => [
      for (final u in c.units)
        PickOption(
          label: '${u.symbol} — ${u.name}', // e.g. "m — metre"
          value: u.symbol,
          names: [u.symbol, u.name.toLowerCase()],
        ),
    ];

/// Guided converter: category -> from -> to -> values. `back` steps back one stage
/// and leaves to the main menu from the first. One-line commands work everywhere.
Future<Leave> converterTool(Io io) async {
  final conv = Converter();
  Future<String?> cmd(String line) async =>
      Converter.looksLikeCommand(line) ? conv.run(line) : null;

  var stage = 0;
  late Category cat;
  late Unit from;
  late Unit to;
  while (true) {
    if (stage == 0) {
      final p = await pick(
        io,
        'Unit Converter — choose a category',
        [for (final c in categories) PickOption(label: c.name, value: c.name, names: [c.name])],
        back: true,
        command: cmd,
        help: _convHelp,
      );
      if (p.kind == PickKind.back) return Leave.back;
      if (p.kind != PickKind.chosen) return Leave.quit;
      cat = categories.firstWhere((c) => c.name == p.option!.value);
      stage = 1;
    } else if (stage == 1) {
      final p = await pick(io, '${_cap(cat.name)} — convert from', _unitOptions(cat),
          back: true, command: cmd, help: _convHelp);
      if (p.kind == PickKind.back) {
        stage = 0;
        continue;
      }
      if (p.kind != PickKind.chosen) return Leave.quit;
      from = cat.units.firstWhere((u) => u.symbol == p.option!.value);
      stage = 2;
    } else if (stage == 2) {
      final p = await pick(io, '${_cap(cat.name)} — convert from ${from.symbol} to',
          _unitOptions(cat), back: true, command: cmd, help: _convHelp);
      if (p.kind == PickKind.back) {
        stage = 1;
        continue;
      }
      if (p.kind != PickKind.chosen) return Leave.quit;
      to = cat.units.firstWhere((u) => u.symbol == p.option!.value);
      io.write('Type a value to convert (help, back, quit).\n');
      stage = 3;
    } else {
      // Values prompt: the units are shown in the prompt (spec 5.1).
      final line = await io.readLine('converter (${from.symbol} → ${to.symbol})> ');
      if (line == null) return Leave.quit;
      final s = line.trim();
      if (s.isEmpty) continue;
      final lc = s.toLowerCase();
      if (lc == 'back') {
        stage = 2;
        continue;
      }
      if (lc == 'quit') return Leave.quit;
      if (lc == 'help' || lc == '?') {
        io.write('$_convHelp\n');
        continue;
      }
      // One word (other than `list`) is a value for the chosen units; anything
      // longer is a full one-line command.
      final single = !s.contains(RegExp(r'\s')) && lc != 'list';
      io.write('${runGuarded(() => single ? conv.guided(s, from, to) : conv.run(s))}\n');
    }
  }
}

/// Main menu (spec 2.1). Returns when the user exits or input ends.
Future<void> runMenu(Io io) async {
  const options = [
    PickOption(
        label: 'Standard Calculator',
        value: 'standard',
        names: ['standard calculator', 'standard', 'std'],
        number: '1'),
    PickOption(
        label: 'Programmer Calculator',
        value: 'programmer',
        names: ['programmer calculator', 'programmer', 'prog'],
        number: '2'),
    PickOption(
        label: 'Unit Converter',
        value: 'converter',
        names: ['unit converter', 'converter', 'convert'],
        number: '3'),
    PickOption(label: 'Exit', value: 'exit', names: ['exit'], number: '0'),
  ];
  while (true) {
    final p = await pick(io, 'Arithmos 1.0 — Core CLI', options,
        back: false, quit: true, help: _menuHelp);
    if (p.kind != PickKind.chosen) return; // quit or end of input
    final Leave r;
    switch (p.option!.value) {
      case 'standard':
        r = await standardTool(io);
      case 'programmer':
        r = await programmerTool(io);
      case 'converter':
        r = await converterTool(io);
      default:
        return; // Exit
    }
    if (r == Leave.quit) return;
  }
}