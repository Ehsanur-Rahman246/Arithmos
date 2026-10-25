// Go extras: formatting boundaries, unit-table sanity, garbage input, scripted
// CLI sessions and one-shot exit codes.
package arithmos_test

import (
	"bytes"
	"math"
	"strings"
	"testing"

	"arithmos/internal/calculator"
	"arithmos/internal/cli"
	"arithmos/internal/converter"
	"arithmos/internal/programmer"
	"arithmos/internal/shared"
)

func TestFormatBoundaries(t *testing.T) {
	cases := []struct {
		in   float64
		want string
	}{
		{0.1 + 0.2, "0.3"}, {100000000000.5, "100000000001"}, {1e15, "1e+15"},
		{999999999999999, "1e+15"}, {1e-6, "0.000001"}, {2e-7, "2e-7"},
		{1.5e20, "1.5e+20"}, {math.Copysign(0, -1), "0"}, {-2.5, "-2.5"},
		{999999999999.9, "1000000000000"}, {123456789012345, "123456789012000"},
		{1.0 / 3, "0.333333333333"}, {2.0 / 3, "0.666666666667"},
	}
	for _, c := range cases {
		got, err := shared.FormatNumber(c.in)
		if err != nil || got != c.want {
			t.Errorf("FormatNumber(%v) = %q, %v; want %q", c.in, got, err, c.want)
		}
	}
	if _, err := shared.FormatNumber(math.Inf(1)); shared.CodeOf(err) != shared.Overflow {
		t.Error("Inf must be OVERFLOW")
	}
	if _, err := shared.FormatNumber(math.NaN()); err == nil {
		t.Error("NaN must be an error")
	}
}

func TestSettledAmendments(t *testing.T) {
	std := map[string]string{
		"200 + (10%)": "200.1", "200 + 5 * 10%": "200.5", "2^50%": "1.41421356237",
		"50%%": "0.005", "5 of 10": "50", "10^-400": "0", "ANS": "0", "SQRT(4)": "2",
	}
	for in, want := range std {
		got, err := calculator.New().Run(in)
		if err != nil || got != want {
			t.Errorf("std %q = %q, %v; want %q", in, got, err, want)
		}
	}
	for _, bad := range []string{"1e5", ".", "5.5.5", "2 3", "sqrt 4", "of 5", "", "   "} {
		if _, err := calculator.New().Run(bad); shared.CodeOf(err) != shared.InvalidExpression {
			t.Errorf("std %q should be INVALID_EXPRESSION, got %v", bad, err)
		}
	}
	p := programmer.New()
	p.Execute("base hex")
	r, _ := p.Execute("A AND F")
	if r.Value != 0xA {
		t.Errorf("A AND F = %d", r.Value)
	}
	r, _ = programmer.New().Execute("1<<3") // R29: no spaces needed
	if r.Value != 8 {
		t.Errorf("1<<3 = %d", r.Value)
	}
	if _, err := programmer.New().Execute("0x"); shared.CodeOf(err) != shared.InvalidDigit {
		t.Errorf("bare 0x in dec mode: %v", err)
	}
	if _, err := programmer.New().Execute("1 << 2.5"); shared.CodeOf(err) != shared.InvalidShift {
		t.Error("1 << 2.5 should be INVALID_SHIFT")
	}
	if _, err := converter.Execute("convert 1e3 m cm"); shared.CodeOf(err) != shared.InvalidNumber {
		t.Error("1e3 should be INVALID_NUMBER")
	}
	if _, err := converter.Execute("list foo"); shared.CodeOf(err) != shared.UnknownCommand {
		t.Error("list foo should be UNKNOWN_COMMAND")
	}
	if l, err := converter.Execute("convert 0 k all"); err != nil || len(l) != 3 {
		t.Errorf("0 k all must list three lines: %v %v", l, err)
	}
}

