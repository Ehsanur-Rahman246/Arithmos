// Runs the shared cases (docs/release-1-cases.json, format in docs/test-cases.md),
// then a few C++-specific extras. Usage: ./run_tests [path/to/cases.json]
// Only codes and results are asserted, never prompt text or terminal formatting.
#include <algorithm>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>

#include "calculator/calculator.hpp"
#include "cli/cli.hpp"
#include "converter/converter.hpp"
#include "programmer/programmer.hpp"
#include "shared/errors.hpp"
#include "shared/format_number.hpp"
#include "shared/text.hpp"

using namespace arithmos;

// ── A tiny JSON reader (the cases file only needs objects, arrays and strings) ──

struct Json {
  enum Type { Null, Str, Arr, Obj, Other } type = Null;
  std::string str;
  std::vector<Json> arr;
  std::vector<std::string> keys;  // Obj: keys[i] belongs to vals[i]
  std::vector<Json> vals;

  const Json* get(const std::string& key) const {
    for (std::size_t i = 0; i < keys.size(); ++i)
      if (keys[i] == key) return &vals[i];
    return nullptr;
  }
};

class JsonParser {
 public:
  explicit JsonParser(const std::string& s) : s_(s) {}
  Json parse() { return value(); }

 private:
  void ws() { while (i_ < s_.size() && std::isspace(static_cast<unsigned char>(s_[i_]))) ++i_; }
  void expect(char c) {
    ws();
    if (i_ >= s_.size() || s_[i_] != c) throw std::runtime_error(std::string("JSON: expected ") + c);
    ++i_;
  }
  static void utf8(std::string& out, unsigned cp) {
    if (cp < 0x80) out += static_cast<char>(cp);
    else if (cp < 0x800) { out += static_cast<char>(0xC0 | (cp >> 6)); out += static_cast<char>(0x80 | (cp & 0x3F)); }
    else { out += static_cast<char>(0xE0 | (cp >> 12)); out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F)); out += static_cast<char>(0x80 | (cp & 0x3F)); }
  }
  std::string string() {
    expect('"');
    std::string out;
    while (i_ < s_.size() && s_[i_] != '"') {
      char c = s_[i_++];
      if (c != '\\') { out += c; continue; }
      c = s_[i_++];
      switch (c) {
        case 'n': out += '\n'; break;
        case 't': out += '\t'; break;
        case 'r': out += '\r'; break;
        case 'b': out += '\b'; break;
        case 'f': out += '\f'; break;
        case 'u': utf8(out, static_cast<unsigned>(std::stoul(s_.substr(i_, 4), nullptr, 16))); i_ += 4; break;
        default: out += c;  // \" \\ \/
      }
    }
    ++i_;  // closing quote
    return out;
  }
  Json value() {
    ws();
    Json j;
    const char c = s_.at(i_);
    if (c == '{') {
      ++i_; j.type = Json::Obj; ws();
      if (s_[i_] == '}') { ++i_; return j; }
      for (;;) {
        ws();
        j.keys.push_back(string());
        expect(':');
        j.vals.push_back(value());
        ws();
        if (s_[i_] == ',') { ++i_; continue; }
        expect('}');
        return j;
      }
    }
    if (c == '[') {
      ++i_; j.type = Json::Arr; ws();
      if (s_[i_] == ']') { ++i_; return j; }
      for (;;) {
        j.arr.push_back(value());
        ws();
        if (s_[i_] == ',') { ++i_; continue; }
        expect(']');
        return j;
      }
    }
    if (c == '"') { j.type = Json::Str; j.str = string(); return j; }
    const std::size_t start = i_;  // number, true, false, null
    while (i_ < s_.size() && !std::strchr(",]} \n\r\t", s_[i_])) ++i_;
    j.type = Json::Other;
    j.str = s_.substr(start, i_ - start);
    return j;
  }

  const std::string& s_;
  std::size_t i_ = 0;
};

// ── One session per case (setup lines and steps share it) ──

struct Runner {
  std::string tool;
  calculator::Session standard;
  programmer::Session programmer;

  std::string exec(const std::string& line) {
    if (tool == "standard") return formatNumber(standard.evaluate(line));
    if (tool == "programmer") return programmer::render(programmer.run(line));
    return converter::run(line);
  }
};

std::vector<std::string> splitLines(const std::string& s) {
  std::vector<std::string> lines;
  std::istringstream is(s);
  for (std::string l; std::getline(is, l);) lines.push_back(l);
  return lines;
}

