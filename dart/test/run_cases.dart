// Loads the shared cases (docs/release-1-cases.json) and runs them, then the Dart
// extras: formatting boundaries, settled amendments (R1-R34), unit-table sanity,
// garbage input, scripted CLI sessions and one-shot exit codes.
//   dart run test/run_cases.dart ../docs/release-1-cases.json
import 'dart:convert';
import 'dart:io';

import 'package:arithmos/src/calculator/calculator.dart';
import 'package:arithmos/src/cli/cli.dart';
import 'package:arithmos/src/cli/tools.dart';
import 'package:arithmos/src/converter/converter.dart';
import 'package:arithmos/src/converter/units.dart';
import 'package:arithmos/src/programmer/programmer.dart';
import 'package:arithmos/src/shared/errors.dart';
import 'package:arithmos/src/shared/format_number.dart';

import 'fakes.dart';

int _pass = 0;
int _fail = 0;

void check(String name, bool ok, [String detail = '']) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    stderr.writeln('FAIL $name $detail');
  }
}

// ------------------------------------------------------------ shared cases

Object newSession(String tool) =>
    tool == 'standard' ? Calculator() : tool == 'programmer' ? Programmer() : Converter();

Object exec(String tool, Object session, String line) {
  if (tool == 'standard') return (session as Calculator).evaluate(line);
  if (tool == 'programmer') return (session as Programmer).run(line);
  return (session as Converter).run(line);
}

/// null = the outcome matched; otherwise a description of the mismatch.
String? verify(String tool, Object session, String line, Map<String, dynamic> o) {
  try {
    final res = exec(tool, session, line);
    if (o['error'] != null) return 'expected error ${o['error']}, got a result';
    final exp = o['expected'];
    if (exp is String) {
      final got = res is ProgResult ? res.render() : res as String;
      return got == exp ? null : 'expected "$exp", got "$got"';
    }
    if (exp is Map) {
      final r = res as ProgResult;
      for (final e in exp.entries) {
        if (r.bases?[e.key] != e.value) {
          return '${e.key}: expected ${e.value}, got ${r.bases?[e.key]}';
        }
      }
      return null;
    }
    final contains = o['expectedContains'];
    if (contains is List) {
      final lines = (res as String).split('\n');
      for (final c in contains) {
        if (!lines.contains(c)) return 'missing line "$c" in "$res"';
      }
      return null;
    }
    return 'case has no outcome';
  } on ArithmosError catch (e) {
    return o['error'] == e.code ? null : 'expected ${o['error'] ?? o['expected']}, got ${e.code}';
  }
}

void runShared(String path) {
  final cases = jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
  check('shared case count is 175', cases.length == 175, 'got ${cases.length}');
  for (final raw in cases) {
    final c = raw as Map<String, dynamic>;
    final id = c['id'] as String;
    final tool = c['tool'] as String;
    final session = newSession(tool);
    String? problem;
    if (c['steps'] != null) {
      for (final st in c['steps'] as List<dynamic>) {
        final m = st as Map<String, dynamic>;
        problem ??= verify(tool, session, m['input'] as String, m);
      }
    } else {
      for (final s in (c['setup'] as List<dynamic>? ?? [])) {
        exec(tool, session, s as String); // e.g. `base hex`
      }
      problem = verify(tool, session, c['input'] as String, c);
    }
    check('shared $id', problem == null, problem ?? '');
  }
}

// ------------------------------------------------------------------ extras

String codeOf(Object? Function() f) {
  try {
    f();
    return 'ok';
  } on ArithmosError catch (e) {
    return e.code;
  }
}

String calc(String s) => Calculator().evaluate(s);

String prog(String s, [String base = 'dec']) {
  final p = Programmer()..base = base;
  return p.run(s).render();
}

String pdec(String s, [String base = 'dec']) {
  final p = Programmer()..base = base;
  return p.run(s).bases!['DEC']!;
}

String conv(String s) => Converter().run(s);

