// Pipeline: tokenize -> parse (AST) -> evaluate.  (Formatting is in shared/.)
#include "calculator/calculator.hpp"

#include <cctype>
#include <cmath>
#include <cstdlib>
#include <memory>
#include <vector>

#include "shared/errors.hpp"
#include "shared/text.hpp"

namespace arithmos::calculator {
namespace {

ArithmosError invalid(const std::string& message) {
  return ArithmosError("INVALID_EXPRESSION", message);
}

// ───────────────────────────── Tokenizer ─────────────────────────────

enum class Tok { Num, Plus, Minus, Star, Slash, Caret, LParen, RParen, Percent,
                 Of, Ans, Sqrt, Abs, End };

struct Token {
  Tok type;
  double number;
};

std::vector<Token> tokenize(const std::string& s) {
  std::vector<Token> out;
  std::size_t i = 0;
  const std::size_t n = s.size();
  while (i < n) {
    const unsigned char c = static_cast<unsigned char>(s[i]);
    if (std::isspace(c)) { ++i; continue; }

    // Numbers: 12, 12.5, .5, 5.  (no exponent: "1e5" lexes as 1 then the word "e")
    if (std::isdigit(c) || c == '.') {
      std::size_t j = i;
      int dots = 0, digits = 0;
      while (j < n && (std::isdigit(static_cast<unsigned char>(s[j])) || s[j] == '.')) {
        if (s[j] == '.') ++dots; else ++digits;
        ++j;
      }
      if (dots > 1 || digits == 0) throw invalid("Unexpected symbol");  // "5.5.5", "."
      const double v = std::strtod(s.substr(i, j - i).c_str(), nullptr);
      if (std::isinf(v)) throw ArithmosError("OVERFLOW", "The result is too large");
      out.push_back({Tok::Num, v});
      i = j;
      continue;
    }

    // Words: of, ans, sqrt, abs (case-insensitive). Anything else is an error.
    if (std::isalpha(c)) {
      std::size_t j = i;
      while (j < n && std::isalpha(static_cast<unsigned char>(s[j]))) ++j;
      const std::string word = s.substr(i, j - i);
      const std::string w = text::lower(word);
      if (w == "of") out.push_back({Tok::Of, 0});
      else if (w == "ans") out.push_back({Tok::Ans, 0});
      else if (w == "sqrt") out.push_back({Tok::Sqrt, 0});
      else if (w == "abs") out.push_back({Tok::Abs, 0});
      else throw invalid("Unknown word '" + word + "'");
      i = j;
      continue;
    }

    switch (c) {
      case '+': out.push_back({Tok::Plus, 0}); break;
      case '-': out.push_back({Tok::Minus, 0}); break;
      case '*': out.push_back({Tok::Star, 0}); break;
      case '/': out.push_back({Tok::Slash, 0}); break;
      case '^': out.push_back({Tok::Caret, 0}); break;
      case '(': out.push_back({Tok::LParen, 0}); break;
      case ')': out.push_back({Tok::RParen, 0}); break;
      case '%': out.push_back({Tok::Percent, 0}); break;
      default: {
        // Report one whole UTF-8 character, not a single byte.
        std::size_t len = c >= 0xF0 ? 4 : c >= 0xE0 ? 3 : c >= 0xC0 ? 2 : 1;
        if (i + len > n) len = n - i;
        throw invalid("Unexpected character '" + s.substr(i, len) + "'");
      }
    }
    ++i;
  }
  out.push_back({Tok::End, 0});
  return out;
}

// ─────────────────────────────── AST ────────────────────────────────

struct Node;
using NodePtr = std::unique_ptr<Node>;

struct Node {
  // Pct is its own node (spec §3.4). Group marks parentheses so that
  // "200 + (10%)" is NOT treated as a relative percent (amendment R1).
  enum class Kind { Num, Ans, Group, Pct, Neg, Pos, Bin, Func };
  Kind kind = Kind::Num;
  double value = 0;
  char op = 0;          // Bin: + - * / ^ and 'o' for "of"
  std::string fn;       // Func: "sqrt" or "abs"
  NodePtr left, right;
};

NodePtr make(Node::Kind kind, NodePtr l = nullptr, NodePtr r = nullptr) {
  auto n = std::make_unique<Node>();
  n->kind = kind;
  n->left = std::move(l);
  n->right = std::move(r);
  return n;
}

// ────────────────────────────── Parser ──────────────────────────────
// Precedence, high to low (spec §3.3):
//   parens/calls > postfix % > ^ (right-assoc) > unary +/- > * / of > + -

class Parser {
 public:
  explicit Parser(std::vector<Token> tokens) : t_(std::move(tokens)) {}

  NodePtr parse() {
    if (peek().type == Tok::End) throw invalid("Nothing to calculate");
    NodePtr tree = expr();
    if (peek().type != Tok::End) throw invalid("Unexpected symbol");  // "2 3", "2(3)"
    return tree;
  }

 private:
  // Keeps absurdly deep input from overflowing the stack (it must never crash).
  struct DepthGuard {
    int& d;
    explicit DepthGuard(int& depth) : d(depth) {
      if (++d > 1000) { --d; throw invalid("The expression is nested too deeply"); }
    }
    ~DepthGuard() { --d; }
  };

  const Token& peek() const { return t_[pos_]; }
  void next() { if (pos_ + 1 < t_.size()) ++pos_; }

  NodePtr expr() {  // + -
    DepthGuard guard(depth_);
    NodePtr left = term();
    while (peek().type == Tok::Plus || peek().type == Tok::Minus) {
      const char op = peek().type == Tok::Plus ? '+' : '-';
      next();
      NodePtr right = term();
      left = make(Node::Kind::Bin, std::move(left), std::move(right));
      left->op = op;
    }
    return left;
  }