bool hasLine(const std::vector<std::string>& lines, const std::string& want) {
  return std::find(lines.begin(), lines.end(), want) != lines.end();
}

// Check one input against `spec` (a case or a step). Returns "" on pass, else the reason.
std::string checkOne(const Json& spec, Runner& r) {
  const Json* input = spec.get("input");
  if (!input) return "case has no input";
  const Json* error = spec.get("error");
  const Json* expected = spec.get("expected");
  const Json* contains = spec.get("expectedContains");

  std::string out;
  try {
    out = r.exec(input->str);
  } catch (const ArithmosError& e) {
    if (error && e.code() == error->str) return "";
    return "'" + input->str + "': unexpected error " + e.code();
  }
  if (error) return "'" + input->str + "': expected error " + error->str + ", got '" + out + "'";

  const auto lines = splitLines(out);
  if (expected && expected->type == Json::Str) {
    if (out != expected->str)
      return "'" + input->str + "': expected '" + expected->str + "', got '" + out + "'";
  } else if (expected && expected->type == Json::Obj) {
    for (std::size_t i = 0; i < expected->keys.size(); ++i) {
      const std::string want = expected->keys[i] + ": " + expected->vals[i].str;
      if (!hasLine(lines, want)) return "'" + input->str + "': missing line '" + want + "'";
    }
  }
  if (contains)
    for (const Json& want : contains->arr)
      if (!hasLine(lines, want.str)) return "'" + input->str + "': missing line '" + want.str + "'";
  return "";
}

// ── Extras ──

static int g_extraFailed = 0;
static int g_extraTotal = 0;

void expect(bool ok, const std::string& name) {
  ++g_extraTotal;
  if (!ok) { ++g_extraFailed; std::cout << "FAIL extra: " << name << "\n"; }
}

void runExtras() {
  // Number formatting boundaries (spec §2.3)
  expect(formatNumber(100000000000.5) == "100000000001", "half away from zero");
  expect(formatNumber(0.1 + 0.2) == "0.3", "binary noise hidden");
  expect(formatNumber(1e-6) == "0.000001", "1e-6 is plain");
  expect(formatNumber(1e-7) == "1e-7", "1e-7 is scientific");
  // 15 digits are rounded to 12 significant digits first (spec §2.3), then padded with zeros
  expect(formatNumber(123456789012345.0) == "123456789012000", "below 1e15 is plain");
  // rounding up can reach 1e15, which is then scientific
  expect(formatNumber(999999999999999.0) == "1e+15", "rounds up into scientific");
  expect(formatNumber(1e15) == "1e+15", "1e15 is scientific");
  expect(formatNumber(999999999999.5) == "1000000000000", "rounding carries");
  expect(formatNumber(-0.0) == "0", "negative zero");
  expect(formatNumber(1.5e20) == "1.5e+20", "mantissa and exponent");

  // Garbage must produce an Error, never a crash
  const char* garbage[] = {"", "(((", ")", "2 $ 3", "\xff\xfe", "1..2", "sqrt", "abs(", "%", "of", "^^"};
  for (const char* g : garbage) {
    calculator::Session s;
    bool threw = false;
    try { s.evaluate(g); } catch (const ArithmosError&) { threw = true; }
    expect(threw, std::string("standard garbage: ") + g);
  }
  {  // deep nesting is rejected, not a stack overflow
    calculator::Session s;
    bool threw = false;
    try { s.evaluate(std::string(5000, '(') + "1" + std::string(5000, ')')); }
    catch (const ArithmosError&) { threw = true; }
    expect(threw, "deeply nested parentheses");
  }

  // Settled amendments
  {
    calculator::Session s;
    expect(formatNumber(s.evaluate("200 + (10%)")) == "200.1", "R1 grouped percent is plain");
    expect(formatNumber(s.evaluate("2^50%")) == "1.41421356237", "R3 % binds tighter than ^");
    expect(formatNumber(s.evaluate("50%%")) == "0.005", "R4 double percent");
    expect(formatNumber(s.evaluate("5 of 10")) == "50", "R5 of is multiplication");
    expect(formatNumber(s.evaluate("10^-400")) == "0", "R9 underflow is 0");
  }
  {
    programmer::Session p;
    expect(programmer::render(p.run("1<<3")).find("DEC: 8") != std::string::npos, "R29 spaceless shift");
    p.run("base hex");
    expect(programmer::render(p.run("DEC")).find("DEC: 3564") != std::string::npos, "R11 DEC is hex 0xDEC");
    expect(programmer::render(p.run("0B")).find("DEC: 11") != std::string::npos, "R30 bare 0B is eleven");
    p.run("base dec");
    bool threw = false;
    try { p.run("0x"); } catch (const ArithmosError& e) { threw = e.code() == "INVALID_DIGIT"; }
    expect(threw, "R30 bare 0x in dec mode");
  }
  expect(converter::convert("1", "m", "ft") == "3.28083989501", "converter basic");
  expect(converter::run("list").find("temperature") != std::string::npos, "list categories");

  // Scripted CLI sessions: menu -> tool -> back -> quit
  {
    std::istringstream in("1\n2 + 3 * 4\nback\n2\n0xFF\nquit\n");
    std::ostringstream out;
    arithmos::cli::runInteractive(in, out);
    expect(out.str().find("standard> 14\n") != std::string::npos, "session: standard result");
    expect(out.str().find("DEC: 255") != std::string::npos, "session: programmer result");
  }
  {
    std::istringstream in("3\nlength\nm\nyd\n100\nback\nback\nback\nback\n0\n");
    std::ostringstream out;
    arithmos::cli::runInteractive(in, out);
    expect(out.str().find("100 m = 109.361329834 yd") != std::string::npos, "session: guided converter");
  }
  {
    std::istringstream in("1\n10 / 0\nans\n");  // EOF mid-session exits cleanly
    std::ostringstream out;
    expect(arithmos::cli::runInteractive(in, out) == 0, "EOF exits cleanly");
    expect(out.str().find("Error [DIV_BY_ZERO]") != std::string::npos, "session: error line");
  }
  {  // one-shot exit codes 0 / 1 / 2 and stdout vs stderr (R31)
    std::ostringstream out, err;
    expect(arithmos::cli::runOneShot({"STD", "2 + 3 * 4"}, out, err) == 0 && out.str() == "14\n", "one-shot ok");
    std::ostringstream out2, err2;
    expect(arithmos::cli::runOneShot({"std", "10 / 0"}, out2, err2) == 1 &&
               out2.str().empty() && err2.str().find("DIV_BY_ZERO") != std::string::npos,
           "one-shot error goes to stderr");
    std::ostringstream out3, err3;
    expect(arithmos::cli::runOneShot({"bogus"}, out3, err3) == 2, "one-shot bad usage");
  }
}

