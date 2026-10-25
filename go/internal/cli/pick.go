package cli

import (
	"fmt"
	"strconv"
	"strings"
)

// Io is the one small object every screen talks to.
type Io interface {
	Write(s string)
	ReadLine(prompt string) (line string, ok bool) // ok=false at end of input
	ReadLinePrefill(prompt, prefill string) (line string, ok bool)
	HasSelector() bool
	Select(o Opts) (SelResult, error)
}

// Option is one answer. Key overrides the number shown in numbered lists
// (the main menu's "0) Exit"); Match lists extra typed names or symbols.
type Option struct {
	Label string
	Key   string
	Match []string
}

type PickKind int

const (
	PickChoice PickKind = iota
	PickBack
	PickQuit
	PickEOF
)

// PickResult is the answer to one question.
type PickResult struct {
	Kind  PickKind
	Index int
}

// PickSpec is one question. Line, if set, runs a typed one-line command and
// reports whether it handled the line (the converter's `100 cm in`).
type PickSpec struct {
	Title      string
	Options    []Option
	Back, Quit bool
	Line       func(line string) bool
}

func (sp PickSpec) find(raw string) int {
	l := strings.ToLower(strings.TrimSpace(raw))
	for i, o := range sp.Options {
		key := o.Key
		if key == "" {
			key = strconv.Itoa(i + 1)
		}
		if l == key || l == strings.ToLower(o.Label) {
			return i
		}
		for _, m := range o.Match {
			if l == strings.ToLower(m) {
				return i
			}
		}
	}
	return -1
}

func plainList(sp PickSpec) string {
	var b strings.Builder
	b.WriteString(sp.Title)
	b.WriteByte('\n')
	for i, o := range sp.Options {
		key := o.Key
		if key == "" {
			key = strconv.Itoa(i + 1)
		}
		fmt.Fprintf(&b, "  %s) %s\n", key, o.Label)
	}
	return b.String()
}

// Pick asks one question with many answers: an arrow-key selector when the Io
// has one, otherwise a numbered list answered by a number, a name or a symbol.
func Pick(ui Io, sp PickSpec) PickResult {
	// handle deals with one typed line; done=true means "return res".
	handle := func(raw string) (res PickResult, done bool) {
		l := strings.ToLower(strings.TrimSpace(raw))
		switch {
		case l == "":
			return res, false
		case l == "help" || l == "?":
			h := "Type a number, a name or a symbol."
			if sp.Back {
				h += " back goes back."
			}
			ui.Write(h + " quit exits.\n")
			return res, false
		case l == "back" && sp.Back:
			return PickResult{Kind: PickBack}, true
		case l == "quit":
			return PickResult{Kind: PickQuit}, true
		}
		if i := sp.find(l); i >= 0 {
			return PickResult{Kind: PickChoice, Index: i}, true
		}
		if sp.Line != nil && sp.Line(raw) {
			return res, false
		}
		ui.Write("Error [UNKNOWN_COMMAND]: Pick one from the list\n")
		return res, false
	}

	if ui.HasSelector() {
		labels := make([]string, len(sp.Options))
		for i, o := range sp.Options {
			labels[i] = o.Label
		}
		o := Opts{Title: sp.Title, Labels: labels, Back: sp.Back, Quit: sp.Quit, Typing: true}
		for {
			r, err := ui.Select(o)
			if err != nil {
				break // the terminal failed: fall back to the numbered list
			}
			switch r.Out { // b, q and Esc act at once, with no prompt line
			case OSelect:
				return PickResult{Kind: PickChoice, Index: r.Index}
			case OBack:
				return PickResult{Kind: PickBack}
			case OQuit:
				return PickResult{Kind: PickQuit}
			case OAbort:
				return PickResult{Kind: PickEOF}
			case OTyped: // the prompt shows the key; the rest of the line is read
				line, ok := ui.ReadLinePrefill("> ", string(r.Ch))
				if !ok {
					return PickResult{Kind: PickEOF}
				}
				if res, done := handle(line); done {
					return res
				}
			}
		}
	}

	ui.Write(plainList(sp))
	for {
		line, ok := ui.ReadLine("> ")
		if !ok {
			return PickResult{Kind: PickEOF}
		}
		if res, done := handle(line); done {
			return res
		}
	}
}