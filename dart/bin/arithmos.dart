// Entry point: argv -> interactive menu or one-shot mode.
import 'dart:io';

import 'package:arithmos/src/cli/cli.dart';

Future<void> main(List<String> args) async {
  final code = await runMain(args);
  // Make sure piped output is written before the process ends.
  try {
    await stdout.flush();
    await stderr.flush();
  } catch (_) {}
  exit(code);
}