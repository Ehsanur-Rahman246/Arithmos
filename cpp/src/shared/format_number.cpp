// src/shared/format_number.cpp
#include "shared/format_number.hpp"

#include <cmath>
#include <cstdio>
#include <cstdlib>

#include "shared/errors.hpp"

namespace arithmos {

std::string formatNumber(double x) {
  if (std::isnan(x)) throw ArithmosError("INVALID_EXPRESSION", "Result is not a number");
  if (std::isinf(x)) throw ArithmosError("OVERFLOW", "Result is too large to represent");
  if (x == 0.0) return "0";  // also covers -0.0 (rule 4)

  const bool negative = x < 0;

  // printf("%.34e") prints the exact binary value as decimal digits, so we can round
  // by hand. (printf itself rounds exact ties to even; the spec wants half away from zero.)
  char buf[96];
  std::snprintf(buf, sizeof buf, "%.34e", std::fabs(x));

  // buf looks like "d.dddd...e+XX": collect the 35 digits and the exponent.
  std::string digits(1, buf[0]);
  const char* p = buf + 2;  // skip "d."
  while (*p && *p != 'e') digits += *p++;
  int exp10 = std::atoi(p + 1);  // p points at 'e'; atoi handles "+05" and "-07"

  // Round to 12 significant digits, half away from zero (on the magnitude).
  const bool roundUp = digits[12] >= '5';
  digits.resize(12);
  if (roundUp) {
    int i = 11;
    while (i >= 0 && digits[i] == '9') digits[i--] = '0';
    if (i < 0) {  // 999999999999.5 -> 1000000000000
      digits.insert(digits.begin(), '1');
      digits.pop_back();
      ++exp10;
    } else {
      ++digits[i];
    }
  }
  // Trim trailing zeros (rule 2).
  while (digits.size() > 1 && digits.back() == '0') digits.pop_back();

  std::string out = negative ? "-" : "";
  if (exp10 >= -6 && exp10 < 15) {
    // Plain notation (rule 3).
    if (exp10 >= 0) {
      for (int i = 0; i <= exp10; ++i)
        out += i < static_cast<int>(digits.size()) ? digits[i] : '0';
      if (static_cast<int>(digits.size()) > exp10 + 1)
        out += "." + digits.substr(exp10 + 1);
    } else {
      out += "0." + std::string(static_cast<std::size_t>(-exp10 - 1), '0') + digits;
    }
  } else {
    // Scientific notation: 1.5e+20, 2e-7.
    out += digits[0];
    if (digits.size() > 1) out += "." + digits.substr(1);
    out += 'e';
    out += exp10 < 0 ? '-' : '+';
    out += std::to_string(std::abs(exp10));
  }
  return out;
}

}  // namespace arithmos