package shared

import (
	"math"
	"math/big"
	"strconv"
	"strings"
)

// FormatNumber implements spec §2.3: 12 significant digits, half away from
// zero, trailing zeros trimmed, -0 -> 0, plain notation for 1e-6 <= |x| < 1e15,
// otherwise <mantissa>e<sign><exponent>.
//
// big.Float prints the *exact* binary value, so exact ties such as
// 100000000000.5 are seen as ties and rounded up (Go's own float formatting
// would round them to even).
func FormatNumber(x float64) (string, error) {
	switch {
	case math.IsNaN(x):
		return "", Errf(InvalidExpression, "Result is not a number")
	case math.IsInf(x, 0):
		return "", Errf(Overflow, "Result is too large to represent")
	case x == 0:
		return "0", nil
	}

	// A double has at most 767 significant decimal digits, so 800 is exact.
	txt := new(big.Float).SetFloat64(math.Abs(x)).Text('e', 800)
	mant, expStr, _ := strings.Cut(txt, "e")
	exp, _ := strconv.Atoi(expStr)
	digits := strings.Replace(mant, ".", "", 1)

	// Round the digit string to 12 significant digits, half away from zero.
	d := []byte(digits[:12])
	if digits[12] >= '5' {
		i := 11
		for ; i >= 0; i-- {
			if d[i] == '9' {
				d[i] = '0'
			} else {
				d[i]++
				break
			}
		}
		if i < 0 { // 999999999999.x rounded up to 1000000000000
			d = []byte("100000000000")
			exp++
		}
	}
	s := strings.TrimRight(string(d), "0") // never empty: first digit is non-zero

	var out string
	if exp >= -6 && exp < 15 { // plain notation
		if exp >= 0 {
			intLen := exp + 1
			if len(s) <= intLen {
				out = s + strings.Repeat("0", intLen-len(s))
			} else {
				out = s[:intLen] + "." + s[intLen:]
			}
		} else {
			out = "0." + strings.Repeat("0", -exp-1) + s
		}
	} else { // scientific notation
		m := s[:1]
		if len(s) > 1 {
			m += "." + s[1:]
		}
		sign, a := "+", exp
		if exp < 0 {
			sign, a = "-", -exp
		}
		out = m + "e" + sign + strconv.Itoa(a)
	}
	if x < 0 {
		out = "-" + out
	}
	return out, nil
}