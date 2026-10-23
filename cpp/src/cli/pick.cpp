#include "pick.hpp"

#include <exception>

#include "../shared/errors.hpp"
#include "../shared/text.hpp"

namespace arithmos::cli {
namespace {

enum class LineResult { Done, Again, AgainQuiet };

bool looksLikeCommand(const std::string& low) {
  const std::vector<std::string> w = text::words(low);
  return !w.empty() && (w[0] == "convert" || w[0] == "list" || w.size() == 3);
}

// Handle one typed answer (from the numbered list, or the rest of a line after a typed key).
LineResult handleLine(PickIo& io, const std::string& raw, const std::vector<Option>& options,
                      bool canBack, const CommandHandler& command, Pick& result) {
  const std::string line = text::trim(raw);
  if (line.empty()) return LineResult::AgainQuiet;  // blank lines are ignored
  const std::string low = text::lower(line);

  if (low == "quit") { result = Pick{PickKind::Quit, 0}; return LineResult::Done; }
  if (low == "back" && canBack) { result = Pick{PickKind::Back, 0}; return LineResult::Done; }
  if (low == "help" || low == "?") {
    io.write(std::string("Type a number or a name") + (canBack ? ", back" : "") + " or quit.\n");
    return LineResult::AgainQuiet;
  }
  for (std::size_t i = 0; i < options.size(); ++i) {
    const Option& o = options[i];
    if (low == text::lower(o.key) || low == text::lower(o.label) ||
        (!o.alias.empty() && low == text::lower(o.alias)) ||
        (!o.name.empty() && low == text::lower(o.name))) {
      result = Pick{PickKind::Chosen, i};
      return LineResult::Done;
    }
  }
  if (command && looksLikeCommand(low)) {
    guardedWrite(io.write, [&] { command(line); });
    return LineResult::Again;  // the list is shown again
  }
  io.write("Error [UNKNOWN_COMMAND]: Pick one from the list\n");
  return LineResult::Again;
}

}  // namespace

bool guardedWrite(const std::function<void(const std::string&)>& write,
                  const std::function<void()>& fn) {
  try {
    fn();
    return true;
  } catch (const ArithmosError& e) {
    write("Error [" + e.code() + "]: " + e.what() + "\n");
  } catch (const std::exception& e) {
    write(std::string("Error [INTERNAL]: ") + e.what() + "\n");
  }
  return false;
}

Pick pick(PickIo& io, const std::string& title, const std::vector<Option>& options,
          bool canBack, const CommandHandler& command) {
  const SelectorConfig cfg{canBack, true, true};
  bool show = true;  // numbered list only: reprint the list before the next prompt?

  for (;;) {
    std::string line;

    if (io.select) {
      // Arrow-key selector (real terminal).
      const SelectorOutcome o = io.select(title, options, cfg);
      switch (o.kind) {
        case SelectorOutcome::Kind::Chosen: return Pick{PickKind::Chosen, o.index};
        case SelectorOutcome::Kind::Back: return Pick{PickKind::Back, 0};
        case SelectorOutcome::Kind::Quit: return Pick{PickKind::Quit, 0};
        case SelectorOutcome::Kind::Abort: return Pick{PickKind::Eof, 0};
        case SelectorOutcome::Kind::Typed: break;
      }
      // A printable key switches to a typed line: the prompt shows the key and the rest
      // of the line is read.
      std::string rest;
      if (!io.readLine(std::string("> ") + o.ch, rest)) return Pick{PickKind::Eof, 0};
      line = std::string(1, o.ch) + rest;
    } else {
      // Numbered list (pipes, files, tests, ARITHMOS_PLAIN=1).
      if (show) {
        std::string listing = title + "\n";
        for (const Option& o : options) listing += "  " + o.key + ") " + o.label + "\n";
        io.write(listing);
      }
      show = true;
      if (!io.readLine("> ", line)) return Pick{PickKind::Eof, 0};
    }

    Pick result;
    switch (handleLine(io, line, options, canBack, command, result)) {
      case LineResult::Done: return result;
      case LineResult::Again: break;
      case LineResult::AgainQuiet: show = false; break;
    }
  }
}

}  // namespace arithmos::cli