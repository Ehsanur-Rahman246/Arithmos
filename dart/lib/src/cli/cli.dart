// Entry logic: no arguments -> interactive menu; otherwise one-shot mode.
// One-shot exit status: 0 success, 1 the line produced Error [CODE], 2 bad usage.
// Results and --help go to stdout; errors and usage-after-bad-input go to stderr (R31).
import 'dart:convert';
import 'dart:io';

import '../calculator/calculator.dart';
import '../converter/converter.dart';
import '../programmer/programmer.dart';
import '../shared/errors.dart';
import 'io.dart';
import 'tools.dart';

const usage = '''Arithmos 1.0 — Core CLI (Dart edition)
Usage:
  arithmos                          interactive menu
  arithmos std <expression>         one calculation        e.g. std "2 + 3 * 4"
  arithmos prog <command>           one programmer command e.g. prog 0xFF AND 0x0F
  arithmos convert <value> <from> <to>
  arithmos list [category]
Exit status: 0 success, 1 Error [CODE], 2 bad usage.''';

Future<int> runMain(List<String> args) async {
  try {
    stderr.encoding = utf8;
  } catch (_) {}
  if (args.isEmpty) {
    final io = ConsoleIo.detect();
    try {
      await runMenu(io);
    } finally {
      io.close();
    }
    return 0;
  }
  try {
    stdout.encoding = utf8;
  } catch (_) {}
  return oneShot(args, stdout.write, stderr.write);
}

/// One-shot mode, with injectable output so tests can capture it.
int oneShot(List<String> args, void Function(String) out, void Function(String) err) {
  final cmd = args[0].toLowerCase(); // the command word is case-insensitive
  final rest = args.sublist(1).join(' ').trim();

  int bad() {
    err('$usage\n');
    return 2;
  }

  String Function()? job;
  switch (cmd) {
    case '--help':
    case '-h':
    case 'help':
      out('$usage\n');
      return 0;
    case 'std':
    case 'standard':
      if (rest.isEmpty) return bad();
      job = () => Calculator().evaluate(rest);
    case 'prog':
    case 'programmer':
      if (rest.isEmpty) return bad();
      job = () => Programmer().run(rest).render();
    case 'convert':
      if (rest.isEmpty) return bad();
      job = () => Converter().run('convert $rest');
    case 'list':
      job = () => Converter().run(rest.isEmpty ? 'list' : 'list $rest');
    default:
      return bad();
  }
  try {
    out('${job()}\n');
    return 0;
  } on ArithmosError catch (e) {
    err('$e\n');
    return 1;
  } catch (e) {
    err('Error [INTERNAL]: $e\n');
    return 1;
  }
}