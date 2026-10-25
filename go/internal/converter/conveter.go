package converter

import (
	"math"
	"regexp"
	"strconv"
	"strings"

	"arithmos/internal/shared"
)

var numRe = regexp.MustCompile(`^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)$`)

func lookup(sym string) entry {
	e, ok := index[strings.ToLower(sym)]
	if !ok {
		shared.Throw(shared.UnknownUnit, "'%s' is not a known unit. Try: list", sym)
	}
	return e
}

// parseValue accepts a plain decimal only: "1e3" and "1,000" are INVALID_NUMBER (R16).
func parseValue(s string) float64 {
	if !numRe.MatchString(s) {
		shared.Throw(shared.InvalidNumber, "'%s' is not a number", s)
	}
	v, _ := strconv.ParseFloat(s, 64)
	if math.IsInf(v, 0) {
		shared.Throw(shared.Overflow, "That number is too large")
	}
	return v
}

func toC(v float64, sym string) float64 {
	switch sym {
	case "f":
		return (v - 32) * 5 / 9
	case "k":
		return v - 273.15
	}
	return v
}

func fromC(c float64, sym string) float64 {
	switch sym {
	case "f":
		return c*9/5 + 32
	case "k":
		return c + 273.15
	}
	return c
}

func belowZero(v float64, sym string) bool {
	switch sym {
	case "c":
		return v < -273.15
	case "f":
		return v < -459.67
	}
	return v < 0
}

func temperature(v float64, from, to string) float64 {
	if belowZero(v, from) {
		shared.Throw(shared.BelowAbsoluteZero, "That is below absolute zero")
	}
	r := fromC(toC(v, from), to)
	if to == "k" && math.Abs(r) < 1e-9 { // exactly at the limit stays 0
		r = 0
	}
	return r
}

func convert(v float64, f, t entry) float64 {
	if f.cat != t.cat {
		shared.Throw(shared.IncompatibleUnits, "Cannot convert %s to %s", f.cat.Name, t.cat.Name)
	}
	if f.cat.Name == "temperature" {
		return temperature(v, f.unit.Symbol, t.unit.Symbol)
	}
	r := v * f.unit.Factor / t.unit.Factor // value x from.factor / to.factor
	if math.IsInf(r, 0) || math.IsNaN(r) {
		shared.Throw(shared.Overflow, "Result is too large to represent")
	}
	return r
}

func format(v float64) string {
	s, err := shared.FormatNumber(v)
	if err != nil {
		shared.Throw(shared.CodeOf(err), "%s", err.Error())
	}
	return s
}

// convertAll lists the value in every unit of the source's category, in table
// order, source included. Any failure fails the whole command (R18).
func convertAll(val, from string) []string {
	v := parseValue(val)
	f := lookup(from)
	out := make([]string, 0, len(f.cat.Units))
	for i := range f.cat.Units {
		t := entry{&f.cat.Units[i], f.cat}
		out = append(out, t.unit.Symbol+": "+format(convert(v, f, t)))
	}
	return out
}

func one(val, from, to string) []string {
	if strings.EqualFold(to, "all") {
		return convertAll(val, from)
	}
	v := parseValue(val)
	f, t := lookup(from), lookup(to)
	return []string{format(convert(v, f, t))}
}

// Execute runs one one-line command: `convert <v> <from> <to|all>`,
// `<v> <from> <to|all>`, `list` or `list <category>`.
func Execute(line string) (lines []string, err error) {
	err = shared.Guard(func() { lines = execute(line) })
	return
}

func execute(line string) []string {
	f := strings.Fields(line)
	if len(f) == 0 {
		shared.Throw(shared.UnknownCommand, "Type a value, e.g. 100")
	}
	switch w := strings.ToLower(f[0]); {
	case w == "list":
		switch len(f) {
		case 1:
			names := make([]string, len(Categories))
			for i, c := range Categories {
				names[i] = c.Name
			}
			return []string{strings.Join(names, ", ")}
		case 2:
			for _, c := range Categories {
				if c.Name == strings.ToLower(f[1]) {
					syms := make([]string, len(c.Units))
					for i, un := range c.Units {
						syms[i] = un.Symbol
					}
					return []string{strings.Join(syms, ", ")}
				}
			}
			shared.Throw(shared.UnknownCommand, "'%s' is not a category. Try: list", f[1])
		}
		shared.Throw(shared.UnknownCommand, "Use: list  or  list <category>")
	case w == "convert":
		if len(f) != 4 {
			shared.Throw(shared.UnknownCommand, "Use: convert <value> <from> <to>")
		}
		return one(f[1], f[2], f[3])
	case len(f) == 3:
		return one(f[0], f[1], f[2])
	}
	shared.Throw(shared.UnknownCommand, "Not a command. Try: convert 100 cm in")
	return nil
}

// Pair converts with units already chosen (the guided flow's values prompt)
// and returns e.g. "100 m = 109.361329834 yd".
func Pair(val, from, to string) (line string, err error) {
	err = shared.Guard(func() {
		v := parseValue(val)
		f, t := lookup(from), lookup(to)
		line = format(v) + " " + f.unit.Symbol + " = " + format(convert(v, f, t)) + " " + t.unit.Symbol
	})
	return
}