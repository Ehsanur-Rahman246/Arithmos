// Arrow-key selector, layers 1-3 of ARCHITECTURE.md "CLI screens":
//   1. key handling   (pure)   handleKey()
//   2. drawing        (pure)   drawLines(), hintLine()
//   3. draw/read loop (injectable keyboard and screen)   runSelector()
// Layer 4 (pick) is in pick.hpp. Real terminal I/O is in terminal.hpp.
#pragma once

#include <cstddef>
#include <functional>
#include <string>
#include <vector>

namespace arithmos::cli {

// One row of a list. `key` is shown and typed ("1".."n", "0"); alias and name are extra
// typed answers (a unit symbol, a unit name, "std", ...).
struct Option {
  std::string key;
  std::string label;
  std::string alias;
  std::string name;
};

// ── Keys ─────────────────────────────────────────────────────────────
enum class Key { Up, Down, Home, End, PageUp, PageDown, Enter, Escape,
                 CtrlC, CtrlD, Char, Other };

struct KeyEvent {
  Key key = Key::Other;
  char ch = 0;  // only for Key::Char (printable ASCII)
};

// Which keys are on offer. q (quit) is always offered by pick(); back only below the main menu.
struct SelectorConfig {
  bool canBack = false;
  bool canQuit = true;
  bool typing = false;  // a printable key opens a typed line (number, name, symbol, command)
};

// Lists longer than this scroll (SL2). A short terminal can make the window smaller.
constexpr std::size_t kWindow = 10;

struct SelectorState {
  std::size_t index = 0;        // highlighted row
  std::size_t top = 0;          // first visible row
  std::size_t count = 0;        // number of rows
  std::size_t window = kWindow; // visible rows (kWindow, or fewer on a short terminal)
};

enum class Action { None, Move, Select, Back, Quit, Abort, Typed };

struct KeyResult {
  Action action = Action::None;
  char ch = 0;  // Action::Typed: the key that was pressed
};

// Layer 1 (pure): update the state for one key. Up/Down wrap, Home/End/PgUp/PgDn jump.
// Esc and b act only if canBack, q only if canQuit; Ctrl-C and Ctrl-D abort (end of input);
// other control keys are ignored; with typing on, any other printable key except space is Typed.
KeyResult handleKey(SelectorState& state, const SelectorConfig& cfg, const KeyEvent& key);

// Layer 2 (pure): the lines to draw: title, visible rows, scroll hints, key hint.
// The selected row starts with the pointer "❯"; with color it is also a full reverse-video bar.
// width > 0: no line is wider than `width` columns (longer lines end with "…"), so one
// logical line is always one screen line and the cursor-up redraw cannot miscount.
// width == 0: no limit.
std::vector<std::string> drawLines(const std::string& title, const std::vector<Option>& options,
                                   const SelectorState& state, const SelectorConfig& cfg,
                                   bool color, std::size_t width = 0);

// The hint line: lists only the keys on offer; shows "or type" when typing is on.
std::string hintLine(const SelectorConfig& cfg);

// Layer 3: injectable keyboard and screen.
struct SelIo {
  std::function<KeyEvent()> readKey;  // blocking; must return CtrlD at end of input
  std::function<void(const std::string&)> write;
  std::function<int()> columns;       // optional: terminal width  (empty = no limit)
  std::function<int()> rows;          // optional: terminal height (empty = default window)
  bool color = true;
};

struct SelectorOutcome {
  enum class Kind { Chosen, Back, Quit, Abort, Typed };
  Kind kind = Kind::Abort;
  std::size_t index = 0;  // Chosen
  char ch = 0;            // Typed
};

// Draw, read keys, redraw. Hides the cursor while active and always restores it. On Enter the
// list is replaced by "✔ <title>: <label>"; on every other result it is erased.
SelectorOutcome runSelector(SelIo& io, const std::string& title,
                            const std::vector<Option>& options, const SelectorConfig& cfg);

}  // namespace arithmos::cli