func TestUnitTableSanity(t *testing.T) {
	seen, total := map[string]bool{}, 0
	for _, c := range converter.Categories {
		for _, u := range c.Units {
			total++
			if seen[u.Symbol] || u.Symbol != strings.ToLower(u.Symbol) {
				t.Errorf("duplicate or non-lower-case symbol %q", u.Symbol)
			}
			seen[u.Symbol] = true
		}
	}
	if len(converter.Categories) != 12 {
		t.Errorf("want 12 categories, got %d", len(converter.Categories))
	}
	if total != len(seen) {
		t.Error("symbols must be unique across categories")
	}
}

func TestGarbageNeverPanics(t *testing.T) {
	inputs := []string{"", " ", "(((", ")", "\x00", "💥", "1 <<", "<< 1", "- - -", "0x", "convert",
		"list list list", "5 AND", "NOT", "base", "1 >>> 99", "99999999999999999999999", "--1",
		"sqrt(", "%", "^", "1 +* 2", "list ///", "convert 1 m", "1e999", strings.Repeat("9", 400)}
	for _, in := range inputs {
		calculator.New().Run(in)
		programmer.New().Execute(in)
		converter.Execute(in)
	}
}

func TestScriptedSession(t *testing.T) {
	script := strings.Join([]string{
		"1", "2 + 3", "10 / 0", "ans", "back", // standard
		"2", "5 AND 3", "base hex", "FF", "back", // programmer
		"3", "length", "m", "yd", "100", "back", "back", "back", "back", // converter, all the way out
		"0",
	}, "\n") + "\n"
	var out bytes.Buffer
	cli.RunInteractive(cli.NewPlainIO(strings.NewReader(script), &out))
	s := out.String()
	// Piped input is not echoed, so the result follows the prompt on the same line.
	for _, want := range []string{"Arithmos 1.0 — Core CLI", "  0) Exit", "standard> 5\n", "Error [DIV_BY_ZERO]",
		"DEC: 1", "Input base: hex", "DEC: 255", "converter (m → yd)> ", "100 m = 109.361329834 yd"} {
		if !strings.Contains(s, want) {
			t.Errorf("session output lacks %q:\n%s", want, s)
		}
	}

	// "5" is printed twice: once for 2 + 3, once for `ans` after the failed division.
	if n := strings.Count(s, "standard> 5\n"); n != 2 {
		t.Errorf("ans should survive the failed line: want 2 results of 5, got %d", n)
	}
}

func TestEndOfInputExitsCleanly(t *testing.T) {
	var out bytes.Buffer
	cli.RunInteractive(cli.NewPlainIO(strings.NewReader("1\n2 + 2\n"), &out)) // EOF inside a tool
	if !strings.Contains(out.String(), "4\n") {
		t.Errorf("got %q", out.String())
	}
}

func TestOneShotExitCodes(t *testing.T) {
	cases := []struct {
		args   []string
		code   int
		stdout string
	}{
		{[]string{"std", "2 + 3 * 4"}, 0, "14\n"},
		{[]string{"STD", "20% of 150"}, 0, "30\n"},
		{[]string{"standard", "10 / 0"}, 1, ""},
		{[]string{"prog", "0xFF", "AND", "0x0F"}, 0, "HEX: F\nDEC: 15\nOCT: 17\nBIN: 1111\n"},
		{[]string{"convert", "100", "cm", "in"}, 0, "39.3700787402\n"},
		{[]string{"list", "length"}, 0, "pm, ang, nm, um, mm, cm, m, km, in, ft, yd, mi, nmi, au, ly\n"},
		{[]string{"std"}, 2, ""},
		{[]string{"frobnicate"}, 2, ""},
	}
	for _, c := range cases {
		var out, errb bytes.Buffer
		if got := cli.RunOneShot(c.args, &out, &errb); got != c.code {
			t.Errorf("%v: exit %d, want %d", c.args, got, c.code)
		}
		if out.String() != c.stdout {
			t.Errorf("%v: stdout %q, want %q", c.args, out.String(), c.stdout)
		}
		if c.code == 1 && !strings.HasPrefix(errb.String(), "Error [") {
			t.Errorf("%v: stderr %q", c.args, errb.String())
		}
	}
}