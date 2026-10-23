// Small string helpers used by every layer (one place per rule).
#pragma once
#include <cctype>
#include <sstream>
#include <string>
#include <vector>

namespace arithmos::text {

// Remove leading and trailing whitespace.
inline std::string trim(const std::string& s) {
  std::size_t b = 0, e = s.size();
  while (b < e && std::isspace(static_cast<unsigned char>(s[b]))) ++b;
  while (e > b && std::isspace(static_cast<unsigned char>(s[e - 1]))) --e;
  return s.substr(b, e - b);
}

inline std::string lower(std::string s) {
  for (char& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return s;
}

inline std::string upper(std::string s) {
  for (char& c : s) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
  return s;
}

// Split on whitespace.
inline std::vector<std::string> words(const std::string& s) {
  std::istringstream is(s);
  std::vector<std::string> out;
  std::string w;
  while (is >> w) out.push_back(w);
  return out;
}

inline std::string join(const std::vector<std::string>& parts, const std::string& sep) {
  std::string out;
  for (std::size_t i = 0; i < parts.size(); ++i) {
    if (i) out += sep;
    out += parts[i];
  }
  return out;
}

}  // namespace arithmos::text