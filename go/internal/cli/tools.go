package cli

import (
	"errors"
	"fmt"
	"strings"

	"arithmos/internal/calculator"
	"arithmos/internal/converter"
	"arithmos/internal/programmer"
	"arithmos/internal/shared"
)

const (
	stdIntro = "Standard Calculator — type an expression. help for commands, back to return.\n"
	stdHelp  = `Standard Calculator
  Operators:  + - * / ^    parentheses, %, of, sqrt(), abs(), ans
  Examples:   2 + 3 * 4    20% of 150    200 + 10%    sqrt(16)    ans * 2
  Commands:   help (or ?), back, quit
`
	progIntro = "Programmer Calculator — 64-bit signed integers. help for commands, back to return.\n"
	progHelp  = `Programmer Calculator
  Values:     255   0xFF   0b101   0o17   0d9   (base <bin|oct|dec|hex> sets the input base)
  Convert:    convert 255 dec hex    or    255 dec hex
  Bitwise:    5 AND 3   5 OR 3   5 XOR 3   NOT 5
  Shifts:     1 << 3   -8 >> 1 (arithmetic)   -8 >>> 1 (logical)   count is decimal 0-63
  Commands:   help (or ?), back, quit
`
	convHelp = `Unit Converter
  Type a value to convert with the chosen units, or a one-line command:
    100 cm in    convert 100 cm in    convert 1 km all    list    list length
  Commands:   help (or ?), back, quit
`
)

// errLine is the one place errors become text: Error [CODE]: message.
func errLine(err error) string {
	var e *shared.Error
	if errors.As(err, &e) {
		return fmt.Sprintf("Error [%s]: %s", e.Code, e.Message)
	}
	return fmt.Sprintf("Error [INTERNAL]: %v", err)
}

// safeRun keeps unexpected panics from crashing the program (Release 1 goal 4).
func safeRun(f func() ([]string, error)) (lines []string, err error) {
	defer func() {
		if r := recover(); r != nil {
			lines, err = nil, fmt.Errorf("%v", r)
		}
	}()
	return f()
}

func printLines(ui Io, lines []string) {
	if len(lines) > 0 {
		ui.Write(strings.Join(lines, "\n") + "\n")
	}
}

type loopEnd int

const (
	loopBack loopEnd = iota
	loopQuit
	loopEOF
)

// promptLoop: help/?, back, quit, blank lines ignored, EOF exits cleanly,
// every error printed as `Error [CODE]: message`.
func promptLoop(ui Io, prompt, help string, run func(line string) ([]string, error)) loopEnd {
	for {
		line, ok := ui.ReadLine(prompt)
		if !ok {
			return loopEOF
		}
		l := strings.TrimSpace(line)
		switch strings.ToLower(l) {
		case "":
			continue
		case "help", "?":
			ui.Write(help)
			continue
		case "back":
			return loopBack
		case "quit":
			return loopQuit
		}
		lines, err := safeRun(func() ([]string, error) { return run(l) })
		if err != nil {
			ui.Write(errLine(err) + "\n")
		} else {
			printLines(ui, lines)
		}
	}
}

func standardTool(ui Io) loopEnd {
	ui.Write(stdIntro)
	c := calculator.New()
	return promptLoop(ui, "standard> ", stdHelp, func(l string) ([]string, error) {
		s, err := c.Run(l)
		if err != nil {
			return nil, err
		}
		return []string{s}, nil
	})
}

func progLines(r programmer.Result) []string {
	switch r.Kind {
	case programmer.KindValue:
		return programmer.Lines(r.Value)
	case programmer.KindBase:
		return []string{"Input base: " + r.Text}
	}
	return []string{r.Text}
}

func programmerTool(ui Io) loopEnd {
	ui.Write(progIntro)
	p := programmer.New()
	return promptLoop(ui, "programmer> ", progHelp, func(l string) ([]string, error) {
		r, err := p.Execute(l)
		if err != nil {
			return nil, err
		}
		return progLines(r), nil
	})
}

func title(s string) string { return strings.ToUpper(s[:1]) + s[1:] }

// oneLine lets a converter picker accept `100 cm in`, `list`, `convert ...`.
func oneLine(ui Io) func(string) bool {
	return func(line string) bool {
		f := strings.Fields(line)
		if len(f) == 0 {
			return false
		}
		if w := strings.ToLower(f[0]); w != "list" && w != "convert" && len(f) != 3 {
			return false
		}
		lines, err := safeRun(func() ([]string, error) { return converter.Execute(line) })
		if err != nil {
			ui.Write(errLine(err) + "\n")
		} else {
			printLines(ui, lines)
		}
		return true
	}
}

// converterTool is the guided flow: category -> from -> to -> values.
// `back` steps back one stage and leaves to the main menu from the first.
func converterTool(ui Io) loopEnd {
	var cat *converter.Category
	var from, to *converter.Unit
	stage := 0
	for {
		var res PickResult
		switch stage {
		case 0:
			opts := make([]Option, len(converter.Categories))
			for i, c := range converter.Categories {
				opts[i] = Option{Label: title(c.Name), Match: []string{c.Name}}
			}
			res = Pick(ui, PickSpec{Title: "Unit Converter — choose a category", Options: opts,
				Back: true, Quit: true, Line: oneLine(ui)})
		case 1, 2:
			t := title(cat.Name) + " — convert from"
			if stage == 2 {
				t += " " + from.Symbol + " to"
			}
			opts := make([]Option, len(cat.Units))
			for i, un := range cat.Units {
				opts[i] = Option{Label: un.Symbol + " — " + un.Name, Match: []string{un.Symbol, un.Name}}
			}
			res = Pick(ui, PickSpec{Title: t, Options: opts, Back: true, Quit: true, Line: oneLine(ui)})
		case 3:
			prompt := fmt.Sprintf("converter (%s → %s)> ", from.Symbol, to.Symbol)
			end := promptLoop(ui, prompt, convHelp, func(l string) ([]string, error) {
				f := strings.Fields(l)
				if w := strings.ToLower(f[0]); len(f) == 1 && w != "list" && w != "convert" {
					s, err := converter.Pair(l, from.Symbol, to.Symbol)
					return []string{s}, err
				}
				return converter.Execute(l)
			})
			if end == loopBack {
				stage = 2
				continue
			}
			return end
		}
		switch res.Kind {
		case PickQuit:
			return loopQuit
		case PickEOF:
			return loopEOF
		case PickBack:
			if stage == 0 {
				return loopBack
			}
			stage--
			continue
		}
		switch stage {
		case 0:
			cat = &converter.Categories[res.Index]
		case 1:
			from = &cat.Units[res.Index]
		case 2:
			to = &cat.Units[res.Index]
		}
		stage++
	}
}

// RunInteractive is the main menu.
func RunInteractive(ui Io) {
	opts := []Option{
		{Label: "Standard Calculator"},
		{Label: "Programmer Calculator"},
		{Label: "Unit Converter"},
		{Label: "Exit", Key: "0", Match: []string{"exit"}},
	}
	for {
		r := Pick(ui, PickSpec{Title: "Arithmos 1.0 — Core CLI", Options: opts, Quit: true})
		if r.Kind != PickChoice || r.Index == 3 {
			return
		}
		var end loopEnd
		switch r.Index {
		case 0:
			end = standardTool(ui)
		case 1:
			end = programmerTool(ui)
		case 2:
			end = converterTool(ui)
		}
		if end != loopBack {
			return
		}
	}
}