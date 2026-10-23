// Selector tests SL1-SL21 (docs/test-cases.md). Same numbers and behaviours as the
// JavaScript, Python and C editions. Only behaviour is asserted.
// Needs only selector.cpp and pick.cpp (no terminal, no engines).
#include <deque>
#include <functional>
#include <iostream>
#include <string>
#include <vector>

#include "cli/pick.hpp"
#include "cli/selector.hpp"

using namespace arithmos::cli;
using Kind = SelectorOutcome::Kind;

namespace {

// ── Test harness ──

int g_failedChecks = 0;  // failed checks in the current test

void check(bool ok, const std::string& what) {
  if (!ok) {
    ++g_failedChecks;
    std::cout << "  check failed: " << what << "\n";
  }
}

KeyEvent K(Key k) { return KeyEvent{k, 0}; }
KeyEvent Ch(char c) { return KeyEvent{Key::Char, c}; }

bool contains(const std::string& s, const std::string& part) {
  return s.find(part) != std::string::npos;
}

std::size_t countOf(const std::string& s, const std::string& part) {
  std::size_t n = 0;
  for (std::size_t p = s.find(part); p != std::string::npos; p = s.find(part, p + part.size())) ++n;
  return n;
}

// Remove ANSI escape sequences, then count UTF-8 code points.
std::size_t visibleWidth(const std::string& s) {
  std::size_t n = 0;
  for (std::size_t i = 0; i < s.size(); ++i) {
    const unsigned char c = static_cast<unsigned char>(s[i]);
    if (c == 0x1b) {  // ESC [ ... final byte
      ++i;
      if (i < s.size() && s[i] == '[') {
        ++i;
        while (i < s.size() && !(s[i] >= '@' && s[i] <= '~')) ++i;
      }
      continue;
    }
    if ((c & 0xC0) != 0x80) ++n;
  }
  return n;
}

// n options: key "1".."n", label "item 1".."item n".
std::vector<Option> opts(std::size_t n) {
  std::vector<Option> v;
  for (std::size_t i = 1; i <= n; ++i)
    v.push_back(Option{std::to_string(i), "item " + std::to_string(i), "", ""});
  return v;
}

// Three category-like options for the pick() tests.
std::vector<Option> cats() {
  return {Option{"1", "length", "", "length"}, Option{"2", "mass", "", "mass"},
          Option{"3", "area", "", "area"}};
}

// Fake keyboard and screen for the draw/read loop.
struct Kb {
  std::deque<KeyEvent> keys;
  KeyEvent next() {
    if (keys.empty()) return K(Key::CtrlD);  // end of input
    const KeyEvent k = keys.front();
    keys.pop_front();
    return k;
  }
};

struct Screen {
  std::string text;
};

SelIo selIo(Kb& kb, Screen& screen, bool color = false) {
  SelIo io;
  io.readKey = [&kb] { return kb.next(); };
  io.write = [&screen](const std::string& s) { screen.text += s; };
  io.color = color;
  return io;
}

SelectorOutcome Out(Kind k, std::size_t index = 0, char ch = 0) {
  return SelectorOutcome{k, index, ch};
}

// Fake io for pick(): scripted selector outcomes and scripted typed lines.
struct FakePick {
  bool useSelector = true;
  std::deque<SelectorOutcome> outcomes;
  std::deque<std::string> lines;  // answers to readLine
  std::string written;
  std::vector<std::string> prompts;
  int selectCalls = 0;
  int readCalls = 0;

