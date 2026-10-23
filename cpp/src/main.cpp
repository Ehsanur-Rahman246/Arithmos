// Entry point: no arguments -> interactive menu (arrow-key selector on a real terminal,
// numbered lists otherwise); with arguments -> one-shot mode.
#include <iostream>
#include <string>
#include <vector>

#include "cli/cli.hpp"
#include "cli/terminal.hpp"

#ifdef _WIN32
#include <windows.h>
#endif

int main(int argc, char** argv) {
#ifdef _WIN32
  // The output contains UTF-8 ("—", "→", "❯"): switch the console while we run, restore on exit.
  const UINT oldCodePage = GetConsoleOutputCP();
  SetConsoleOutputCP(CP_UTF8);
  struct Restore {
    UINT cp;
    ~Restore() { SetConsoleOutputCP(cp); }
  } restore{oldCodePage};
#endif
  const std::vector<std::string> args(argv + 1, argv + argc);
  if (!args.empty()) return arithmos::cli::runOneShot(args, std::cout, std::cerr);

  arithmos::cli::Terminal terminal;  // detects a real terminal; honours ARITHMOS_PLAIN=1
  return arithmos::cli::runInteractive(std::cin, std::cout,
                                       terminal.interactive() ? &terminal : nullptr);
}