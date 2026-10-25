// Package programmer is the Programmer Calculator engine: a signed 64-bit
// two's-complement model on Go's native int64/uint64. No I/O.
package programmer

import (
	"math"
	"math/big"
	"strconv"
	"strings"

	"arithmos/internal/shared"
)

// ParseBase maps bin/oct/dec/hex (any case) to a radix.
func ParseBase(name string) (int, bool) {
	switch strings.ToLower(name) {
	case "bin":
		return 2, true
	case "oct":
		return 8, true
	case "dec":
		return 10, true
	case "hex":
		return 16, true
	}
	return 0, false
}

// BaseName is the lower-case canonical name of a radix.
func BaseName(b int) string {
	switch b {
	case 2:
		return "bin"
	case 8:
		return "oct"
	case 16:
		return "hex"
	}
	return "dec"
}

func prefixBase(c byte) int {
	switch c {
	case 'b', 'B':
		return 2
	case 'o', 'O':
		return 8
	case 'd', 'D':
		return 10
	case 'x', 'X':
		return 16
	}
	return 0
}

func digitVal(c byte) int {
	switch {
	case c >= '0' && c <= '9':
		return int(c - '0')
	case c >= 'a' && c <= 'z':
		return int(c-'a') + 10 // g..z are >= 16: invalid in every base
	case c >= 'A' && c <= 'Z':
		return int(c-'A') + 10
	}
	return -1
}

var (
	two63 = new(big.Int).Lsh(big.NewInt(1), 63)
	two64 = new(big.Int).Lsh(big.NewInt(1), 64)
)

// ParseLiteral reads one literal. Order (ARCHITECTURE.md): prefix overrides the
// input base -> digit validation -> range. Digits are accumulated in a big.Int,
// so range checks are exact and nothing passes through float.
func ParseLiteral(text string, base int) int64 {
	s, neg := text, false
	if strings.HasPrefix(s, "-") {
		neg, s = true, s[1:]
	}
	// A prefix counts only when digits follow it (R30): "0B" in hex is 11.
	if len(s) > 2 && s[0] == '0' {
		if pb := prefixBase(s[1]); pb != 0 {
			base, s = pb, s[2:]
		}
	}
	if s == "" {
		shared.Throw(shared.InvalidNumber, "'%s' is not a number", text)
	}
	for i := 0; i < len(s); i++ {
		if digitVal(s[i]) < 0 {
			shared.Throw(shared.InvalidNumber, "'%s' is not a number", text)
		}
	}
	mag, bb := new(big.Int), big.NewInt(int64(base))
	for i := 0; i < len(s); i++ {
		d := digitVal(s[i])
		if d >= base {
			shared.Throw(shared.InvalidDigit, "'%c' is not a %s digit", strings.ToUpper(string(s[i]))[0], BaseName(base))
		}
		mag.Mul(mag, bb)
		mag.Add(mag, big.NewInt(int64(d)))
	}
	switch {
	case neg:
		if mag.Cmp(two63) > 0 {
			shared.Throw(shared.OutOfRange, "That number does not fit in 64 bits")
		}
		if mag.Cmp(two63) == 0 {
			return math.MinInt64
		}
		return -mag.Int64()
	case base == 10:
		if mag.Cmp(two63) >= 0 {
			shared.Throw(shared.OutOfRange, "That number does not fit in 64 bits")
		}
		return mag.Int64()
	default: // bin/oct/hex: a raw bit pattern, reinterpreted as signed
		if mag.Cmp(two64) >= 0 {
			shared.Throw(shared.OutOfRange, "That number needs more than 64 bits")
		}
		return int64(mag.Uint64())
	}
}

// FormatBase prints v in one base. Negative values show the full 64-bit
// pattern in hex/oct/bin and the signed value in dec (spec §4.4).
func FormatBase(v int64, base int) string {
	switch base {
	case 16:
		return strings.ToUpper(strconv.FormatUint(uint64(v), 16))
	case 8:
		return strconv.FormatUint(uint64(v), 8)
	case 2:
		return strconv.FormatUint(uint64(v), 2)
	}
	return strconv.FormatInt(v, 10)
}

// FormatMap returns the four renderings keyed HEX, DEC, OCT, BIN.
func FormatMap(v int64) map[string]string {
	return map[string]string{
		"HEX": FormatBase(v, 16), "DEC": FormatBase(v, 10),
		"OCT": FormatBase(v, 8), "BIN": FormatBase(v, 2),
	}
}

// Lines is the §4.4 output block.
func Lines(v int64) []string {
	m := FormatMap(v)
	return []string{"HEX: " + m["HEX"], "DEC: " + m["DEC"], "OCT: " + m["OCT"], "BIN: " + m["BIN"]}
}