void runExtras() {
  // --- number formatting boundaries (spec 2.3)
  final fmt = <double, String>{
    100000000000.5: '100000000001', // half away from zero
    1e15: '1e+15',
    999999999999999.0: '1e+15', // 999999999999999 rounds up to 1e15, so it prints in scientific notation.
    999999999999.0: '999999999999', // 12 digits: still plain
    99999999999.95: '99999999999.9', // rounds at the 12th digit, stays plain (see note below)
    1e-6: '0.000001',
    1e-7: '1e-7',
    -0.0: '0',
    0.1 + 0.2: '0.3',
    2.5: '2.5',
    1.5e20: '1.5e+20',
    2e-7: '2e-7',
    123456789012345.0: '123456789012000',
    -1234.5: '-1234.5',
    1 / 3: '0.333333333333',
  };
  fmt.forEach((v, want) => check('format $v', formatNumber(v) == want, 'got ${formatNumber(v)}'));
  check('format Infinity -> OVERFLOW', codeOf(() => formatNumber(double.infinity)) == 'OVERFLOW');
  check('format NaN -> INVALID_EXPRESSION',
      codeOf(() => formatNumber(double.nan)) == 'INVALID_EXPRESSION');

  // --- settled amendments (Standard)
  check('R1 200 + (10%)', calc('200 + (10%)') == '200.1');
  check('R2 200 + 5 * 10%', calc('200 + 5 * 10%') == '200.5');
  check('R3 2^50%', calc('2^50%') == '1.41421356237');
  check('R4 50%%', calc('50%%') == '0.005');
  check('R5 5 of 10', calc('5 of 10') == '50');
  check('R6 ANS case-insensitive', (Calculator()..ans = 7).evaluate('ANS + 1') == '8');
  check('R7 1e5', codeOf(() => calc('1e5')) == 'INVALID_EXPRESSION');
  check('R8 .', codeOf(() => calc('.')) == 'INVALID_EXPRESSION');
  check('R8 5.5.5', codeOf(() => calc('5.5.5')) == 'INVALID_EXPRESSION');
  check('R9 10^-400', calc('10^-400') == '0');
  check('5. and .5', calc('5. + .5') == '5.5');
  check('(-8)^(1/3)', codeOf(() => calc('(-8)^(1/3)')) == 'DOMAIN_ERROR');
  check('sqrt needs parens', codeOf(() => calc('sqrt 4')) == 'INVALID_EXPRESSION');
  check('of alone', codeOf(() => calc('of 5')) == 'INVALID_EXPRESSION');
  check('2 3 (no implicit mult)', codeOf(() => calc('2 3')) == 'INVALID_EXPRESSION');

  // --- settled amendments (Programmer)
  check('R11 A AND F in hex', prog('A AND F', 'hex').contains('HEX: A'));
  check('R11 DEC in hex mode', pdec('DEC', 'hex') == '3564');
  check('R11 FACE XOR BEEF', pdec('FACE XOR BEEF', 'hex') == '17441');
  check('R12 NOT 0xFF', pdec('NOT 0xFF') == '-256');
  check('R12 NOT -1', pdec('NOT -1') == '0');
  check('R13 1 << 0x3', codeOf(() => prog('1 << 0x3')) == 'INVALID_SHIFT');
  check('R13 1 << 2.5', codeOf(() => prog('1 << 2.5')) == 'INVALID_SHIFT');
  check('R14 -0x80', pdec('-0x80') == '-128');
  check('R15 convert FFFF.. hex dec', prog('convert FFFFFFFFFFFFFFFF hex dec') == '-1');
  check('R29 1<<3', pdec('1<<3') == '8');
  check('R29 -8>>>1', pdec('-8>>>1') == '9223372036854775804');
  check('R30 bare 0x in dec', codeOf(() => prog('0x')) == 'INVALID_DIGIT');
  check('R30 bare 0B in hex is 11', pdec('0B', 'hex') == '11');
  check('R32 base HEX', (Programmer()..base = 'dec').run('base HEX').render() == 'Input base: hex');
  check('-0x8000000000000000', pdec('-0x8000000000000000') == '-9223372036854775808');
  check('-0x8000000000000001 out of range',
      codeOf(() => prog('-0x8000000000000001')) == 'OUT_OF_RANGE');
  check('1 << 63 wraps', pdec('1 << 63') == '-9223372036854775808');
  check('1.5 is INVALID_NUMBER', codeOf(() => prog('1.5')) == 'INVALID_NUMBER');
  check('5 AND (missing)', codeOf(() => prog('5 AND')) == 'UNKNOWN_COMMAND');
  check('convert 1 dec', codeOf(() => prog('convert 1 dec')) == 'UNKNOWN_COMMAND');
  check('NOT alone', codeOf(() => prog('NOT')) == 'UNKNOWN_COMMAND');
  check('base alone', codeOf(() => prog('base')) == 'INVALID_BASE');

  // --- settled amendments (Converter)
  check('R16 1e3', codeOf(() => conv('convert 1e3 m cm')) == 'INVALID_NUMBER');
  check('R17 overflow result', codeOf(() => conv('convert 1e300 m cm')) == 'INVALID_NUMBER');
  check('R17 huge input', codeOf(() => conv('convert ${'9' * 400} m cm')) == 'OVERFLOW');
  check('R17 result overflow',
      codeOf(() => conv('convert ${'9' * 300} eb bit')) == 'OVERFLOW');
  check('R19 list foo', codeOf(() => conv('list foo')) == 'UNKNOWN_COMMAND');
  check('R20 0 k all ok', codeOf(() => conv('convert 0 k all')) == 'ok');
  check('R20 -273.15 c all ok', codeOf(() => conv('convert -273.15 c all')) == 'ok');
  check('R20 -459.67 f all ok', codeOf(() => conv('convert -459.67 f all')) == 'ok');
  check('R20 below zero all', codeOf(() => conv('convert -1 k all')) == 'BELOW_ABSOLUTE_ZERO');
  check('list is 12 categories', conv('list').split(', ').length == 12);
  check('list length has 15 units', conv('list length').split(', ').length == 15);
  check('5. value', conv('convert 5. m cm') == '500');

  // --- unit table sanity
  var total = 0;
  for (final c in categories) {
    total += c.units.length;
    if (c.name != 'temperature') {
      check('base unit of ${c.name} has factor 1',
          c.units.any((u) => u.symbol == c.base && u.factor == 1));
    }
  }
  check('12 categories', categories.length == 12);
  check('unit symbols are unique', unitIndex.length == total, '$total vs ${unitIndex.length}');
  check('all symbols are lower case', unitIndex.keys.every((k) => k == k.toLowerCase()));

  // --- garbage never crashes an engine (only ArithmosError may escape)
  final garbage = [
    '', ' ', '(((', ')))', '%%%', '1..2', '😀', 'sqrt', 'sqrt(', '\u0000', '9' * 400,
    '--1', '0x', '0b', '- -', '1 +* 2', '<<', '>>>', '1 << ', 'convert', 'list list list',
    '\t\t', '¿?', 'AND', 'NOT NOT 1', 'base base base', '1 2 3 4 5 6',
  ];
  for (final g in garbage) {
    for (final entry in <String, Object? Function()>{
      'std': () => Calculator().evaluate(g),
      'prog': () => Programmer().run(g),
      'conv': () => Converter().run(g),
    }.entries) {
      try {
        entry.value();
        check('garbage ${entry.key} "$g"', true);
      } on ArithmosError {
        check('garbage ${entry.key} "$g"', true);
      } catch (e) {
        check('garbage ${entry.key} "$g"', false, 'escaped: $e');
      }
    }
  }
}

