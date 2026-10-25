// Package calculator is the Standard Calculator engine:
// tokenize -> parse (AST) -> evaluate -> format. It never does I/O.
package calculator

import (
	"math"
	"strconv"
	"strings"

	"arithmos/internal/shared"
)

// ---------------------------------------------------------------- tokenizer

type kind int

const (
	kNum kind = iota
	kWord
	kOp
	kEOF
)

type token struct {
	k    kind
	text string
	num  float64
}

func isDigit(c rune) bool  { return c >= '0' && c <= '9' }
func isLetter(c rune) bool { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') }

func tokenize(src string) []token {
	var toks []token
	rs := []rune(src)
	for i := 0; i < len(rs); {
		c := rs[i]
		switch {
		case c == ' ' || c == '\t' || c == '\r' || c == '\n':
			i++
		case isDigit(c) || c == '.': // 12, 12.5, .5, 5.
			j := i
			for j < len(rs) && isDigit(rs[j]) {
				j++
			}
			if j < len(rs) && rs[j] == '.' {
				j++
				for j < len(rs) && isDigit(rs[j]) {
					j++
				}
			}
			text := string(rs[i:j])
			if text == "." {
				shared.Throw(shared.InvalidExpression, "Unexpected character '.'")
			}
			v, err := strconv.ParseFloat(text, 64)
			if err != nil && math.IsInf(v, 0) {
				shared.Throw(shared.Overflow, "That number is too large")
			}
			toks = append(toks, token{k: kNum, text: text, num: v})
			i = j
		case isLetter(c): // keywords are case-insensitive
			j := i
			for j < len(rs) && isLetter(rs[j]) {
				j++
			}
			w := string(rs[i:j])
			switch lw := strings.ToLower(w); lw {
			case "sqrt", "abs", "ans", "of":
				toks = append(toks, token{k: kWord, text: lw})
			default:
				shared.Throw(shared.InvalidExpression, "Unknown word '%s'", w)
			}
			i = j
		default:
			if strings.ContainsRune("+-*/^()%", c) {
				toks = append(toks, token{k: kOp, text: string(c)})
				i++
			} else {
				shared.Throw(shared.InvalidExpression, "Unexpected character '%c'", c)
			}
		}
	}
	return toks
}

// ------------------------------------------------------------------- parser

type node interface{}

type (
	numN   struct{ v float64 }
	ansN   struct{}
	unaryN struct {
		op byte
		x  node
	}
	binN struct { // op is + - * / ^ or "of"
		op   string
		l, r node
	}
	pctN   struct{ x node }  // postfix %
	groupN struct{ x node }  // parentheses; stops the "relative percent" rule
	callN  struct {
		fn string
		x  node
	}
)

type parser struct {
	toks []token
	pos  int
}

func (p *parser) peek() token { return p.toks[p.pos] }
func (p *parser) adv() token {
	t := p.toks[p.pos]
	if t.k != kEOF {
		p.pos++
	}
	return t
}
func (p *parser) isOp(s string) bool {
	t := p.peek()
	return t.k == kOp && t.text == s
}
func (p *parser) isWord(s string) bool {
	t := p.peek()
	return t.k == kWord && t.text == s
}

func parse(toks []token) node {
	p := &parser{toks: append(toks, token{k: kEOF})}
	if p.peek().k == kEOF {
		shared.Throw(shared.InvalidExpression, "Nothing to calculate")
	}
	n := p.expr()
	if p.peek().k != kEOF {
		shared.Throw(shared.InvalidExpression, "Unexpected symbol")
	}
	return n
}

// Precedence, low to high (spec §3.3):
//   expr    + -
//   term    * / of
//   unary   unary + -
//   power   ^ (right-associative; exponent may itself be unary)
//   postfix %
//   primary number, ans, calls, parentheses

func (p *parser) expr() node {
	l := p.term()
	for p.isOp("+") || p.isOp("-") {
		op := p.adv().text
		l = &binN{op, l, p.term()}
	}
	return l
}

func (p *parser) term() node {
	l := p.unary()
	for p.isOp("*") || p.isOp("/") || p.isWord("of") {
		op := p.adv().text
		l = &binN{op, l, p.unary()}
	}
	return l
}

func (p *parser) unary() node {
	if p.isOp("-") || p.isOp("+") {
		op := p.adv().text[0]
		return &unaryN{op, p.unary()}
	}
	return p.power()
}

func (p *parser) power() node {
	b := p.postfix()
	if p.isOp("^") {
		p.adv()
		return &binN{"^", b, p.unary()} // 2^3^2 and 2^-1
	}
	return b
}

func (p *parser) postfix() node {
	n := p.primary()
	for p.isOp("%") {
		p.adv()
		n = &pctN{n}
	}
	return n
}

func (p *parser) primary() node {
	t := p.adv()
	switch t.k {
	case kNum:
		return &numN{t.num}
	case kWord:
		switch t.text {
		case "ans":
			return &ansN{}
		case "sqrt", "abs":
			if !p.isOp("(") {
				shared.Throw(shared.InvalidExpression, "%s needs parentheses, like %s(4)", t.text, t.text)
			}
			p.adv()
			x := p.expr()
			if !p.isOp(")") {
				shared.Throw(shared.InvalidExpression, "Missing closing parenthesis")
			}
			p.adv()
			return &callN{t.text, x}
		}
		shared.Throw(shared.InvalidExpression, "Unexpected '%s'", t.text) // "of" as an operand
	case kOp:
		if t.text == "(" {
			x := p.expr()
			if !p.isOp(")") {
				shared.Throw(shared.InvalidExpression, "Missing closing parenthesis")
			}
			p.adv()
			return &groupN{x}
		}
		shared.Throw(shared.InvalidExpression, "Unexpected symbol")
	case kEOF:
		shared.Throw(shared.InvalidExpression, "The expression ends too early")
	}
	return nil
}

// ---------------------------------------------------------------- evaluator

// Calculator is one Standard Calculator session; it holds `ans`.
type Calculator struct{ ans float64 }

// New returns a session with ans = 0.
func New() *Calculator { return &Calculator{} }

// check turns NaN and Infinity into errors: they never reach the user.
func check(v float64) float64 {
	if math.IsNaN(v) {
		shared.Throw(shared.DomainError, "The result is not a number")
	}
	if math.IsInf(v, 0) {
		shared.Throw(shared.Overflow, "The result is too large")
	}
	return v
}

func pow(b, e float64) float64 {
	if b == 0 {
		if e == 0 {
			shared.Throw(shared.Undefined, "0^0 is undefined")
		}
		if e < 0 {
			shared.Throw(shared.DivByZero, "Zero cannot be raised to a negative power")
		}
		return 0
	}
	if b < 0 && e != math.Trunc(e) {
		shared.Throw(shared.DomainError, "A negative number cannot have a fractional power")
	}
	return math.Pow(b, e)
}

func (c *Calculator) eval(n node) float64 {
	switch n := n.(type) {
	case *numN:
		return n.v
	case *ansN:
		return c.ans
	case *groupN:
		return c.eval(n.x)
	case *pctN:
		return c.eval(n.x) / 100
	case *unaryN:
		v := c.eval(n.x)
		if n.op == '-' {
			return -v
		}
		return v
	case *callN:
		v := c.eval(n.x)
		if n.fn == "sqrt" {
			if v < 0 {
				shared.Throw(shared.DomainError, "Cannot take the square root of a negative number")
			}
			return math.Sqrt(v)
		}
		return math.Abs(v)
	case *binN:
		l := c.eval(n.l)
		switch n.op {
		case "+", "-":
			var r float64
			if p, ok := n.r.(*pctN); ok { // spec §3.4: direct % operand is relative
				r = l * c.eval(p.x) / 100
			} else {
				r = c.eval(n.r)
			}
			if n.op == "+" {
				return check(l + r)
			}
			return check(l - r)
		}
		r := c.eval(n.r)
		switch n.op {
		case "*", "of":
			return check(l * r)
		case "/":
			if r == 0 {
				shared.Throw(shared.DivByZero, "Cannot divide by zero")
			}
			return check(l / r)
		case "^":
			return check(pow(l, r))
		}
	}
	shared.Throw(shared.InvalidExpression, "Malformed expression")
	return 0
}

// Eval evaluates one expression. It does not change ans.
func (c *Calculator) Eval(line string) (v float64, err error) {
	err = shared.Guard(func() { v = c.eval(parse(tokenize(line))) })
	return
}

// Run evaluates and formats one expression. ans changes only after the whole
// line succeeded, so a failed line leaves ans unchanged (S33).
func (c *Calculator) Run(line string) (string, error) {
	v, err := c.Eval(line)
	if err != nil {
		return "", err
	}
	s, err := shared.FormatNumber(v)
	if err != nil {
		return "", err
	}
	c.ans = v
	return s, nil
}