// Kind says what a Result holds.
type Kind int

const (
	KindValue Kind = iota // Value: show in all bases
	KindText              // Text: a converted number
	KindBase              // Text: the new input base name
)

// Result is what one command produced. The CLI turns it into text.
type Result struct {
	Kind  Kind
	Value int64
	Text  string
}

// Programmer is one session; it holds the input base.
type Programmer struct{ base int }

// New starts in decimal.
func New() *Programmer { return &Programmer{base: 10} }

// Base returns the current input radix.
func (p *Programmer) Base() int { return p.base }

// Execute runs one line.
func (p *Programmer) Execute(line string) (res Result, err error) {
	err = shared.Guard(func() { res = p.exec(line) })
	return
}

// splitShift finds <<, >> or >>> anywhere in the line, so "1<<3" works (R29).
func splitShift(line string) (l, op, r string, ok bool) {
	for i := 0; i < len(line); i++ {
		for _, o := range []string{">>>", "<<", ">>"} {
			if strings.HasPrefix(line[i:], o) {
				return strings.TrimSpace(line[:i]), o, strings.TrimSpace(line[i+len(o):]), true
			}
		}
	}
	return
}

func allDigits(s string) bool {
	if s == "" {
		return false
	}
	for i := 0; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return true
}

func (p *Programmer) shift(l, op, r string) Result {
	if l == "" || r == "" || strings.ContainsAny(l+r, " \t") {
		shared.Throw(shared.UnknownCommand, "Not a command. Try help")
	}
	a := ParseLiteral(l, p.base)
	n, err := strconv.Atoi(r)
	// The count is always a plain decimal 0-63, whatever the input base.
	if !allDigits(r) || err != nil || n < 0 || n > 63 {
		shared.Throw(shared.InvalidShift, "A shift count must be a whole number from 0 to 63")
	}
	var v int64
	switch op {
	case "<<":
		v = int64(uint64(a) << uint(n)) // bits past bit 63 are discarded
	case ">>":
		v = a >> uint(n) // arithmetic: sign-extending
	default:
		v = int64(uint64(a) >> uint(n)) // logical: zero-filling
	}
	return Result{Kind: KindValue, Value: v}
}

func baseOrThrow(name string) int {
	b, ok := ParseBase(name)
	if !ok {
		shared.Throw(shared.InvalidBase, "'%s' is not a base. Use bin, oct, dec or hex", name)
	}
	return b
}

func convertBases(val, from, to string) Result {
	fb, tb := baseOrThrow(from), baseOrThrow(to)
	return Result{Kind: KindText, Text: FormatBase(ParseLiteral(val, fb), tb)}
}

func (p *Programmer) exec(line string) Result {
	line = strings.TrimSpace(line)
	if line == "" {
		shared.Throw(shared.UnknownCommand, "Type a number or a command. Try help")
	}
	if l, op, r, ok := splitShift(line); ok {
		return p.shift(l, op, r)
	}
	f := strings.Fields(line)
	switch w := strings.ToLower(f[0]); {
	case w == "base":
		if len(f) != 2 {
			shared.Throw(shared.InvalidBase, "Use: base bin | oct | dec | hex")
		}
		p.base = baseOrThrow(f[1])
		return Result{Kind: KindBase, Text: BaseName(p.base)}
	case w == "convert":
		if len(f) != 4 {
			shared.Throw(shared.UnknownCommand, "Use: convert <value> <from> <to>")
		}
		return convertBases(f[1], f[2], f[3])
	case w == "not":
		if len(f) != 2 {
			shared.Throw(shared.UnknownCommand, "Use: NOT <value>")
		}
		return Result{Kind: KindValue, Value: ^ParseLiteral(f[1], p.base)}
	}
	switch len(f) {
	case 1:
		return Result{Kind: KindValue, Value: ParseLiteral(f[0], p.base)}
	case 3:
		// The operator is always the middle word (R11).
		switch op := strings.ToLower(f[1]); op {
		case "and", "or", "xor":
			a, b := ParseLiteral(f[0], p.base), ParseLiteral(f[2], p.base)
			var v int64
			switch op {
			case "and":
				v = a & b
			case "or":
				v = a | b
			default:
				v = a ^ b
			}
			return Result{Kind: KindValue, Value: v}
		}
		// "255 dec hex": the word convert is optional (R24).
		if fb, ok := ParseBase(f[1]); ok {
			if tb, ok2 := ParseBase(f[2]); ok2 {
				return convertBases(f[0], BaseName(fb), BaseName(tb))
			}
		}
	}
	shared.Throw(shared.UnknownCommand, "Not a command. Try help")
	return Result{}
}