// Spec §2.3 number formatting, used by the Standard Calculator and the Converter.
#pragma once
#include <string>

namespace arithmos {

// 12 significant digits (half away from zero), trailing zeros trimmed, -0 -> 0,
// plain notation for 1e-6 <= |x| < 1e15, else <mantissa>e<sign><exponent>.
// Throws OVERFLOW for infinity and INVALID_EXPRESSION for NaN (NaN never reaches the user).
std::string formatNumber(double x);

}  // namespace arithmos