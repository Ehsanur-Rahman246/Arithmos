#include "converter/converter.hpp"

#include <cctype>
#include <cmath>
#include <cstdlib>

#include "shared/errors.hpp"
#include "shared/format_number.hpp"
#include "shared/text.hpp"

namespace arithmos::converter {
namespace {

// ── Temperature: formula-based, goes through °C, rejects below absolute zero ──

double toCelsius(double v, const std::string& unit) {
  if (unit == "c") return v;
  if (unit == "f") return (v - 32.0) * 5.0 / 9.0;
  return v - 273.15;  // k
}

double fromCelsius(double c, const std::string& unit) {
  if (unit == "c") return c;
  if (unit == "f") return c * 9.0 / 5.0 + 32.0;
  return c + 273.15;  // k
}

double convertTemperature(double v, const Unit& from, const Unit& to) {
  const double c = toCelsius(v, from.symbol);
  // The tolerance absorbs binary noise, so exactly -459.67 f / 0 k / -273.15 c are allowed.
  if (c < -273.15 - 1e-9)
    throw ArithmosError("BELOW_ABSOLUTE_ZERO", "That is below absolute zero");
  return fromCelsius(c, to.symbol);
}

// value × from.factor ÷ to.factor  (spec §5.2)
double convertValue(const Category& cat, double v, const Unit& from, const Unit& to) {
  const double result = cat.name == "temperature"
                            ? convertTemperature(v, from, to)
                            : v * from.factor / to.factor;
  if (std::isinf(result) || std::isnan(result))
    throw ArithmosError("OVERFLOW", "Result is too large to represent");
  return result;
}

}  // namespace

double parseValue(const std::string& input) {
  const std::string bad = "'" + input + "' is not a number";
  std::size_t i = 0;
  if (i < input.size() && (input[i] == '-' || input[i] == '+')) ++i;
  int digits = 0, dots = 0;
  for (; i < input.size(); ++i) {
    const unsigned char c = static_cast<unsigned char>(input[i]);
    if (std::isdigit(c)) ++digits;
    else if (c == '.') ++dots;
    else throw ArithmosError("INVALID_NUMBER", bad);  // letters, "1e3", "1,000"
  }
  if (digits == 0 || dots > 1) throw ArithmosError("INVALID_NUMBER", bad);
  const double v = std::strtod(input.c_str(), nullptr);
  if (std::isinf(v)) throw ArithmosError("OVERFLOW", "That number is too large");
  return v;
}

std::string convert(const std::string& valueText, const std::string& fromSym,
                    const std::string& toSym) {
  const double value = parseValue(valueText);

  const Category* fromCat = nullptr;
  const Unit* from = findUnit(fromSym, &fromCat);
  if (!from)
    throw ArithmosError("UNKNOWN_UNIT", "'" + fromSym + "' is not a known unit. Try: list");

  // Target "all": every unit of the source's category, in table order.
  // Everything is computed first, so an error never leaves partial output (R18).
  if (text::lower(toSym) == "all") {
    std::vector<std::string> lines;
    for (const Unit& u : fromCat->units)
      lines.push_back(u.symbol + ": " + formatNumber(convertValue(*fromCat, value, *from, u)));
    return text::join(lines, "\n");
  }

  const Category* toCat = nullptr;
  const Unit* to = findUnit(toSym, &toCat);
  if (!to)
    throw ArithmosError("UNKNOWN_UNIT", "'" + toSym + "' is not a known unit. Try: list");
  if (toCat != fromCat)
    throw ArithmosError("INCOMPATIBLE_UNITS",
                        "Cannot convert " + fromCat->name + " to " + toCat->name);

  return formatNumber(convertValue(*fromCat, value, *from, *to));
}

std::string run(const std::string& rawLine) {
  const std::vector<std::string> w = text::words(text::trim(rawLine));
  if (w.empty()) throw ArithmosError("UNKNOWN_COMMAND", "Type a value, e.g. 100");
  const std::string first = text::lower(w[0]);

  if (first == "list") {
    if (w.size() > 2) throw ArithmosError("UNKNOWN_COMMAND", "Use: list  or  list <category>");
    std::vector<std::string> names;
    if (w.size() == 1) {
      for (const Category& c : categories()) names.push_back(c.name);
    } else {
      const Category* cat = findCategory(w[1]);
      if (!cat)
        throw ArithmosError("UNKNOWN_COMMAND", "'" + w[1] + "' is not a category. Try: list");
      for (const Unit& u : cat->units) names.push_back(u.symbol);
    }
    return text::join(names, ", ");
  }

  if (first == "convert") {
    if (w.size() != 4)
      throw ArithmosError("UNKNOWN_COMMAND", "Use: convert <value> <from> <to>");
    return convert(w[1], w[2], w[3]);
  }

  if (w.size() == 3) return convert(w[0], w[1], w[2]);  // the word "convert" is optional

  throw ArithmosError("UNKNOWN_COMMAND", "Not a command. Try: convert 100 cm in");
}

}  // namespace arithmos::converter