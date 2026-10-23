// Menus, prompt loops and tool bindings. Screens are built with pick() (pick.hpp), which
// uses the arrow-key selector on a real terminal and numbered lists everywhere else.
#include "cli.hpp"

#include <cctype>
#include <functional>
#include <iostream>

#include "../calculator/calculator.hpp"
#include "../converter/converter.hpp"
#include "../programmer/programmer.hpp"
#include "../shared/errors.hpp"
#include "../shared/format_number.hpp"
#include "../shared/text.hpp"
#include "pick.hpp"
#include "selector.hpp"
#include "terminal.hpp"

namespace arithmos::cli {
namespace {

using text::lower;
using text::trim;
using text::words;

enum class Flow { Back, Quit };

const char* const kStdHelp =
    "Standard Calculator\n"
    "  Expressions: 2 + 3 * 4   (1+2)^2   200 + 10%   20% of 150   sqrt(16)   abs(-3)   ans\n"
    "  help or ?   this text      back   main menu      quit   exit\n";

const char* const kProgHelp =
    "Programmer Calculator (64-bit signed)\n"
    "  <value>                    show in HEX, DEC, OCT, BIN (prefixes 0b 0o 0d 0x)\n"
    "  base <bin|oct|dec|hex>     set the input base\n"
    "  [convert] <value> <from> <to>    e.g. 255 dec hex\n"
    "  <a> AND|OR|XOR <b>    NOT <a>    <a> << n    <a> >> n    <a> >>> n   (n = decimal 0-63)\n"
    "  help or ?   this text      back   main menu      quit   exit\n";

const char* const kConvHelp =
    "Unit Converter\n"
    "  <value>                        convert with the chosen units\n"
    "  [convert] <value> <from> <to>  e.g. 100 cm in   (target 'all' lists every unit)\n"
    "  list    list <category>\n"
    "  help or ?   this text      back   previous screen      quit   exit\n";

const char* const kUsage =
    "Usage: arithmos                          interactive menu\n"
    "       arithmos std <expression>         e.g. std \"2 + 3 * 4\"\n"
    "       arithmos prog <command>           e.g. prog \"5 AND 3\"\n"
    "       arithmos convert <value> <from> <to>\n"
    "       arithmos list [category]\n";

// Run fn; print any error to `os` as one line. Returns true on success.
bool guarded(std::ostream& os, const std::function<void()>& fn) {
  return guardedWrite([&os](const std::string& s) { os << s; }, fn);
}

// Print the prompt and read one line. Returns false at end of input (after a newline).
bool readLine(std::istream& in, std::ostream& out, const std::string& prompt, std::string& line) {
  out << prompt << std::flush;
  if (!std::getline(in, line)) {
    out << "\n";
    return false;
  }
  if (!line.empty() && line.back() == '\r') line.pop_back();
  return true;
}

// The io that pick() talks to. With a terminal it also gets the arrow-key selector.
PickIo makePickIo(std::istream& in, std::ostream& out, Terminal* terminal) {
  PickIo io;
  io.write = [&out](const std::string& s) { out << s << std::flush; };
  io.readLine = [&in, &out](const std::string& prompt, std::string& line) {
    return readLine(in, out, prompt, line);
  };
  if (terminal != nullptr) {
    const auto write = io.write;
    io.select = [terminal, write](const std::string& title, const std::vector<Option>& options,
                                  const SelectorConfig& cfg) {
      SelIo sel;
      sel.readKey = [terminal] { return terminal->readKey(); };
      sel.write = write;
      sel.color = terminal->color();
      sel.columns = [terminal] { return terminal->columns(); };
      sel.rows = [terminal] { return terminal->rows(); };
      return runSelector(sel, title, options, cfg);
    };
  }
  return io;
}

// ─────────────────────────────── Prompt loop ───────────────────────────────

using LineHandler = std::function<void(const std::string&)>;

// help/?, back, quit, blank lines ignored, EOF exits cleanly, every error on one line.
// (Prompts read whole lines, so Esc is not available here: type back.)
Flow promptLoop(std::istream& in, std::ostream& out, const std::string& prompt,
                const char* help, const LineHandler& handle) {
  std::string line;
  while (readLine(in, out, prompt, line)) {
    line = trim(line);
    if (line.empty()) continue;
    const std::string low = lower(line);
    if (low == "quit") return Flow::Quit;
    if (low == "back") return Flow::Back;
    if (low == "help" || low == "?") { out << help; continue; }
    guarded(out, [&] { handle(line); });
  }
  return Flow::Quit;  // end of input
}

// ───────────────────────────────── Tools ───────────────────────────────────

Flow runStandard(std::istream& in, std::ostream& out) {
  out << "Standard Calculator — type an expression. help for commands.\n";
  calculator::Session session;
  return promptLoop(in, out, "standard> ", kStdHelp, [&](const std::string& line) {
    out << formatNumber(session.evaluate(line)) << "\n";
  });
}

Flow runProgrammer(std::istream& in, std::ostream& out) {
  out << "Programmer Calculator — 64-bit signed integers. help for commands.\n";
  programmer::Session session;
  return promptLoop(in, out, "programmer> ", kProgHelp, [&](const std::string& line) {
    out << programmer::render(session.run(line)) << "\n";
  });
}

std::string capitalize(std::string s) {
  if (!s.empty()) s[0] = static_cast<char>(std::toupper(static_cast<unsigned char>(s[0])));
  return s;
}

// Guided flow: category -> from -> to -> values. `back` (or Esc, b) steps back one stage and
// leaves to the main menu from the first. One-line commands work at every stage.
Flow runConverter(std::istream& in, std::ostream& out, PickIo& io) {
  enum class Stage { Category, From, To, Values };
  const auto& cats = converter::categories();
  Stage stage = Stage::Category;
  std::size_t ci = 0, fi = 0, ti = 0;  // category, from-unit, to-unit (ti == size means "all")

  const auto oneLine = [&](const std::string& line) { out << converter::run(line) << "\n"; };

  out << "Unit Converter — twelve categories, including temperature. help for commands.\n";

  for (;;) {
    if (stage == Stage::Category) {
      std::vector<Option> opts;
      for (std::size_t i = 0; i < cats.size(); ++i)
        opts.push_back({std::to_string(i + 1), cats[i].name, "", cats[i].name});
      const Pick p = pick(io, "Unit Converter — choose a category", opts, true, oneLine);
      if (p.kind == PickKind::Back) return Flow::Back;
      if (p.kind != PickKind::Chosen) return Flow::Quit;
      ci = p.index;
      stage = Stage::From;

    } else if (stage == Stage::From || stage == Stage::To) {
      const converter::Category& cat = cats[ci];
      std::vector<Option> opts;
      for (std::size_t i = 0; i < cat.units.size(); ++i)
        opts.push_back({std::to_string(i + 1), cat.units[i].symbol + " — " + cat.units[i].name,
                        cat.units[i].symbol, cat.units[i].name});
      std::string title = capitalize(cat.name) + " — convert from";
      if (stage == Stage::To) {
        title += " " + cat.units[fi].symbol + " to";
        opts.push_back({std::to_string(cat.units.size() + 1),
                        "all — every unit in this category", "all", "all"});
      }
      const Pick p = pick(io, title, opts, true, oneLine);
      if (p.kind == PickKind::Back) {
        stage = stage == Stage::From ? Stage::Category : Stage::From;
        continue;
      }
      if (p.kind != PickKind::Chosen) return Flow::Quit;
      if (stage == Stage::From) { fi = p.index; stage = Stage::To; }
      else { ti = p.index; stage = Stage::Values; }

    } else {
      const converter::Category& cat = cats[ci];
      const std::string fromSym = cat.units[fi].symbol;
      const std::string toSym = ti == cat.units.size() ? "all" : cat.units[ti].symbol;
      const std::string prompt = "converter (" + fromSym + " → " + toSym + ")> ";

      const Flow f = promptLoop(in, out, prompt, kConvHelp, [&](const std::string& line) {
        const auto w = words(line);
        if (w.size() == 1 && lower(w[0]) != "list") {  // a bare value, e.g. "100"
          const std::string result = converter::convert(w[0], fromSym, toSym);
          if (toSym == "all")
            out << result << "\n";
          else
            out << formatNumber(converter::parseValue(w[0])) << " " << fromSym << " = "
                << result << " " << toSym << "\n";
        } else {
          out << converter::run(line) << "\n";  // convert..., 100 cm in, list, list <category>
        }
      });
      if (f == Flow::Quit) return Flow::Quit;
      stage = Stage::To;  // back
    }
  }
}

}  // namespace

// ───────────────────────────── Public entry points ─────────────────────────────

int runInteractive(std::istream& in, std::ostream& out, Terminal* terminal) {
  PickIo io = makePickIo(in, out, terminal);

  const std::vector<Option> menu = {
      {"1", "Standard Calculator", "standard", "standard calculator"},
      {"2", "Programmer Calculator", "programmer", "programmer calculator"},
      {"3", "Unit Converter", "converter", "unit converter"},
      {"0", "Exit", "exit", "exit"}};

  for (;;) {
    const Pick p = pick(io, "Arithmos 1.0 — Core CLI", menu, false, nullptr);
    if (p.kind != PickKind::Chosen) return 0;  // quit or end of input
    Flow flow = Flow::Back;
    switch (p.index) {
      case 0: flow = runStandard(in, out); break;
      case 1: flow = runProgrammer(in, out); break;
      case 2: flow = runConverter(in, out, io); break;
      default: return 0;  // 0) Exit
    }
    if (flow == Flow::Quit) return 0;
  }
}

int runOneShot(const std::vector<std::string>& args, std::ostream& out, std::ostream& err) {
  if (args.empty()) { err << kUsage; return 2; }
  const std::string cmd = lower(args[0]);  // the command word is case-insensitive

  if (cmd == "--help" || cmd == "-h" || cmd == "help") { out << kUsage; return 0; }

  // Join the remaining arguments into one line: `prog 0xFF AND 0x0F` == `prog "0xFF AND 0x0F"`.
  std::string rest;
  for (std::size_t i = 1; i < args.size(); ++i) rest += (i > 1 ? " " : "") + args[i];

  enum class Tool { Standard, Programmer, Converter } tool;
  std::string line;
  if (cmd == "std" || cmd == "standard") {
    tool = Tool::Standard;
    line = rest;
    if (args.size() < 2) { err << kUsage; return 2; }
  } else if (cmd == "prog" || cmd == "programmer") {
    tool = Tool::Programmer;
    line = rest;
    if (args.size() < 2) { err << kUsage; return 2; }
  } else if (cmd == "convert") {
    tool = Tool::Converter;
    line = "convert " + rest;
    if (args.size() < 2) { err << kUsage; return 2; }
  } else if (cmd == "list") {
    tool = Tool::Converter;
    line = "list " + rest;  // "list" alone is valid
  } else {
    err << "Unknown command '" << args[0] << "'\n" << kUsage;
    return 2;
  }

  std::string result;
  const bool ok = guarded(err, [&] {
    switch (tool) {
      case Tool::Standard: {
        calculator::Session session;
        result = formatNumber(session.evaluate(line));
        break;
      }
      case Tool::Programmer: {
        programmer::Session session;
        result = programmer::render(session.run(line));
        break;
      }
      case Tool::Converter: result = converter::run(line); break;
    }
  });
  if (!ok) return 1;  // the Error [CODE] line is already on stderr
  out << result << "\n";
  return 0;
}

}  // namespace arithmos::cli