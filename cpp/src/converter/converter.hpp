// Unit Converter engine (spec §5). Data-driven: unit tables live in units.cpp.
#pragma once
#include <string>
#include <vector>

namespace arithmos::converter {

struct Unit {
  std::string symbol;  // lower-case, unique across ALL categories
  std::string name;    // display name, exactly as in the spec tables (R33)
  double factor;       // base units per one of this unit (unused for temperature)
};

struct Category {
  std::string name;
  std::string base;
  std::vector<Unit> units;  // in spec table order
};

const std::vector<Category>& categories();                 // the twelve categories
const Category* findCategory(const std::string& name);     // case-insensitive
const Unit* findUnit(const std::string& symbol, const Category** category);  // case-insensitive

// Plain decimal value ("abc", "1e3", "1,000" are INVALID_NUMBER).
double parseValue(const std::string& text);

// Convert a value. `to` may be "all": one "<symbol>: <value>" line per unit of the
// source's category, in table order, source included (all-or-nothing on error).
std::string convert(const std::string& valueText, const std::string& from, const std::string& to);

// One-line commands: "convert <v> <from> <to>", "<v> <from> <to>", "list", "list <category>".
std::string run(const std::string& line);

}  // namespace arithmos::converter