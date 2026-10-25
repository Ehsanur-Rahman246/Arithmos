// Standard Calculator: tokenize -> parse (AST) -> evaluate -> format.
// Pure logic: no stdin/stdout. Throws ArithmosError.
import 'dart:math' as math;

import '../shared/errors.dart';
import '../shared/format_number.dart';

ArithmosError _bad(String msg) => ArithmosError('INVALID_EXPRESSION', msg);

// ---------------------------------------------------------------- tokenizer

enum _T { num, plus, minus, star, slash, caret, lparen, rparen, pct, word }

class _Tok {
  final _T t;
  final String text;
  final double value;
  const _Tok(this.t, this.text, [this.value = 0]);
}

const _syms = {
  '+': _T.plus, '-': _T.minus, '*': _T.star, '/': _T.slash,
  '^': _T.caret, '(': _T.lparen, ')': _T.rparen, '%': _T.pct,
};
const _words = {'sqrt', 'abs', 'ans', 'of'};

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
bool _isAlpha(int c) => (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

List<_Tok> _tokenize(String s) {
  final out = <_Tok>[];
  var i = 0;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
      i++;
      continue;
    }
    // Numbers: 12  12.5  .5  5.   (no exponent form in Release 1)
    if (_isDigit(c) || c == 0x2E) {
      var j = i;
      while (j < s.length && _isDigit(s.codeUnitAt(j))) {
        j++;
      }
      final intPart = s.substring(i, j);
      var fracPart = '';
      if (j < s.length && s.codeUnitAt(j) == 0x2E) {
        j++;
        final k = j;
        while (j < s.length && _isDigit(s.codeUnitAt(j))) {
          j++;
        }
        fracPart = s.substring(k, j);
      }
      if (intPart.isEmpty && fracPart.isEmpty) throw _bad("Unexpected character '.'");
      if (j < s.length && s.codeUnitAt(j) == 0x2E) throw _bad("Unexpected character '.'"); // 5.5.5
      final v = double.parse(
          '${intPart.isEmpty ? '0' : intPart}.${fracPart.isEmpty ? '0' : fracPart}');
      if (v.isInfinite) throw const ArithmosError('OVERFLOW', 'That number is too large');
      out.add(_Tok(_T.num, s.substring(i, j), v));
      i = j;
      continue;
    }
    // Words: sqrt abs ans of (case-insensitive). "1e5" lands here as the word "e".
    if (_isAlpha(c)) {
      var j = i;
      while (j < s.length && _isAlpha(s.codeUnitAt(j))) {
        j++;
      }
      final raw = s.substring(i, j);
      final w = raw.toLowerCase();
      if (!_words.contains(w)) throw _bad("Unknown word '$raw'");
      out.add(_Tok(_T.word, w));
      i = j;
      continue;
    }
    final kind = _syms[s[i]];
    if (kind == null) throw _bad("Unexpected character '${s[i]}'");
    out.add(_Tok(kind, s[i]));
    i++;
  }
  return out;
}

// ------------------------------------------------------------------- parser
// Precedence, high to low (spec 3.3): ( ) and calls, postfix %, ^ (right),
// unary + -, * / of, + -.

sealed class _N {}

class _Num extends _N {
  final double v;
  _Num(this.v);
}

class _AnsN extends _N {}

/// Parentheses get their own node so `200 + (10%)` is NOT a relative percent.
class _Group extends _N {
  final _N e;
  _Group(this.e);
}

class _Neg extends _N {
  final bool minus;
  final _N e;
  _Neg(this.minus, this.e);
}

class _Pct extends _N {
  final _N e;
  _Pct(this.e);
}

class _Bin extends _N {
  final String op; // + - * / ^   ('of' is '*')
  final _N l, r;
  _Bin(this.op, this.l, this.r);
}

class _Call extends _N {
  final String fn; // sqrt | abs
  final _N a;
  _Call(this.fn, this.a);
}

class _Parser {
  final List<_Tok> t;
  int i = 0;
  _Parser(this.t);

  bool _is(_T k) => i < t.length && t[i].t == k;
  bool _isWord(String w) => i < t.length && t[i].t == _T.word && t[i].text == w;

  _N parse() {
    if (t.isEmpty) throw _bad('Nothing to calculate');
    final n = _sum();
    // Leftovers: `2 3`, `2(3)`, `)`. Implicit multiplication ends up here.
    if (i < t.length) throw _bad('Unexpected symbol');
    return n;
  }

  _N _sum() {
    var l = _term();
    while (_is(_T.plus) || _is(_T.minus)) {
      final op = t[i++].t == _T.plus ? '+' : '-';
      l = _Bin(op, l, _term());
    }
    return l;
  }