// ------------------------------------------------- scripted sessions (plain)

Future<void> runSessions() async {
  // Main menu -> Standard -> back -> Programmer -> back -> Converter (guided) -> exit.
  final io = ScriptedIo(lines: [
    '1', '2 + 3 * 4', '10 / 0', 'ans * 2', 'back', //            standard
    '2', '5 AND 3', 'base hex', 'FF', 'back', //                 programmer
    '3', '1', 'm', 'yd', '100', 'list length', 'back', 'back', 'back', 'back', // converter
    '0', //                                                      Exit
  ]);
  await runMenu(io);
  final t = io.text;
  check('session: menu title', t.contains('Arithmos 1.0 — Core CLI'));
  check('session: numbered rows', t.contains('  1) Standard Calculator') && t.contains('  0) Exit'));
  check('session: 14', t.contains('standard> 14\n'));
  check('session: error printed', t.contains('Error [DIV_BY_ZERO]'));
  check('session: ans unchanged by the error', t.contains('standard> 28\n'));
  check('session: programmer table', t.contains('HEX: 1') && t.contains('DEC: 1'));
  check('session: base command', t.contains('Input base: hex'));
  check('session: hex input', t.contains('DEC: 255'));
  check('session: guided converter', t.contains('100 m = 109.361329834 yd'));
  check('session: unit row label', t.contains('  1) pm — picometre'));
  check('session: one-line command at values prompt', t.contains('pm, ang, nm, um'));
  check('session: converter prompt shows units', t.contains('converter (m → yd)> '));

  // End of input exits cleanly everywhere.
  await runMenu(ScriptedIo(lines: ['1']));
  await runMenu(ScriptedIo(lines: ['2']));
  await runMenu(ScriptedIo(lines: ['3', '1']));
  check('session: EOF is clean', true);

  // Unknown menu word -> error, list comes back; quit works.
  final io2 = ScriptedIo(lines: ['zzz', 'quit']);
  await runMenu(io2);
  check('session: unknown word', io2.text.contains('Error [UNKNOWN_COMMAND]: Pick one from the list'));
  check('session: list shown again', 'Arithmos 1.0 — Core CLI'.allMatches(io2.text).length == 2);
}