int main(int argc, char** argv) {
  const std::string path = argc > 1 ? argv[1] : "../docs/release-1-cases.json";
  std::ifstream file(path);
  if (!file) { std::cerr << "Cannot open " << path << "\n"; return 2; }
  std::stringstream buffer;
  buffer << file.rdbuf();
  const std::string data = buffer.str();

  Json root = JsonParser(data).parse();
  // Accept a bare array of cases, or an object that holds the array (e.g. {"cases": [...]}).
  const Json* cases = &root;
  if (root.type == Json::Obj) {
    cases = root.get("cases");
    if (!cases)
      for (const Json& v : root.vals) if (v.type == Json::Arr) { cases = &v; break; }
  }
  if (!cases || cases->type != Json::Arr) { std::cerr << "No case array found\n"; return 2; }

  int total = 0, failed = 0;
  for (const Json& c : cases->arr) {
    ++total;
    const std::string id = c.get("id") ? c.get("id")->str : "?";
    Runner runner;
    runner.tool = c.get("tool") ? c.get("tool")->str : "";
    std::string why;
    try {
      if (const Json* setup = c.get("setup"))
        for (const Json& line : setup->arr) runner.exec(line.str);  // e.g. "base hex"
      if (const Json* steps = c.get("steps")) {                     // multi-line sessions
        for (const Json& step : steps->arr) {
          why = checkOne(step, runner);
          if (!why.empty()) break;
        }
      } else {
        why = checkOne(c, runner);
      }
    } catch (const std::exception& e) {
      why = std::string("exception: ") + e.what();
    }
    if (!why.empty()) { ++failed; std::cout << "FAIL " << id << ": " << why << "\n"; }
  }

  runExtras();

  std::cout << "shared cases: " << (total - failed) << "/" << total << " passed\n"
            << "extra tests:  " << (g_extraTotal - g_extraFailed) << "/" << g_extraTotal << " passed\n";
  return (failed == 0 && g_extraFailed == 0) ? 0 : 1;
}