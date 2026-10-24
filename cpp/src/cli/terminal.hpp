// Real-terminal I/O: detects a terminal and reads single keys.
// POSIX: termios. Windows: _getch plus ANSI escape processing. The terminal is raw only
// while a key is being read, so it is never left raw (selector rule 5).
#pragma once

#include "selector.hpp"

namespace arithmos::cli {

class Terminal {
 public:
  // Decides whether the selector can be used: stdin and stdout are terminals, TERM is not
  // "dumb" (POSIX) and ARITHMOS_PLAIN is not "1". On Windows it also switches the console
  // to ANSI escape processing and restores the old mode in the destructor.
  Terminal();
  ~Terminal();
  Terminal(const Terminal&) = delete;
  Terminal& operator=(const Terminal&) = delete;

  bool interactive() const { return interactive_; }
  bool color() const { return color_; }  // false when NO_COLOR is set
  int columns() const;  // terminal width in columns (80 if it cannot be read)
  int rows() const;     // terminal height in rows (24 if it cannot be read)

  // Blocking read of one key. Returns CtrlD at end of input.
  KeyEvent readKey();

 private:
  bool interactive_ = false;
  bool color_ = true;
  unsigned long savedMode_ = 0;  // Windows console mode
  bool modeSaved_ = false;
};

}  // namespace arithmos::cli