// ---------------------------------------------------------- one-shot mode

void runOneShot() {
  int run(List<String> a, StringBuffer o, StringBuffer e) => oneShot(a, o.write, e.write);

  var o = StringBuffer(), e = StringBuffer();
  check('one-shot std', run(['std', '2 + 3 * 4'], o, e) == 0 && o.toString() == '14\n');
  o = StringBuffer();
  e = StringBuffer();
  check('one-shot STANDARD case-insensitive', run(['STANDARD', '1+1'], o, e) == 0 && o.toString() == '2\n');
  o = StringBuffer();
  e = StringBuffer();
  check('one-shot error -> 1 on stderr',
      run(['std', '1 / 0'], o, e) == 1 && o.isEmpty && e.toString().startsWith('Error [DIV_BY_ZERO]'));
  o = StringBuffer();
  e = StringBuffer();
  check('one-shot prog', run(['prog', '0xFF', 'AND', '0x0F'], o, e) == 0 && o.toString().contains('DEC: 15'));
  o = StringBuffer();
  e = StringBuffer();
  check('one-shot convert',
      run(['convert', '100', 'cm', 'in'], o, e) == 0 && o.toString() == '39.3700787402\n');
  o = StringBuffer();
  e = StringBuffer();
  check('one-shot list length', run(['list', 'length'], o, e) == 0 && o.toString().startsWith('pm, ang'));
  o = StringBuffer();
  e = StringBuffer();
  check('one-shot bad usage -> 2', run(['frobnicate'], o, e) == 2 && e.toString().contains('Usage'));
  o = StringBuffer();
  e = StringBuffer();
  check('one-shot std without expression -> 2', run(['std'], o, e) == 2);
  o = StringBuffer();
  e = StringBuffer();
  check('one-shot --help -> stdout, 0', run(['--help'], o, e) == 0 && o.toString().contains('Usage'));
}

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty ? args[0] : '../docs/release-1-cases.json';
  runShared(path);
  runExtras();
  await runSessions();
  runOneShot();
  stdout.writeln('passed $_pass, failed $_fail');
  exit(_fail == 0 ? 0 : 1);
}