  PickIo io() {
    PickIo p;
    p.write = [this](const std::string& s) { written += s; };
    p.readLine = [this](const std::string& prompt, std::string& line) {
      ++readCalls;
      prompts.push_back(prompt);
      if (lines.empty()) return false;
      line = lines.front();
      lines.pop_front();
      return true;
    };
    if (useSelector) {
      p.select = [this](const std::string&, const std::vector<Option>&, const SelectorConfig&) {
        ++selectCalls;
        if (outcomes.empty()) return Out(Kind::Abort);
        const SelectorOutcome o = outcomes.front();
        outcomes.pop_front();
        return o;
      };
    }
    return p;
  }
};

// ── SL1-SL12: pure layers ──

void SL1() {  // up/down move, wrap around, home/end
  SelectorState st;
  st.count = 3;
  const SelectorConfig cfg{};
  handleKey(st, cfg, K(Key::Down));
  check(st.index == 1, "down moves to row 2");
  handleKey(st, cfg, K(Key::Down));
  handleKey(st, cfg, K(Key::Down));
  check(st.index == 0, "down wraps to the first row");
  handleKey(st, cfg, K(Key::Up));
  check(st.index == 2, "up wraps to the last row");
  handleKey(st, cfg, K(Key::Home));
  check(st.index == 0, "home");
  handleKey(st, cfg, K(Key::End));
  check(st.index == 2, "end");
}

void SL2() {  // long lists scroll in a window of 10
  SelectorState st;
  st.count = 25;
  const SelectorConfig cfg{};
  for (int i = 0; i < 10; ++i) handleKey(st, cfg, K(Key::Down));
  check(st.index == 10 && st.top == 1, "window scrolls by one after the 10th row");
  handleKey(st, cfg, K(Key::End));
  check(st.index == 24 && st.top == 15, "end shows the last window");
  handleKey(st, cfg, K(Key::Home));
  check(st.index == 0 && st.top == 0, "home shows the first window");
  const std::vector<std::string> lines = drawLines("T", opts(25), st, cfg, false);
  std::size_t rows = 0;
  for (const std::string& l : lines)
    if (contains(l, ") item")) ++rows;
  check(rows == kWindow, "exactly 10 rows are drawn");
}

void SL3() {  // Enter selects; Esc / b / q only work when offered
  SelectorState st;
  st.count = 3;
  SelectorConfig none{};
  none.canQuit = false;
  check(handleKey(st, none, K(Key::Enter)).action == Action::Select, "Enter selects");
  check(handleKey(st, none, K(Key::Escape)).action == Action::None, "Esc ignored when not offered");
  check(handleKey(st, none, Ch('b')).action == Action::None, "b ignored when not offered");
  check(handleKey(st, none, Ch('q')).action == Action::None, "q ignored when not offered");
  SelectorConfig all{};
  all.canBack = true;
  check(handleKey(st, all, K(Key::Escape)).action == Action::Back, "Esc is back");
  check(handleKey(st, all, Ch('b')).action == Action::Back, "b is back");
  check(handleKey(st, all, Ch('q')).action == Action::Quit, "q is quit");
}

void SL4() {  // Ctrl-C / Ctrl-D abort; other control keys are ignored
  SelectorState st;
  st.count = 3;
  const SelectorConfig cfg{};
  check(handleKey(st, cfg, K(Key::CtrlC)).action == Action::Abort, "Ctrl-C aborts");
  check(handleKey(st, cfg, K(Key::CtrlD)).action == Action::Abort, "Ctrl-D aborts");
  check(handleKey(st, cfg, K(Key::Other)).action == Action::None, "other control keys ignored");
  check(st.index == 0, "ignored keys do not move the highlight");
}

void SL5() {  // typing on: a printable key ends the selector and carries the character
  SelectorState st;
  st.count = 3;
  SelectorConfig cfg{};
  cfg.typing = true;
  KeyResult r = handleKey(st, cfg, Ch('x'));
  check(r.action == Action::Typed && r.ch == 'x', "letter is typed");
  r = handleKey(st, cfg, Ch('1'));
  check(r.action == Action::Typed && r.ch == '1', "digit is typed");
}

void SL6() {  // typing off: printable keys are ignored
  SelectorState st;
  st.count = 3;
  const SelectorConfig cfg{};
  check(handleKey(st, cfg, Ch('x')).action == Action::None, "letter ignored");
  check(handleKey(st, cfg, Ch('1')).action == Action::None, "digit ignored");
}

void SL7() {  // typing on: Esc, b, q, arrows and Enter keep their meaning
  SelectorState st;
  st.count = 3;
  SelectorConfig cfg{};
  cfg.typing = true;
  cfg.canBack = true;
  check(handleKey(st, cfg, K(Key::Escape)).action == Action::Back, "Esc");
  check(handleKey(st, cfg, Ch('b')).action == Action::Back, "b");
  check(handleKey(st, cfg, Ch('q')).action == Action::Quit, "q");
  check(handleKey(st, cfg, K(Key::Down)).action == Action::Move, "arrow");
  check(handleKey(st, cfg, K(Key::Enter)).action == Action::Select, "Enter");
}

void SL8() {  // typing on: space and control keys do not start a typed line
  SelectorState st;
  st.count = 3;
  SelectorConfig cfg{};
  cfg.typing = true;
  check(handleKey(st, cfg, Ch(' ')).action == Action::None, "space");
  check(handleKey(st, cfg, K(Key::Other)).action == Action::None, "control key");
  check(handleKey(st, cfg, K(Key::CtrlC)).action == Action::Abort, "Ctrl-C still aborts");
}

void SL9() {  // the selected row is highlighted as a full bar
  const std::vector<Option> o = {Option{"1", "a", "", ""},
                                 Option{"2", "a longer label", "", ""}};
  SelectorState st;
  st.count = 2;
  const std::vector<std::string> lines = drawLines("T", o, st, SelectorConfig{}, true);
  check(lines.size() >= 3, "title and two rows");
  check(contains(lines[1], "\x1b[7m") && contains(lines[1], "\x1b[0m"), "selected row is reverse video");
  check(!contains(lines[2], "\x1b[7m"), "other rows are not highlighted");
  check(visibleWidth(lines[1]) == visibleWidth(lines[2]), "the bar is as wide as the widest row");
}

void SL10() {  // plain mode still marks the selected row with the pointer
  const std::vector<Option> o = opts(2);
  SelectorState st;
  st.count = 2;
  const std::vector<std::string> lines = drawLines("T", o, st, SelectorConfig{}, false);
  check(lines.size() >= 3 && contains(lines[1], "❯"), "pointer on the selected row");
  bool escapes = false;
  for (const std::string& l : lines)
    if (contains(l, "\x1b")) escapes = true;
  check(!escapes, "no escape codes without colour");
}

void SL11() {  // hint line lists only keys on offer
  SelectorConfig bare{};
  bare.canQuit = false;
  const std::string h = hintLine(bare);
  check(contains(h, "Enter") && contains(h, "move"), "arrows and Enter always listed");
  check(!contains(h, "Esc") && !contains(h, "q quit") && !contains(h, "type"), "nothing else listed");
  SelectorConfig quit{};
  check(contains(hintLine(quit), "q quit"), "q listed when offered");
}

void SL12() {  // hint shows Esc/b back and "or type" when typing is on
  SelectorConfig cfg{};
  cfg.canBack = true;
  cfg.typing = true;
  check(contains(hintLine(cfg), "Esc/b back"), "Esc/b back");
  check(contains(hintLine(cfg), "or type"), "or type");
  cfg.typing = false;
  check(!contains(hintLine(cfg), "or type"), "no 'or type' with typing off");
}

// ── SL13-SL15: the draw/read loop ──

void SL13() {  // keys in, index out, summary left behind, cursor restored
  Kb kb;
  kb.keys = {K(Key::Down), K(Key::Enter)};
  Screen scr;
  SelIo io = selIo(kb, scr);
  const SelectorOutcome o = runSelector(io, "Pick", opts(3), SelectorConfig{});
  check(o.kind == Kind::Chosen && o.index == 1, "second row chosen");
  check(contains(scr.text, "✔ Pick: item 2"), "summary left behind");
  const std::size_t hide = scr.text.find("\x1b[?25l");
  const std::size_t show = scr.text.rfind("\x1b[?25h");
  check(hide != std::string::npos && show != std::string::npos && hide < show,
        "cursor hidden, then restored");
  check(scr.text.rfind("✔") < show, "cursor restored after the summary");
}

void SL14() {  // loop: Esc, ignored keys, Ctrl-C
  {
    Kb kb;
    kb.keys = {K(Key::Escape)};
    Screen scr;
    SelIo io = selIo(kb, scr);
    SelectorConfig cfg{};
    cfg.canBack = true;
    check(runSelector(io, "T", opts(3), cfg).kind == Kind::Back, "Esc goes back");
    check(contains(scr.text, "\x1b[?25h"), "cursor restored after Esc");
  }
  {
    Kb kb;
    kb.keys = {K(Key::Other), Ch('x'), K(Key::Enter)};  // typing is off: both ignored
    Screen scr;
    SelIo io = selIo(kb, scr);
    const SelectorOutcome o = runSelector(io, "T", opts(3), SelectorConfig{});
    check(o.kind == Kind::Chosen && o.index == 0, "ignored keys change nothing");
  }
  {
    Kb kb;
    kb.keys = {K(Key::CtrlC)};
    Screen scr;
    SelIo io = selIo(kb, scr);
    check(runSelector(io, "T", opts(3), SelectorConfig{}).kind == Kind::Abort, "Ctrl-C aborts");
    check(contains(scr.text, "\x1b[?25h"), "cursor restored after Ctrl-C");
  }
}

void SL15() {  // loop: a typed key returns its character and restores the cursor
  Kb kb;
  kb.keys = {Ch('x')};
  Screen scr;
  SelIo io = selIo(kb, scr);
  SelectorConfig cfg{};
  cfg.typing = true;
  const SelectorOutcome o = runSelector(io, "T", opts(3), cfg);
  check(o.kind == Kind::Typed && o.ch == 'x', "typed character returned");
  check(contains(scr.text, "\x1b[?25h"), "cursor restored");
  check(!contains(scr.text, "✔"), "no summary for a typed key");
}

// ── SL16-SL21: pick() ──

void SL16() {  // pick() uses the selector when present and maps its results
  FakePick f;
  f.outcomes = {Out(Kind::Chosen, 2), Out(Kind::Back), Out(Kind::Quit), Out(Kind::Abort)};
  PickIo io = f.io();
  Pick p = pick(io, "T", cats(), true, nullptr);
  check(p.kind == PickKind::Chosen && p.index == 2, "Chosen");
  p = pick(io, "T", cats(), true, nullptr);
  check(p.kind == PickKind::Back, "Back");
  p = pick(io, "T", cats(), true, nullptr);
  check(p.kind == PickKind::Quit, "Quit");
  p = pick(io, "T", cats(), true, nullptr);
  check(p.kind == PickKind::Eof, "Abort is end of input");
  check(f.readCalls == 0, "no prompt line was read");
}

void SL17() {  // pick(): a typed name or number selects it
  FakePick f;
  f.outcomes = {Out(Kind::Typed, 0, 'l'), Out(Kind::Typed, 0, '2')};
  f.lines = {"ength", ""};
  PickIo io = f.io();
  Pick p = pick(io, "T", cats(), true, nullptr);
  check(p.kind == PickKind::Chosen && p.index == 0, "typed name 'length'");
  p = pick(io, "T", cats(), true, nullptr);
  check(p.kind == PickKind::Chosen && p.index == 1, "typed number 2");
  check(f.prompts.size() == 2 && f.prompts[0] == "> l", "the prompt shows the typed key");
}

void SL18() {  // pick(): a typed one-line command runs and the list comes back
  FakePick f;
  f.outcomes = {Out(Kind::Typed, 0, 'l'), Out(Kind::Chosen, 2)};
  f.lines = {"ist"};
  std::vector<std::string> ran;
  PickIo io = f.io();
  const Pick p = pick(io, "T", cats(), true, [&ran](const std::string& line) { ran.push_back(line); });
  check(ran.size() == 1 && ran[0] == "list", "the command ran with the full line");
  check(f.selectCalls == 2, "the selector came back");
  check(p.kind == PickKind::Chosen && p.index == 2, "then a normal choice");
}

void SL19() {  // pick(): an unknown typed word is an error and the list comes back
  FakePick f;
  f.outcomes = {Out(Kind::Typed, 0, 'z'), Out(Kind::Chosen, 0)};
  f.lines = {"zz"};
  PickIo io = f.io();
  const Pick p = pick(io, "T", cats(), true, nullptr);
  check(contains(f.written, "Error [UNKNOWN_COMMAND]"), "error line printed");
  check(f.selectCalls == 2, "the selector came back");
  check(p.kind == PickKind::Chosen, "then a normal choice");
}

void SL20() {  // pick(): b, q and Esc act at once, with no prompt line
  const KeyEvent keys[] = {Ch('b'), Ch('q'), K(Key::Escape)};
  const PickKind want[] = {PickKind::Back, PickKind::Quit, PickKind::Back};
  for (int i = 0; i < 3; ++i) {
    Kb kb;
    kb.keys = {keys[i]};
    Screen scr;
    bool read = false;
    PickIo io;
    io.write = [&scr](const std::string& s) { scr.text += s; };
    io.readLine = [&read](const std::string&, std::string&) { read = true; return false; };
    io.select = [&kb, &scr](const std::string& title, const std::vector<Option>& o,
                            const SelectorConfig& cfg) {
      SelIo sel = selIo(kb, scr);
      return runSelector(sel, title, o, cfg);
    };
    const Pick p = pick(io, "T", cats(), true, nullptr);
    check(p.kind == want[i], "key " + std::to_string(i) + " acts at once");
    check(!read, "no prompt line was read for key " + std::to_string(i));
    check(!contains(scr.text, "> "), "no prompt line was printed for key " + std::to_string(i));
  }
}

void SL21() {  // pick(): without a selector (pipes) the numbered list works as before
  FakePick f;
  f.useSelector = false;
  f.lines = {"help", "bogus", "2"};
  PickIo io = f.io();
  const Pick p = pick(io, "Title", cats(), true, nullptr);
  check(p.kind == PickKind::Chosen && p.index == 1, "typed number 2");
  check(contains(f.written, "Title\n  1) length\n  2) mass\n  3) area\n"), "numbered list format");
  check(countOf(f.written, "  1) length") == 2, "list printed again only after the error");
  check(contains(f.written, "Error [UNKNOWN_COMMAND]: Pick one from the list"), "error line");
  check(f.readCalls == 3, "three lines read");
}

// ── X2 (C++ only, not one of SL1-SL21): the redraw cannot miscount ──
// Lines never exceed the terminal width and the window shrinks on a short terminal, so one
// logical line is always one screen line and "cursor up N lines" lands on the first line.
void X2() {
  const std::vector<Option> o = {Option{"1", "a very long label that cannot fit", "", ""},
                                 Option{"2", "short", "", ""}};
  SelectorState st;
  st.count = 2;
  SelectorConfig cfg{};
  cfg.canBack = true;
  cfg.typing = true;
  for (const bool color : {false, true}) {
    const std::vector<std::string> lines =
        drawLines("A rather long title for a narrow terminal", o, st, cfg, color, 20);
    for (const std::string& l : lines) check(visibleWidth(l) <= 20, "line fits in 20 columns: " + l);
  }

  // A 3-row window draws exactly 3 rows.
  SelectorState small;
  small.count = 25;
  small.window = 3;
  const std::vector<std::string> lines = drawLines("T", opts(25), small, SelectorConfig{}, false);
  std::size_t rows = 0;
  for (const std::string& l : lines)
    if (contains(l, ") item")) ++rows;
  check(rows == 3, "a window of 3 draws 3 rows");

  // Through the loop: a 7-row terminal leaves room for 2 rows. The block is
  // title + 2 rows + "more" line + key hint = 5 lines, so the erase must move up exactly 5.
  Kb kb;
  kb.keys = {K(Key::Enter)};
  Screen scr;
  SelIo io = selIo(kb, scr);
  io.columns = [] { return 30; };
  io.rows = [] { return 7; };
  runSelector(io, "T", opts(25), SelectorConfig{});
  check(contains(scr.text, "\x1b[5A\r"), "erase moves up by the number of lines drawn");
}

}  // namespace

