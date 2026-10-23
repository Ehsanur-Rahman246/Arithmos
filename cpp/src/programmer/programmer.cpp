// src/programmer/programmer.cpp
#include "programmer.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "../shared/errors.hpp"
#include "../shared/text.hpp"

namespace arithmos::programmer {
namespace {

using I64 = std::int64_t;
using U64 = std::uint64_t;

// ───────────────────────────── Constants ─────────────────────────────

constexpr int kMaxShift = 63;                               // spec §4.5: shift count 0-63
constexpr U64 kSignBit = U64{1} << 63;                      // 2^63
constexpr U64 kUnsignedMax = std::numeric_limits<U64>::max();
constexpr I64 kSignedMax = std::numeric_limits<I64>::max();
constexpr int kLetterOffset = 10;                           // 'A' is digit value 10

// ───────────────────────── Character helpers ─────────────────────────
// Wrap <cctype> so every call gets an unsigned char (passing a negative char is undefined).

bool isDigit(char c) { return c >= '0' && c <= '9'; }

bool isAlnum(char c) { return std::isalnum(static_cast<unsigned char>(c)) != 0; }

char toUpperChar(char c) {
  return static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
}

char toLowerChar(char c) {
  return static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
}

// Value of an alphanumeric digit: '0'-'9' -> 0-9, 'a'/'A' -> 10, ... 'z'/'Z' -> 35.
int digitValue(char c) {
  return isDigit(c) ? c - '0' : toUpperChar(c) - 'A' + kLetterOffset;
}

// ─────────────────────────── 64-bit helpers ───────────────────────────

// Reinterpret 64 bits as signed two's complement. Does not depend on how the compiler
// converts out-of-range unsigned values.
I64 toSigned(U64 u) {
  if (u <= static_cast<U64>(kSignedMax)) return static_cast<I64>(u);
  return -static_cast<I64>(~u) - 1;
}

// ─────────────────────────── Result builders ───────────────────────────

Result valueResult(I64 value) {
  Result r;
  r.kind = Result::Kind::Value;
  r.value = value;
  return r;
}

Result textResult(std::string output) {
  Result r;
  r.kind = Result::Kind::Text;
  r.output = std::move(output);
  return r;
}

Result baseResult(Base base) {
  Result r;
  r.kind = Result::Kind::BaseSet;
  r.base = base;
  return r;
}

// ───────────────────────────── Commands ─────────────────────────────

Base requireBase(const std::string& name) {
  const std::optional<Base> base = baseFromName(name);
  if (!base) {
    throw ArithmosError("INVALID_BASE",
                        "'" + name + "' is not a base. Use bin, oct, dec or hex");
  }
  return *base;
}

// `convert` reads the value with the explicit FROM base, not the current input base.
Result convertValue(const std::string& valueText, Base from, Base to) {
  const I64 value = parseLiteral(valueText, from);
  return textResult(formatInBase(value, static_cast<int>(to)));
}

// "1 << 3", "-8>>1", "-8 >>> 1": spaces around the operator are optional (R29).
Result shiftLine(Base base, const std::string& line, std::string_view op, std::size_t pos) {
  const std::string left = text::trim(line.substr(0, pos));
  const std::string right = text::trim(line.substr(pos + op.size()));
  if (left.empty() || right.empty() || text::words(left).size() != 1) {
    throw ArithmosError("UNKNOWN_COMMAND", "Not a command. Try help");
  }

  const I64 value = parseLiteral(left, base);

  // The count is always a plain decimal 0-63. "-1", "2.5", "0x3" and "64" are INVALID_SHIFT.
  const bool decimal = std::all_of(right.begin(), right.end(), isDigit);
  int count = 0;
  if (decimal) {
    for (const char c : right) {
      count = count * 10 + (c - '0');
      if (count > kMaxShift) count = kMaxShift + 1;  // saturate: a huge count cannot overflow int
    }
  }
  if (!decimal || count > kMaxShift) {
    throw ArithmosError("INVALID_SHIFT", "A shift count must be a whole number from 0 to 63");
  }

  const U64 bits = static_cast<U64>(value);
  if (op == "<<") return valueResult(toSigned(bits << count));   // bits past 63 are discarded
  if (op == ">>>") return valueResult(toSigned(bits >> count));  // logical: zero-filling
  // Arithmetic right shift without relying on implementation-defined behaviour: for a
  // negative value, shift its (non-negative) complement and complement the result back.
  return valueResult(value >= 0 ? (value >> count) : ~((~value) >> count));
}

}  // namespace

// ───────────────────────────── Public API ─────────────────────────────

std::optional<Base> baseFromName(const std::string& name) {
  const std::string n = text::lower(name);
  if (n == "bin") return Base::Bin;
  if (n == "oct") return Base::Oct;
  if (n == "dec") return Base::Dec;
  if (n == "hex") return Base::Hex;
  return std::nullopt;
}

std::string baseName(Base base) {
  switch (base) {
    case Base::Bin: return "bin";
    case Base::Oct: return "oct";
    case Base::Dec: return "dec";
    case Base::Hex: return "hex";
  }
  return "dec";  // unreachable; keeps every compiler happy
}

I64 parseLiteral(const std::string& literal, Base inputBase) {
  std::string s = literal;
  bool negative = false;
  if (!s.empty() && s.front() == '-') {
    negative = true;
    s.erase(0, 1);
  }

  // Empty, or anything that is not a letter or digit, is INVALID_NUMBER ("1.5", "-", "FF!").
  if (s.empty() || !std::all_of(s.begin(), s.end(), isAlnum)) {
    throw ArithmosError("INVALID_NUMBER", "'" + literal + "' is not a number");
  }

  // A prefix overrides the input base, but only when something follows it (R30):
  // "0B" in hex mode is the number 11, while "0B1" is binary 1.
  int radix = static_cast<int>(inputBase);
  if (s.size() > 2 && s[0] == '0') {
    bool prefixed = true;
    switch (toLowerChar(s[1])) {
      case 'b': radix = 2; break;
      case 'o': radix = 8; break;
      case 'd': radix = 10; break;
      case 'x': radix = 16; break;
      default: prefixed = false; break;
    }
    if (prefixed) s.erase(0, 2);
  }

  // Digit validation comes before the range check and covers every digit.
  const U64 uRadix = static_cast<U64>(radix);
  U64 magnitude = 0;
  bool overflow = false;
  for (const char ch : s) {
    const int digit = digitValue(ch);
    if (digit >= radix) {
      throw ArithmosError("INVALID_DIGIT",
                          "'" + std::string(1, toUpperChar(ch)) + "' is not a " +
                              baseName(static_cast<Base>(radix)) + " digit");
    }
    if (overflow) continue;  // keep validating the remaining digits
    const U64 uDigit = static_cast<U64>(digit);
    if (magnitude > (kUnsignedMax - uDigit) / uRadix) {
      overflow = true;
    } else {
      magnitude = magnitude * uRadix + uDigit;
    }
  }

  if (negative) {  // any base: the magnitude may be at most 2^63
    if (overflow || magnitude > kSignBit) {
      throw ArithmosError("OUT_OF_RANGE", "That number does not fit in 64 bits");
    }
    return toSigned(U64{0} - magnitude);
  }
  if (radix == 10) {  // decimal must fit the signed range
    if (overflow || magnitude >= kSignBit) {
      throw ArithmosError("OUT_OF_RANGE", "That number does not fit in 64 bits");
    }
    return static_cast<I64>(magnitude);
  }
  // bin/oct/hex without a minus sign: a raw bit pattern, reinterpreted as signed.
  if (overflow) throw ArithmosError("OUT_OF_RANGE", "That number needs more than 64 bits");
  return toSigned(magnitude);
}

std::string formatInBase(I64 value, int radix) {
  if (radix < 2 || radix > 16) throw std::invalid_argument("radix must be 2..16");
  if (radix == 10) return std::to_string(static_cast<long long>(value));

  U64 u = static_cast<U64>(value);  // a negative value becomes its full 64-bit pattern
  if (u == 0) return "0";
  static constexpr std::string_view kDigits = "0123456789ABCDEF";
  const U64 uRadix = static_cast<U64>(radix);
  std::string out;
  while (u != 0) {
    out += kDigits[static_cast<std::size_t>(u % uRadix)];
    u /= uRadix;
  }
  std::reverse(out.begin(), out.end());
  return out;
}

std::vector<std::string> formatAll(I64 value) {
  return {"HEX: " + formatInBase(value, 16), "DEC: " + formatInBase(value, 10),
          "OCT: " + formatInBase(value, 8), "BIN: " + formatInBase(value, 2)};
}

std::string render(const Result& result) {
  switch (result.kind) {
    case Result::Kind::Value: return text::join(formatAll(result.value), "\n");
    case Result::Kind::Text: return result.output;
    case Result::Kind::BaseSet: return "Input base: " + baseName(result.base);  // R32
  }
  return "";  // unreachable
}

Result Session::run(const std::string& rawLine) {
  const std::string line = text::trim(rawLine);
  if (line.empty()) {
    throw ArithmosError("UNKNOWN_COMMAND", "Type a number or a command. Try help");
  }

  const std::vector<std::string> w = text::words(line);
  const std::string first = text::lower(w[0]);

  // base <bin|oct|dec|hex>
  if (first == "base") {
    if (w.size() != 2) throw ArithmosError("INVALID_BASE", "Use: base bin | oct | dec | hex");
    base_ = requireBase(w[1]);
    return baseResult(base_);
  }

  // convert <value> <from> <to>
  if (first == "convert") {
    if (w.size() != 4) {
      throw ArithmosError("UNKNOWN_COMMAND", "Use: convert <value> <from> <to>");
    }
    const Base from = requireBase(w[2]);
    const Base to = requireBase(w[3]);
    return convertValue(w[1], from, to);
  }

  // <value> <from> <to>: the word "convert" is optional (R24).
  if (w.size() == 3) {
    const std::optional<Base> from = baseFromName(w[1]);
    const std::optional<Base> to = baseFromName(w[2]);
    if (from && to) return convertValue(w[0], *from, *to);
  }

  // NOT <a>
  if (first == "not") {
    if (w.size() != 2) throw ArithmosError("UNKNOWN_COMMAND", "Use: NOT <value>");
    return valueResult(~parseLiteral(w[1], base_));
  }

  // Shifts are checked before single words so that "1<<3" works. ">>>" must come before ">>".
  static constexpr std::array<std::string_view, 3> kShiftOps = {">>>", ">>", "<<"};
  for (const std::string_view shiftOp : kShiftOps) {
    const std::size_t pos = line.find(shiftOp);
    if (pos != std::string::npos) return shiftLine(base_, line, shiftOp, pos);
  }

  // <a> AND|OR|XOR <b>: the operator is always the middle word, so in hex mode words made
  // of hex digits (A, DEC, FACE) are numbers (R11).
  if (w.size() == 3) {
    const std::string op = text::lower(w[1]);
    if (op == "and" || op == "or" || op == "xor") {
      const U64 a = static_cast<U64>(parseLiteral(w[0], base_));
      const U64 b = static_cast<U64>(parseLiteral(w[2], base_));
      U64 bits = 0;
      if (op == "and") bits = a & b;
      else if (op == "or") bits = a | b;
      else bits = a ^ b;
      return valueResult(toSigned(bits));
    }
  }

  // A single value is shown in every base.
  if (w.size() == 1) return valueResult(parseLiteral(w[0], base_));

  throw ArithmosError("UNKNOWN_COMMAND", "Not a command. Try help");
}

}  // namespace arithmos::programmer