// Layer 4: pick(), one question with many answers. It uses the arrow-key selector when
// the io has one (real terminal) and numbered lists answered by typing everywhere else.
#pragma once

#include <cstddef>
#include <functional>
#include <string>
#include <vector>

#include "selector.hpp"

namespace arithmos::cli {

struct PickIo {
  std::function<void(const std::string&)> write;
  // Prints the prompt, reads one line. Returns false at end of input.
  std::function<bool(const std::string& prompt, std::string& line)> readLine;
  // Empty on pipes, files, tests and ARITHMOS_PLAIN=1 (numbered list only).
  std::function<SelectorOutcome(const std::string& title, const std::vector<Option>& options,
                                const SelectorConfig& cfg)> select;
};

enum class PickKind { Chosen, Back, Quit, Eof };

struct Pick {
  PickKind kind = PickKind::Eof;
  std::size_t index = 0;  // Chosen
};

using CommandHandler = std::function<void(const std::string&)>;

// Show the options and return the answer. A typed one-line command (`convert ...`, `list`,
// `<v> <from> <to>`) goes to `command` (may be empty), then the list is shown again.
// An unknown answer prints Error [UNKNOWN_COMMAND] and the list is shown again.
Pick pick(PickIo& io, const std::string& title, const std::vector<Option>& options,
          bool canBack, const CommandHandler& command);

// Run fn; any error is written as one "Error [CODE]: message" line. Returns true on success.
// Unexpected exceptions are caught too, so bad input never crashes (Release 1 goal 4).
bool guardedWrite(const std::function<void(const std::string&)>& write,
                  const std::function<void()>& fn);

}  // namespace arithmos::cli