  _N _term() {
    var l = _unary();
    while (true) {
      if (_is(_T.star) || _is(_T.slash)) {
        final op = t[i++].t == _T.star ? '*' : '/';
        l = _Bin(op, l, _unary());
      } else if (_isWord('of')) {
        i++;
        l = _Bin('*', l, _unary());
      } else {
        return l;
      }
    }
  }

  _N _unary() {
    if (_is(_T.plus) || _is(_T.minus)) {
      final minus = t[i++].t == _T.minus;
      return _Neg(minus, _unary());
    }
    return _power();
  }

  // The right side of ^ is a unary level, so 2^-1 works and 2^3^2 is right-assoc.
  _N _power() {
    final base = _postfix();
    if (_is(_T.caret)) {
      i++;
      return _Bin('^', base, _unary());
    }
    return base;
  }

  _N _postfix() {
    var n = _primary();
    while (_is(_T.pct)) {
      i++;
      n = _Pct(n);
    }
    return n;
  }

  _N _primary() {
    if (i >= t.length) throw _bad('The expression ends too early');
    final k = t[i];
    if (k.t == _T.num) {
      i++;
      return _Num(k.value);
    }
    if (k.t == _T.lparen) {
      i++;
      final e = _sum();
      _close();
      return _Group(e);
    }
    if (k.t == _T.word) {
      i++;
      if (k.text == 'ans') return _AnsN();
      if (k.text == 'of') throw _bad("Unexpected 'of'");
      // sqrt or abs: parentheses are required
      if (!_is(_T.lparen)) throw _bad('${k.text} needs parentheses, like ${k.text}(4)');
      i++;
      final a = _sum();
      _close();
      return _Call(k.text, a);
    }
    throw _bad('Unexpected symbol');
  }

  void _close() {
    if (!_is(_T.rparen)) throw _bad('Missing closing parenthesis');
    i++;
  }
}

// ---------------------------------------------------------------- evaluator

/// NaN and Infinity never reach the user (spec 2.3 rule 5).
double _chk(double v) {
  if (v.isNaN) throw const ArithmosError('DOMAIN_ERROR', 'The result is not a number');
  if (v.isInfinite) throw const ArithmosError('OVERFLOW', 'The result is too large');
  return v;
}

double _pow(double b, double e) {
  if (b == 0 && e == 0) throw const ArithmosError('UNDEFINED', '0^0 is undefined');
  if (b == 0 && e < 0) {
    throw const ArithmosError('DIV_BY_ZERO', 'Zero cannot be raised to a negative power');
  }
  if (b < 0 && e != e.truncateToDouble()) {
    throw const ArithmosError('DOMAIN_ERROR', 'A negative number cannot have a fractional power');
  }
  return _chk(math.pow(b, e).toDouble()); // 10^-400 is 0, no error
}

double _eval(_N n, double ans) {
  if (n is _Num) return n.v;
  if (n is _AnsN) return ans;
  if (n is _Group) return _eval(n.e, ans);
  if (n is _Neg) {
    final v = _eval(n.e, ans);
    return n.minus ? -v : v;
  }
  if (n is _Pct) return _chk(_eval(n.e, ans) / 100); // standalone: value / 100
  if (n is _Call) {
    final a = _eval(n.a, ans);
    if (n.fn == 'sqrt') {
      if (a < 0) {
        throw const ArithmosError('DOMAIN_ERROR', 'Cannot take the square root of a negative number');
      }
      return math.sqrt(a);
    }
    return a.abs();
  }
  if (n is _Bin) {
    final l = _eval(n.l, ans);
    // Spec 3.4: a % that is the DIRECT right operand of + or - is relative to the left.
    if ((n.op == '+' || n.op == '-') && n.r is _Pct) {
      final p = _eval((n.r as _Pct).e, ans);
      final delta = l * p / 100;
      return _chk(n.op == '+' ? l + delta : l - delta);
    }
    final r = _eval(n.r, ans);
    switch (n.op) {
      case '+':
        return _chk(l + r);
      case '-':
        return _chk(l - r);
      case '*':
        return _chk(l * r);
      case '/':
        if (r == 0) throw const ArithmosError('DIV_BY_ZERO', 'Cannot divide by zero');
        return _chk(l / r);
      default:
        return _pow(l, r);
    }
  }
  throw const ArithmosError('INVALID_EXPRESSION', 'Malformed expression');
}

/// A Standard Calculator session. `ans` changes only after a fully successful
/// evaluation (including formatting), so a failed line never touches it.
class Calculator {
  double ans = 0;

  String evaluate(String line) {
    final tree = _Parser(_tokenize(line.trim())).parse();
    final v = _eval(tree, ans);
    final text = formatNumber(v);
    ans = v;
    return text;
  }
}