  NodePtr term() {  // * / of
    NodePtr left = unary();
    while (peek().type == Tok::Star || peek().type == Tok::Slash || peek().type == Tok::Of) {
      const char op = peek().type == Tok::Star ? '*' : peek().type == Tok::Slash ? '/' : 'o';
      next();
      NodePtr right = unary();
      left = make(Node::Kind::Bin, std::move(left), std::move(right));
      left->op = op;
    }
    return left;
  }

  NodePtr unary() {  // unary + -  (binds looser than ^, so -2^2 = -4)
    DepthGuard guard(depth_);
    if (peek().type == Tok::Minus) { next(); return make(Node::Kind::Neg, unary()); }
    if (peek().type == Tok::Plus)  { next(); return make(Node::Kind::Pos, unary()); }
    return power();
  }

  NodePtr power() {  // ^ is right-associative: the exponent is parsed as a unary
    NodePtr base = postfix();
    if (peek().type == Tok::Caret) {
      next();
      NodePtr exponent = unary();  // allows 2^-1 and 2^3^2
      NodePtr node = make(Node::Kind::Bin, std::move(base), std::move(exponent));
      node->op = '^';
      return node;
    }
    return base;
  }

  NodePtr postfix() {  // 50%, 50%%
    NodePtr node = primary();
    while (peek().type == Tok::Percent) {
      next();
      node = make(Node::Kind::Pct, std::move(node));
    }
    return node;
  }

  void expectRParen() {
    if (peek().type == Tok::RParen) { next(); return; }
    if (peek().type == Tok::End) throw invalid("Missing closing parenthesis");
    throw invalid("Unexpected symbol");
  }

  NodePtr primary() {
    const Token t = peek();
    switch (t.type) {
      case Tok::Num: {
        next();
        NodePtr n = make(Node::Kind::Num);
        n->value = t.number;
        return n;
      }
      case Tok::Ans:
        next();
        return make(Node::Kind::Ans);
      case Tok::LParen: {
        next();
        NodePtr inner = expr();
        expectRParen();
        return make(Node::Kind::Group, std::move(inner));
      }
      case Tok::Sqrt:
      case Tok::Abs: {
        next();
        const std::string fn = t.type == Tok::Sqrt ? "sqrt" : "abs";
        if (peek().type != Tok::LParen)
          throw invalid(fn + " needs parentheses, like " + fn + "(4)");
        next();
        NodePtr inner = expr();
        expectRParen();
        NodePtr n = make(Node::Kind::Func, std::move(inner));
        n->fn = fn;
        return n;
      }
      case Tok::End: throw invalid("The expression ends too early");
      case Tok::Of:  throw invalid("Unexpected 'of'");
      default:       throw invalid("Unexpected symbol");
    }
  }

  std::vector<Token> t_;
  std::size_t pos_ = 0;
  int depth_ = 0;
};

// ──────────────────────────── Evaluator ─────────────────────────────

// NaN and infinity never escape: they become DOMAIN_ERROR / OVERFLOW.
double checked(double v) {
  if (std::isnan(v)) throw ArithmosError("DOMAIN_ERROR", "The result is not a number");
  if (std::isinf(v)) throw ArithmosError("OVERFLOW", "The result is too large");
  return v;
}

double power(double a, double b) {  // spec §3.5
  if (a == 0 && b == 0) throw ArithmosError("UNDEFINED", "0^0 is undefined");
  if (a == 0 && b < 0)
    throw ArithmosError("DIV_BY_ZERO", "Zero cannot be raised to a negative power");
  if (a < 0 && b != std::floor(b))
    throw ArithmosError("DOMAIN_ERROR", "A negative number cannot have a fractional power");
  return checked(std::pow(a, b));
}

double eval(const Node& n, double ans) {
  switch (n.kind) {
    case Node::Kind::Num:   return n.value;
    case Node::Kind::Ans:   return ans;
    case Node::Kind::Group: return eval(*n.left, ans);
    case Node::Kind::Pct:   return eval(*n.left, ans) / 100.0;  // standalone percent
    case Node::Kind::Neg:   return -eval(*n.left, ans);
    case Node::Kind::Pos:   return eval(*n.left, ans);
    case Node::Kind::Func: {
      const double x = eval(*n.left, ans);
      if (n.fn == "sqrt") {
        if (x < 0)
          throw ArithmosError("DOMAIN_ERROR", "Cannot take the square root of a negative number");
        return std::sqrt(x);
      }
      return std::fabs(x);
    }
    case Node::Kind::Bin: {
      const double a = eval(*n.left, ans);
      if (n.op == '+' || n.op == '-') {
        // A % that is the DIRECT right operand is relative to the left operand:
        // 200 + 10% -> 200 + 200*10/100. Grouping, negation, etc. make it plain.
        const double b = n.right->kind == Node::Kind::Pct
                             ? a * eval(*n.right->left, ans) / 100.0
                             : eval(*n.right, ans);
        return checked(n.op == '+' ? a + b : a - b);
      }
      const double b = eval(*n.right, ans);
      switch (n.op) {
        case '*':
        case 'o': return checked(a * b);  // "of" is sugar for *
        case '/':
          if (b == 0) throw ArithmosError("DIV_BY_ZERO", "Cannot divide by zero");
          return checked(a / b);
        default:  return power(a, b);     // '^'
      }
    }
  }
  return 0;  // unreachable
}

}  // namespace

double Session::evaluate(const std::string& expression) {
  Parser parser(tokenize(expression));
  const NodePtr tree = parser.parse();
  const double result = eval(*tree, ans_);
  ans_ = result;  // only reached after a fully successful evaluation
  return result;
}

}  // namespace arithmos::calculator