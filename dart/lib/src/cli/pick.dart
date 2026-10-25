// pick(): one question, many answers (selector layer 4).
//   * With a selector: arrow-key list; any printable key opens a typed line.
//   * Without one (pipes, files, tests, ARITHMOS_PLAIN=1): a numbered list answered
//     by typing a number, a name or a symbol.
// A typed line is tried as: quit/back/help, number, name, then a one-line command.
import '../shared/errors.dart';
import 'io.dart';
import 'selector.dart';

class PickOption {
  final String label; // shown in the list
  final String value; // returned to the caller
  final List<String> names; // extra lower-case words that select it
  final String number; // explicit number ('' = position + 1); main menu uses '0' for Exit
  const PickOption({
    required this.label,
    required this.value,
    this.names = const [],
    this.number = '',
  });
}

enum PickKind { chosen, back, quit, eof }

class Picked {
  final PickKind kind;
  final PickOption? option;
  const Picked(this.kind, [this.option]);
}

/// Runs a typed one-line command. Returns the output text, or null when the line
/// is not a command. May throw ArithmosError for a command that failed.
typedef LineCommand = Future<String?> Function(String line);

Future<Picked> pick(
  Io io,
  String title,
  List<PickOption> options, {
  bool back = false,
  bool quit = true,
  LineCommand? command,
  String help = '',
}) async {
  final nums = [
    for (var i = 0; i < options.length; i++)
      options[i].number.isNotEmpty ? options[i].number : '${i + 1}',
  ];
  var showList = true; // plain mode: print the list now and after errors/commands

  while (true) {
    String? line;
    if (io.hasSelector) {
      final r = await io.select(SelOpts(
        title: title,
        labels: [for (final o in options) o.label],
        back: back,
        quit: quit,
      ));
      switch (r.kind) {
        case SelKind.chosen:
          return Picked(PickKind.chosen, options[r.index]);
        case SelKind.back:
          return const Picked(PickKind.back);
        case SelKind.quit:
          return const Picked(PickKind.quit);
        case SelKind.typed:
          // The prompt shows the key already typed; the rest of the line is read.
          line = await io.readLine('> ', prefill: r.ch);
          if (line == null) return const Picked(PickKind.eof);
        default:
          return const Picked(PickKind.eof); // Ctrl-C / Ctrl-D
      }
    } else {
      if (showList) {
        final b = StringBuffer('$title\n');
        for (var i = 0; i < options.length; i++) {
          b.write('  ${nums[i]}) ${options[i].label}\n');
        }
        io.write(b.toString());
        showList = false;
      }
      line = await io.readLine('> ');
      if (line == null) return const Picked(PickKind.eof);
    }

    final s = line.trim();
    if (s.isEmpty) continue; // blank input is ignored
    final lc = s.toLowerCase();
    if (lc == 'quit') return const Picked(PickKind.quit);
    if (lc == 'back' && back) return const Picked(PickKind.back);
    if (lc == 'help' || lc == '?') {
      io.write('$help\n');
      continue;
    }
    for (var i = 0; i < options.length; i++) {
      if (nums[i] == lc) return Picked(PickKind.chosen, options[i]);
    }
    for (final o in options) {
      if (o.names.contains(lc) || o.label.toLowerCase() == lc) {
        return Picked(PickKind.chosen, o);
      }
    }
    // Not an option: maybe a one-line command. The list comes back afterwards.
    try {
      final out = command == null ? null : await command(s);
      if (out != null) {
        io.write('$out\n');
        showList = true;
        continue;
      }
    } on ArithmosError catch (e) {
      io.write('$e\n');
      showList = true;
      continue;
    }
    io.write('Error [UNKNOWN_COMMAND]: Pick one from the list\n');
    showList = true;
  }
}