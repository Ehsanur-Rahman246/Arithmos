#include "selector.hpp"

#include <algorithm>

namespace arithmos::cli {
namespace {

constexpr const char* kReverse = "\x1b[7m";  // reverse video: the full-bar highlight
constexpr const char* kDim = "\x1b[2m";
constexpr const char* kReset = "\x1b[0m";

// Display width = number of UTF-8 code points (labels contain "—").
std::size_t displayWidth(const std::string& s) {
  std::size_t n = 0;
  for (const unsigned char c : s)
    if ((c & 0xC0) != 0x80) ++n;
  return n;
}

// Cut `s` to at most `width` columns, ending with "…" when something was cut.
// width == 0 means no limit.
std::string fit(const std::string& s, std::size_t width) {
  if (width == 0 || displayWidth(s) <= width) return s;
  std::string out;
  std::size_t columns = 0;
  for (std::size_t i = 0; i < s.size();) {
    const unsigned char c = static_cast<unsigned char>(s[i]);
    const std::size_t len = c >= 0xF0 ? 4 : c >= 0xE0 ? 3 : c >= 0xC0 ? 2 : 1;
    if (columns + 1 >= width) break;  // leave room for the ellipsis
    out.append(s, i, len);
    i += len;
    ++columns;
  }
  return out + "…";
}

// Scroll the window just enough to keep the highlighted row visible.
void keepVisible(SelectorState& s) {
  if (s.window == 0) s.window = 1;
  if (s.index < s.top) s.top = s.index;
  else if (s.index >= s.top + s.window) s.top = s.index + 1 - s.window;
}

}  // namespace

// ─────────────────────────── Layer 1: key handling ───────────────────────────

KeyResult handleKey(SelectorState& st, const SelectorConfig& cfg, const KeyEvent& ev) {
  const bool hasRows = st.count > 0;
  const auto moveTo = [&st](std::size_t to) {
    st.index = to;
    keepVisible(st);
    return KeyResult{Action::Move, 0};
  };

  switch (ev.key) {
    case Key::Up:
      return hasRows ? moveTo((st.index + st.count - 1) % st.count) : KeyResult{};
    case Key::Down:
      return hasRows ? moveTo((st.index + 1) % st.count) : KeyResult{};
    case Key::Home:
      return hasRows ? moveTo(0) : KeyResult{};
    case Key::End:
      return hasRows ? moveTo(st.count - 1) : KeyResult{};
    case Key::PageUp:
      return hasRows ? moveTo(st.index >= st.window ? st.index - st.window : 0) : KeyResult{};
    case Key::PageDown:
      return hasRows ? moveTo(std::min(st.count - 1, st.index + st.window)) : KeyResult{};
    case Key::Enter:
      return hasRows ? KeyResult{Action::Select, 0} : KeyResult{};
    case Key::Escape:
      return cfg.canBack ? KeyResult{Action::Back, 0} : KeyResult{};
    case Key::CtrlC:
    case Key::CtrlD:
      return KeyResult{Action::Abort, 0};
    case Key::Char:
      // b and q act at once, with no prompt line. They are ordinary keys when not offered.
      if (ev.ch == 'b' && cfg.canBack) return KeyResult{Action::Back, 0};
      if (ev.ch == 'q' && cfg.canQuit) return KeyResult{Action::Quit, 0};
      // Space and control keys never start a typed line.
      if (cfg.typing && ev.ch > ' ' && ev.ch != 127) return KeyResult{Action::Typed, ev.ch};
      return KeyResult{};
    case Key::Other:
      break;
  }
  return KeyResult{};
}

// ───────────────────────────── Layer 2: drawing ─────────────────────────────

std::string hintLine(const SelectorConfig& cfg) {
  std::string h = "↑↓ move · Enter select";
  if (cfg.canBack) h += " · Esc/b back";
  if (cfg.canQuit) h += " · q quit";
  if (cfg.typing) h += " · or type a number, name or command";
  return h;
}

std::vector<std::string> drawLines(const std::string& title, const std::vector<Option>& options,
                                   const SelectorState& state, const SelectorConfig& cfg,
                                   bool color, std::size_t width) {
  std::vector<std::string> out;
  out.push_back(fit(title, width));

  // Every row is padded to the widest row so the highlight is a full bar.
  std::size_t widest = 0;
  for (const Option& o : options) widest = std::max(widest, displayWidth(o.key + ") " + o.label));
  const std::size_t barWidth = width > 0 ? std::min(widest + 2, width) : widest + 2;

  const std::size_t end = std::min(options.size(), state.top + state.window);
  if (state.top > 0) out.push_back(fit("  ↑ " + std::to_string(state.top) + " more", width));

  for (std::size_t i = state.top; i < end; ++i) {
    const bool selected = i == state.index;
    // The pointer stays even without colour (SL10).
    std::string row = fit((selected ? "❯ " : "  ") + options[i].key + ") " + options[i].label, width);
    if (selected && color) {
      const std::size_t w = displayWidth(row);
      if (w < barWidth) row += std::string(barWidth - w, ' ');
      row = std::string(kReverse) + row + kReset;
    }
    out.push_back(row);
  }

  if (end < options.size())
    out.push_back(fit("  ↓ " + std::to_string(options.size() - end) + " more", width));

  const std::string hint = fit("  " + hintLine(cfg), width);
  out.push_back(color ? std::string(kDim) + hint + kReset : hint);
  return out;
}

// ─────────────────────────── Layer 3: draw/read loop ───────────────────────────

SelectorOutcome runSelector(SelIo& io, const std::string& title,
                            const std::vector<Option>& options, const SelectorConfig& cfg) {
  using Kind = SelectorOutcome::Kind;
  if (options.empty()) return SelectorOutcome{Kind::Abort, 0, 0};

  SelectorState st;
  st.count = options.size();
  std::size_t drawn = 0;  // how many screen lines the list occupies right now

  // Move up over the drawn lines and clear from there down.
  const auto erase = [&] {
    if (drawn == 0) return;
    io.write("\x1b[" + std::to_string(drawn) + "A\r\x1b[J");
    drawn = 0;
  };

  const auto draw = [&] {
    erase();

    // Measured on every draw, so resizing the window is handled. The block is
    // title + rows + 2 scroll hints + key hint, and the cursor rests on the line below it,
    // so a short terminal gets a smaller window (never taller than the screen).
    const int rows = io.rows ? io.rows() : 0;
    st.window = kWindow;
    if (rows > 0) {
      const std::size_t room = rows > 5 ? static_cast<std::size_t>(rows - 5) : 1;
      st.window = std::min(kWindow, room);
    }
    keepVisible(st);

    // One column less than the terminal width: a line that fills the last column can wrap.
    const int cols = io.columns ? io.columns() : 0;
    const std::size_t width = cols > 1 ? static_cast<std::size_t>(cols - 1) : 0;

    const std::vector<std::string> lines = drawLines(title, options, st, cfg, io.color, width);
    std::string buffer;
    for (const std::string& l : lines) buffer += l + "\n";
    io.write(buffer);
    drawn = lines.size();
  };

  // Every way out erases the list, leaves an optional summary and restores the cursor.
  const auto finish = [&](SelectorOutcome outcome, const std::string& summary) {
    erase();
    if (!summary.empty()) io.write(summary);
    io.write("\x1b[?25h");  // show cursor
    return outcome;
  };

  io.write("\x1b[?25l");  // hide cursor
  draw();

  for (;;) {
    const KeyResult r = handleKey(st, cfg, io.readKey());
    switch (r.action) {
      case Action::Move:
        draw();
        break;
      case Action::Select:
        return finish(SelectorOutcome{Kind::Chosen, st.index, 0},
                      "✔ " + title + ": " + options[st.index].label + "\n");
      case Action::Back:
        return finish(SelectorOutcome{Kind::Back, 0, 0}, "");
      case Action::Quit:
        return finish(SelectorOutcome{Kind::Quit, 0, 0}, "");
      case Action::Abort:
        return finish(SelectorOutcome{Kind::Abort, 0, 0}, "");
      case Action::Typed:
        return finish(SelectorOutcome{Kind::Typed, 0, r.ch}, "");
      case Action::None:
        break;
    }
  }
}

}  // namespace arithmos::cli