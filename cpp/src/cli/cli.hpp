// The only layer that does I/O. Streams are injected so sessions can be scripted in tests.
#pragma once

#include <iosfwd>
#include <string>
#include <vector>

namespace arithmos::cli {

class Terminal;

// Interactive menu. Returns the process exit status (0).
// terminal == nullptr -> numbered lists (pipes, files, tests, ARITHMOS_PLAIN=1).
// terminal != nullptr -> arrow-key selector (pass it only when terminal->interactive()).
int runInteractive(std::istream& in, std::ostream& out, Terminal* terminal = nullptr);

// One-shot mode: args = {"std"|"prog"|"convert"|"list"|"--help", ...}.
// Results and --help -> out; Error [CODE] lines and usage after bad input -> err (R31).
// Exit status: 0 success, 1 the line produced an Error [CODE], 2 bad usage.
int runOneShot(const std::vector<std::string>& args, std::ostream& out, std::ostream& err);

}  // namespace arithmos::cli