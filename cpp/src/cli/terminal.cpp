#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS  // MSVC: getenv
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include "terminal.hpp"

#include <cstdlib>
#include <string>

#ifdef _WIN32
#include <conio.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>
#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif
#else
#include <cerrno>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <termios.h>
#include <unistd.h>
#endif

namespace arithmos::cli {

Terminal::Terminal() {
  const char* noColor = std::getenv("NO_COLOR");
  color_ = !(noColor != nullptr && *noColor != '\0');

  // Rule 4: ARITHMOS_PLAIN=1 forces the numbered list.
  const char* plain = std::getenv("ARITHMOS_PLAIN");
  if (plain != nullptr && std::string(plain) == "1") return;

#ifdef _WIN32
  if (!_isatty(_fileno(stdin)) || !_isatty(_fileno(stdout))) return;
  HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
  DWORD mode = 0;
  if (out == INVALID_HANDLE_VALUE || !GetConsoleMode(out, &mode)) return;
  if (!SetConsoleMode(out, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING)) return;
  savedMode_ = mode;
  modeSaved_ = true;
  interactive_ = true;
#else
  const char* term = std::getenv("TERM");
  if (!isatty(STDIN_FILENO) || !isatty(STDOUT_FILENO)) return;
  if (term == nullptr || std::string(term) == "dumb") return;
  interactive_ = true;
#endif
}

Terminal::~Terminal() {
#ifdef _WIN32
  if (modeSaved_) SetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE), static_cast<DWORD>(savedMode_));
#endif
}

namespace {

// Size of the visible terminal window. Returns false if it cannot be read.
bool screenSize(int& cols, int& rows) {
#ifdef _WIN32
  CONSOLE_SCREEN_BUFFER_INFO info;
  if (!GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &info)) return false;
  cols = info.srWindow.Right - info.srWindow.Left + 1;
  rows = info.srWindow.Bottom - info.srWindow.Top + 1;
  return true;
#else
  winsize ws;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) != 0) return false;
  cols = ws.ws_col;
  rows = ws.ws_row;
  return true;
#endif
}

}  // namespace

int Terminal::columns() const {
  int c = 0, r = 0;
  return screenSize(c, r) && c > 0 ? c : 80;
}

int Terminal::rows() const {
  int c = 0, r = 0;
  return screenSize(c, r) && r > 0 ? r : 24;
}

#ifdef _WIN32

KeyEvent Terminal::readKey() {
  const int c = _getch();
  if (c < 0) return KeyEvent{Key::CtrlD, 0};
  if (c == 0 || c == 0xE0) {  // extended key: the next code says which
    switch (_getch()) {
      case 72: return KeyEvent{Key::Up, 0};
      case 80: return KeyEvent{Key::Down, 0};
      case 71: return KeyEvent{Key::Home, 0};
      case 79: return KeyEvent{Key::End, 0};
      case 73: return KeyEvent{Key::PageUp, 0};
      case 81: return KeyEvent{Key::PageDown, 0};
      default: return KeyEvent{Key::Other, 0};
    }
  }
  switch (c) {
    case 3: return KeyEvent{Key::CtrlC, 0};
    case 4:
    case 26: return KeyEvent{Key::CtrlD, 0};  // Ctrl-D, and Ctrl-Z (Windows end of input)
    case 10:
    case 13: return KeyEvent{Key::Enter, 0};
    case 27: return KeyEvent{Key::Escape, 0};
    default: break;
  }
  if (c >= 32 && c <= 126) return KeyEvent{Key::Char, static_cast<char>(c)};
  return KeyEvent{Key::Other, 0};
}

#else  // POSIX

namespace {

// One byte from stdin. timeoutMs < 0 blocks; otherwise returns -1 if nothing arrives in time.
int readByte(int timeoutMs) {
  if (timeoutMs >= 0) {
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);
    timeval tv;
    tv.tv_sec = 0;
    tv.tv_usec = timeoutMs * 1000;
    if (select(STDIN_FILENO + 1, &fds, nullptr, nullptr, &tv) <= 0) return -1;
  }
  for (;;) {
    unsigned char c = 0;
    const ssize_t n = read(STDIN_FILENO, &c, 1);
    if (n == 1) return c;
    if (n < 0 && errno == EINTR) continue;
    return -1;  // end of input or error
  }
}

// After ESC: a lone Esc, or an arrow/Home/End/PgUp/PgDn sequence (ESC [ A, ESC O A, ESC [ 5 ~ ...).
KeyEvent decodeEscape() {
  const int c = readByte(50);
  if (c < 0) return KeyEvent{Key::Escape, 0};               // a bare Esc key press
  if (c != '[' && c != 'O') return KeyEvent{Key::Other, 0};  // Alt+key and friends

  std::string params;
  int fin = readByte(50);
  if (c == '[') {  // CSI: parameter bytes (0x30-0x3F), then a final byte (0x40-0x7E)
    while (fin >= 0x30 && fin <= 0x3F) {
      params += static_cast<char>(fin);
      fin = readByte(50);
    }
  }
  if (fin < 0) return KeyEvent{Key::Other, 0};

  const int n = params.empty() ? 0 : std::atoi(params.c_str());
  switch (fin) {
    case 'A': return KeyEvent{Key::Up, 0};
    case 'B': return KeyEvent{Key::Down, 0};
    case 'H': return KeyEvent{Key::Home, 0};
    case 'F': return KeyEvent{Key::End, 0};
    case '~':
      switch (n) {
        case 1:
        case 7: return KeyEvent{Key::Home, 0};
        case 4:
        case 8: return KeyEvent{Key::End, 0};
        case 5: return KeyEvent{Key::PageUp, 0};
        case 6: return KeyEvent{Key::PageDown, 0};
        default: break;
      }
      break;
    default: break;
  }
  return KeyEvent{Key::Other, 0};
}

KeyEvent decodeKey() {
  const int c = readByte(-1);
  if (c < 0) return KeyEvent{Key::CtrlD, 0};
  switch (c) {
    case 3: return KeyEvent{Key::CtrlC, 0};
    case 4: return KeyEvent{Key::CtrlD, 0};
    case 10:
    case 13: return KeyEvent{Key::Enter, 0};
    case 27: return decodeEscape();
    default: break;
  }
  if (c >= 32 && c <= 126) return KeyEvent{Key::Char, static_cast<char>(c)};
  return KeyEvent{Key::Other, 0};  // other control keys and UTF-8 bytes are ignored
}

}  // namespace

KeyEvent Terminal::readKey() {
  termios saved;
  if (tcgetattr(STDIN_FILENO, &saved) != 0) return KeyEvent{Key::CtrlD, 0};

  // Raw only while a key is read: no line buffering, no echo, and Ctrl-C arrives as a key.
  termios raw = saved;
  raw.c_lflag &= static_cast<tcflag_t>(~(ICANON | ECHO | ISIG));
  raw.c_iflag &= static_cast<tcflag_t>(~(IXON | ICRNL));
  raw.c_cc[VMIN] = 1;
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSANOW, &raw);

  const KeyEvent ev = decodeKey();

  tcsetattr(STDIN_FILENO, TCSANOW, &saved);  // never leave the terminal raw
  return ev;
}

#endif

}  // namespace arithmos::cli