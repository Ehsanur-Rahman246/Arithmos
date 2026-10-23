// src/programmer/programmer.hpp
// Programmer Calculator engine (spec §4): signed 64-bit two's complement. Pure logic, no I/O.
#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace arithmos::programmer {

// The enumerator value is the radix.
enum class Base : int { Bin = 2, Oct = 8, Dec = 10, Hex = 16 };

// What one input line produced.
struct Result {
  enum class Kind : unsigned char {
    Value,    // a number: shown in all four bases
    Text,     // a convert result: printed as is
    BaseSet   // `base <name>` succeeded: `base` holds the new input base
  };

  Kind kind = Kind::Value;
  std::int64_t value = 0;     // Kind::Value
  std::string output;         // Kind::Text
  Base base = Base::Dec;      // Kind::BaseSet
};

// Holds the current input base (dec by default).
class Session {
 public:
  // Run one line. Throws ArithmosError (spec §2.2 codes) on failure.
  Result run(const std::string& line);

  [[nodiscard]] Base inputBase() const noexcept { return base_; }

 private:
  Base base_ = Base::Dec;
};

// Name <-> base. Lookup is case-insensitive; the canonical name is lower case.
[[nodiscard]] std::optional<Base> baseFromName(const std::string& name);
[[nodiscard]] std::string baseName(Base base);

// Parse one literal: optional '-', optional prefix (0b 0o 0d 0x), digit validation, range
// (spec §4.3). Throws INVALID_NUMBER, INVALID_DIGIT or OUT_OF_RANGE.
[[nodiscard]] std::int64_t parseLiteral(const std::string& literal, Base inputBase);

// One value in one radix (2..16): uppercase, no prefix, no leading zeros. Negative values
// show the full 64-bit pattern in radix 2/8/16 and the signed value in radix 10.
[[nodiscard]] std::string formatInBase(std::int64_t value, int radix);

// The four output lines: "HEX: ..", "DEC: ..", "OCT: ..", "BIN: .." (spec §4.4).
[[nodiscard]] std::vector<std::string> formatAll(std::int64_t value);

// The text the CLI prints for a result.
[[nodiscard]] std::string render(const Result& result);

}  // namespace arithmos::programmer