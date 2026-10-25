package cli

import (
	"fmt"
	"strings"
)

// Outcome is what one key press (or the whole selector run) produced.
type Outcome int

const (
	OContinue Outcome = iota
	OSelect
	OBack
	OQuit
	OAbort // Ctrl-C / Ctrl-D / read error: end of input
	OTyped // a printable key: the caller reads the rest of a typed line
)

// Opts describes one selector screen.
type Opts struct {
	Title        string
	Labels       []string
	Back, Quit   bool // keys on offer: Esc/b and q
	Typing       bool // any other printable key opens a typed line
	Window       int  // visible rows (default 10)
}

// State is the cursor position and the first visible row.
type State struct{ Index, Top int }

// Step is the result of Handle.
type Step struct {
	State State
	Out   Outcome
	Ch    rune
}

// SelResult is the result of a whole selector run.
type SelResult struct {
	Out   Outcome
	Index int
	Ch    rune
}

const defaultWindow = 10

func window(o Opts) int {
	w := o.Window
	if w <= 0 {
		w = defaultWindow
	}
	if n := len(o.Labels); w > n {
		w = n
	}
	if w < 1 {
		w = 1
	}
	return w
}

// EffWindow shrinks the window so the block (title + rows + hint) fits the terminal height.
func EffWindow(o Opts, height int) int {
	w := window(o)
	if height > 0 {
		w = min(w, max(height-3, 1))
	}
	return w
}

func fixTop(top, idx, win, n int) int {
	if idx < top {
		top = idx
	}
	if idx >= top+win {
		top = idx - win + 1
	}
	if top > n-win {
		top = n - win
	}
	if top < 0 {
		top = 0
	}
	return top
}

// Handle is pure key handling (SL1-SL8).
func Handle(o Opts, s State, k Key) Step {
	n, win := len(o.Labels), window(o)
	move := func(i int) Step {
		s.Index = i
		s.Top = fixTop(s.Top, i, win, n)
		return Step{State: s}
	}
	if n == 0 && k.Kind != KCtrlC && k.Kind != KCtrlD {
		return Step{State: s}
	}
	switch k.Kind {
	case KUp:
		return move((s.Index - 1 + n) % n) // wraps
	case KDown:
		return move((s.Index + 1) % n)
	case KHome:
		return move(0)
	case KEnd:
		return move(n - 1)
	case KPgUp:
		return move(max(0, s.Index-win))
	case KPgDn:
		return move(min(n-1, s.Index+win))
	case KEnter:
		return Step{State: s, Out: OSelect}
	case KEsc:
		if o.Back {
			return Step{State: s, Out: OBack}
		}
	case KCtrlC, KCtrlD:
		return Step{State: s, Out: OAbort}
	case KChar:
		switch {
		case k.Ch == ' ': // space never starts a typed line
		case k.Ch == 'b' && o.Back:
			return Step{State: s, Out: OBack}
		case k.Ch == 'q' && o.Quit:
			return Step{State: s, Out: OQuit}
		case o.Typing:
			return Step{State: s, Out: OTyped, Ch: k.Ch}
		}
	}
	return Step{State: s} // everything else is ignored
}

// Hint lists only the keys on offer (SL11, SL12).
func Hint(o Opts) string {
	parts := []string{"↑↓ move", "Enter select"}
	if o.Back {
		parts = append(parts, "Esc/b back")
	}
	if o.Quit {
		parts = append(parts, "q quit")
	}
	h := strings.Join(parts, " · ")
	if o.Typing {
		h += " · or type"
	}
	return h
}

// DrawCtx is the terminal the block is drawn for.
type DrawCtx struct {
	Width, Height int
	Color         bool
}

func trunc(s string, max int) string {
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	if max <= 1 {
		return "…"
	}
	return string(r[:max-1]) + "…"
}

// Draw is pure drawing (SL9, SL10, X2). Every line is at most Width-1 columns
// so one logical line is one screen line and a redraw can move up by len(lines).
func Draw(o Opts, s State, c DrawCtx) []string {
	n, win := len(o.Labels), window(o)
	maxw := c.Width - 1
	if c.Width <= 0 {
		maxw = 79
	}
	if maxw < 1 {
		maxw = 1
	}
	top := fixTop(s.Top, s.Index, win, n)

	title, hint := trunc(o.Title, maxw), trunc(Hint(o), maxw)
	if c.Color {
		title, hint = "\x1b[1m"+title+"\x1b[0m", "\x1b[2m"+hint+"\x1b[0m"
	}
	lines := []string{title}
	for i := top; i < top+win && i < n; i++ {
		if i == s.Index {
			txt := trunc("❯ "+o.Labels[i], maxw)
			if c.Color { // a full reverse-video bar
				txt = "\x1b[7m" + txt + strings.Repeat(" ", max(0, maxw-len([]rune(txt)))) + "\x1b[0m"
			}
			lines = append(lines, txt)
		} else {
			lines = append(lines, trunc("  "+o.Labels[i], maxw))
		}
	}
	return append(lines, hint)
}

// KeySource reads keys; Enter/Leave switch raw mode on and off.
type KeySource interface {
	Enter() error
	Leave()
	ReadKey() (Key, error)
}

// Screen is where the selector draws.
type Screen interface {
	Write(string)
	Size() (w, h int)
	Color() bool
}

// RunSelector is the draw/read loop (SL13-SL15, X2). The terminal is raw only
// between Enter and Leave, and the cursor is always shown again.
func RunSelector(o Opts, keys KeySource, scr Screen) (SelResult, error) {
	if err := keys.Enter(); err != nil {
		return SelResult{}, err
	}
	defer keys.Leave()
	scr.Write("\x1b[?25l") // hide cursor
	defer scr.Write("\x1b[?25h")

	st, drawn := State{}, 0
	erase := func() {
		if drawn > 0 {
			scr.Write(fmt.Sprintf("\x1b[%dA\r\x1b[J", drawn))
			drawn = 0
		}
	}
	redraw := func() { // measured on every redraw, so resizing works
		w, h := scr.Size()
		oo := o
		oo.Window = EffWindow(o, h)
		st.Top = fixTop(st.Top, st.Index, window(oo), len(o.Labels))
		lines := Draw(oo, st, DrawCtx{Width: w, Height: h, Color: scr.Color()})
		erase()
		scr.Write(strings.Join(lines, "\n") + "\n")
		drawn = len(lines)
	}
	redraw()
	for {
		k, err := keys.ReadKey()
		if err != nil {
			erase()
			return SelResult{Out: OAbort}, nil
		}
		_, h := scr.Size()
		oo := o
		oo.Window = EffWindow(o, h)
		step := Handle(oo, st, k)
		st = step.State
		if step.Out == OContinue {
			redraw()
			continue
		}
		erase()
		if step.Out == OSelect { // a chosen row leaves a summary behind
			scr.Write(fmt.Sprintf("✔ %s: %s\n", o.Title, o.Labels[st.Index]))
		}
		return SelResult{Out: step.Out, Index: st.Index, Ch: step.Ch}, nil
	}
}