int main() {
  struct Test {
    const char* id;
    void (*fn)();
  };
  const Test tests[] = {
      {"SL1", SL1},   {"SL2", SL2},   {"SL3", SL3},   {"SL4", SL4},   {"SL5", SL5},
      {"SL6", SL6},   {"SL7", SL7},   {"SL8", SL8},   {"SL9", SL9},   {"SL10", SL10},
      {"SL11", SL11}, {"SL12", SL12}, {"SL13", SL13}, {"SL14", SL14}, {"SL15", SL15},
      {"SL16", SL16}, {"SL17", SL17}, {"SL18", SL18}, {"SL19", SL19}, {"SL20", SL20},
      {"SL21", SL21}};

  int total = 0, passed = 0;
  for (const Test& t : tests) {
    ++total;
    g_failedChecks = 0;
    t.fn();
    if (g_failedChecks == 0) ++passed;
    else std::cout << "FAIL " << t.id << "\n";
  }
  std::cout << "selector tests: " << passed << "/" << total << " passed\n";
  if (total != 21) {
    std::cout << "expected exactly 21 selector tests (SL1-SL21)\n";
    return 1;
  }

  g_failedChecks = 0;
  X2();
  const bool x2ok = g_failedChecks == 0;
  if (!x2ok) std::cout << "FAIL X2\n";
  std::cout << "extra selector tests: " << (x2ok ? 1 : 0) << "/1 passed\n";

  return (passed == total && x2ok) ? 0 : 1;
}