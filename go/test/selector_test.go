// Selector tests SL1-SL21 plus X2 (widths, heights, erase) and X3 (key bytes).
package arithmos_test

import (
	"fmt"
	"io"
	"strings"
	"testing"

	"arithmos/internal/cli"
)

// ------------------------------------------------------------------- fakes

type fakeKeys struct {
	q             []cli.Key
	entered, left int
}

func (f *fakeKeys) Enter() error { f.entered++; return nil }
func (f *fakeKeys) Leave()       { f.left++ }
func (f *fakeKeys) ReadKey() (cli.Key, error) {
	if len(f.q) == 0 {
		return cli.Key{}, io.EOF
	}
	k := f.q[0]
	f.q = f.q[1:]
	return k, nil
}

type fakeScreen struct {
	buf   strings.Builder
	w, h  int
	color bool
}

func (s *fakeScreen) Write(t string)      { s.buf.WriteString(t) }
func (s *fakeScreen) Size() (int, int)    { return s.w, s.h }
func (s *fakeScreen) Color() bool         { return s.color }

type fakeIO struct {
	out                 strings.Builder
	lines               []string
	sels                []cli.SelResult
	hasSel              bool
	selCalls, lineCalls int
}

func (f *fakeIO) Write(s string) { f.out.WriteString(s) }
func (f *fakeIO) next() (string, bool) {
	f.lineCalls++
	if len(f.lines) == 0 {
		return "", false
	}
	l := f.lines[0]
	f.lines = f.lines[1:]
	return l, true
}
func (f *fakeIO) ReadLine(string) (string, bool)          { return f.next() }
func (f *fakeIO) ReadLinePrefill(string, string) (string, bool) { return f.next() }
func (f *fakeIO) HasSelector() bool                       { return f.hasSel }
func (f *fakeIO) Select(cli.Opts) (cli.SelResult, error) {
	f.selCalls++
	if len(f.sels) == 0 {
		return cli.SelResult{Out: cli.OAbort}, nil
	}
	r := f.sels[0]
	f.sels = f.sels[1:]
	return r, nil
}

func kk(k cli.KeyKind) cli.Key { return cli.Key{Kind: k} }
func ch(r rune) cli.Key        { return cli.Key{Kind: cli.KChar, Ch: r} }

func labels(n int) []string {
	l := make([]string, n)
	for i := range l {
		l[i] = fmt.Sprintf("item%d", i)
	}
	return l
}

func eq[T comparable](t *testing.T, got, want T) {
	t.Helper()
	if got != want {
		t.Errorf("got %v, want %v", got, want)
	}
}

func has(t *testing.T, s, sub string) {
	t.Helper()
	if !strings.Contains(s, sub) {
		t.Errorf("%q does not contain %q", s, sub)
	}
}

func handle(o cli.Opts, k cli.Key) cli.Step { return cli.Handle(o, cli.State{}, k) }

var opts3 = cli.Opts{Title: "T", Labels: labels(3)}

// -------------------------------------------------------- key handling SL1-8

func TestSL1Move(t *testing.T) {
	s := cli.State{}
	s = cli.Handle(opts3, s, kk(cli.KDown)).State
	eq(t, s.Index, 1)
	s = cli.Handle(opts3, cli.Handle(opts3, s, kk(cli.KDown)).State, kk(cli.KDown)).State
	eq(t, s.Index, 0) // wrapped
	eq(t, cli.Handle(opts3, s, kk(cli.KUp)).State.Index, 2)
	eq(t, cli.Handle(opts3, cli.State{Index: 2}, kk(cli.KHome)).State.Index, 0)
	eq(t, cli.Handle(opts3, cli.State{}, kk(cli.KEnd)).State.Index, 2)
}

func TestSL2Scroll(t *testing.T) {
	o := cli.Opts{Title: "T", Labels: labels(15)}
	s := cli.State{}
	for i := 0; i < 10; i++ {
		s = cli.Handle(o, s, kk(cli.KDown)).State
	}
	eq(t, s.Index, 10)
	eq(t, s.Top, 1)
	lines := cli.Draw(o, s, cli.DrawCtx{Width: 40, Height: 40})
	eq(t, len(lines), 12) // title + 10 rows + hint
	all := strings.Join(lines, "\n")
	has(t, all, "item10")
	if strings.Contains(all, "item0") {
		t.Error("item0 should have scrolled out")
	}
}

func TestSL3OfferedKeys(t *testing.T) {
	eq(t, handle(opts3, kk(cli.KEnter)).Out, cli.OSelect)
	eq(t, handle(opts3, kk(cli.KEsc)).Out, cli.OContinue)
	eq(t, handle(opts3, ch('b')).Out, cli.OContinue)
	eq(t, handle(opts3, ch('q')).Out, cli.OContinue)
	o := opts3
	o.Back, o.Quit = true, true
	eq(t, handle(o, kk(cli.KEsc)).Out, cli.OBack)
	eq(t, handle(o, ch('b')).Out, cli.OBack)
	eq(t, handle(o, ch('q')).Out, cli.OQuit)
}

func TestSL4Abort(t *testing.T) {
	eq(t, handle(opts3, kk(cli.KCtrlC)).Out, cli.OAbort)
	eq(t, handle(opts3, kk(cli.KCtrlD)).Out, cli.OAbort)
	eq(t, handle(opts3, kk(cli.KOther)).Out, cli.OContinue)
}

func TestSL5TypingOn(t *testing.T) {
	o := opts3
	o.Typing = true
	st := handle(o, ch('5'))
	eq(t, st.Out, cli.OTyped)
	eq(t, st.Ch, '5')
	st = handle(o, ch('b')) // b is not offered, so it is typed
	eq(t, st.Out, cli.OTyped)
}

func TestSL6TypingOff(t *testing.T) {
	eq(t, handle(opts3, ch('5')).Out, cli.OContinue)
}

func TestSL7TypingKeepsMeanings(t *testing.T) {
	o := cli.Opts{Title: "T", Labels: labels(3), Back: true, Quit: true, Typing: true}
	eq(t, handle(o, kk(cli.KEsc)).Out, cli.OBack)
	eq(t, handle(o, ch('b')).Out, cli.OBack)
	eq(t, handle(o, ch('q')).Out, cli.OQuit)
	eq(t, handle(o, kk(cli.KDown)).State.Index, 1)
	eq(t, handle(o, kk(cli.KEnter)).Out, cli.OSelect)
}

func TestSL8SpaceAndControl(t *testing.T) {
	o := opts3
	o.Typing = true
	eq(t, handle(o, ch(' ')).Out, cli.OContinue)
	eq(t, handle(o, kk(cli.KOther)).Out, cli.OContinue)
}

// ------------------------------------------------------------- drawing SL9-12

func TestSL9Bar(t *testing.T) {
	lines := cli.Draw(opts3, cli.State{Index: 1}, cli.DrawCtx{Width: 20, Height: 24, Color: true})
	var bar string
	for _, l := range lines {
		if strings.HasPrefix(l, "\x1b[7m") {
			bar = l
		}
	}
	if bar == "" {
		t.Fatal("no reverse-video bar")
	}
	inner := strings.TrimSuffix(strings.TrimPrefix(bar, "\x1b[7m"), "\x1b[0m")
	eq(t, len([]rune(inner)), 19) // full bar: width-1 columns
}

func TestSL10PlainPointer(t *testing.T) {
	lines := cli.Draw(opts3, cli.State{Index: 1}, cli.DrawCtx{Width: 30, Height: 24})
	eq(t, lines[1], "  item0")
	eq(t, lines[2], "❯ item1")
}

func TestSL11HintOnlyOfferedKeys(t *testing.T) {
	h := cli.Hint(opts3)
	if strings.Contains(h, "back") || strings.Contains(h, "quit") || strings.Contains(h, "type") {
		t.Errorf("hint lists keys not on offer: %q", h)
	}
	o := opts3
	o.Quit = true
	has(t, cli.Hint(o), "q quit")
}

func TestSL12HintBackAndType(t *testing.T) {
	h := cli.Hint(cli.Opts{Labels: labels(2), Back: true, Typing: true})
	has(t, h, "Esc/b back")
	has(t, h, "or type")
}

// --------------------------------------------------------------- loop SL13-15

func TestSL13LoopSelect(t *testing.T) {
	k := &fakeKeys{q: []cli.Key{kk(cli.KDown), kk(cli.KEnter)}}
	s := &fakeScreen{w: 40, h: 24}
	r, err := cli.RunSelector(opts3, k, s)
	eq(t, err, nil)
	eq(t, r.Out, cli.OSelect)
	eq(t, r.Index, 1)
	out := s.buf.String()
	has(t, out, "✔ T: item1")
	has(t, out, "\x1b[?25l")
	has(t, out, "\x1b[?25h") // cursor restored
	eq(t, k.entered, 1)
	eq(t, k.left, 1)
}

func TestSL14LoopEscIgnoredCtrlC(t *testing.T) {
	o := opts3
	o.Back = true
	r, _ := cli.RunSelector(o, &fakeKeys{q: []cli.Key{kk(cli.KOther), kk(cli.KEsc)}}, &fakeScreen{w: 40, h: 24})
	eq(t, r.Out, cli.OBack)
	r, _ = cli.RunSelector(o, &fakeKeys{q: []cli.Key{kk(cli.KCtrlC)}}, &fakeScreen{w: 40, h: 24})
	eq(t, r.Out, cli.OAbort)
}

func TestSL15LoopTyped(t *testing.T) {
	o := opts3
	o.Typing = true
	s := &fakeScreen{w: 40, h: 24}
	r, _ := cli.RunSelector(o, &fakeKeys{q: []cli.Key{ch('x')}}, s)
	eq(t, r.Out, cli.OTyped)
	eq(t, r.Ch, 'x')
	has(t, s.buf.String(), "\x1b[?25h")
	if strings.Contains(s.buf.String(), "✔") {
		t.Error("a typed key must not leave a summary")
	}
}

// ---------------------------------------------------------------- pick SL16-21

func spec() cli.PickSpec {
	return cli.PickSpec{Title: "Pick", Back: true, Quit: true, Options: []cli.Option{
		{Label: "alpha", Match: []string{"a1"}}, {Label: "beta"}, {Label: "gamma"},
	}}
}

func TestSL16PickUsesSelector(t *testing.T) {
	for out, want := range map[cli.Outcome]cli.PickKind{
		cli.OBack: cli.PickBack, cli.OQuit: cli.PickQuit, cli.OAbort: cli.PickEOF,
	} {
		f := &fakeIO{hasSel: true, sels: []cli.SelResult{{Out: out}}}
		eq(t, cli.Pick(f, spec()).Kind, want)
	}
	f := &fakeIO{hasSel: true, sels: []cli.SelResult{{Out: cli.OSelect, Index: 1}}}
	r := cli.Pick(f, spec())
	eq(t, r.Kind, cli.PickChoice)
	eq(t, r.Index, 1)
}

func TestSL17TypedNameOrNumber(t *testing.T) {
	f := &fakeIO{hasSel: true, lines: []string{"beta"}, sels: []cli.SelResult{{Out: cli.OTyped, Ch: 'b'}}}
	eq(t, cli.Pick(f, spec()).Index, 1)
	f = &fakeIO{hasSel: true, lines: []string{"3"}, sels: []cli.SelResult{{Out: cli.OTyped, Ch: '3'}}}
	eq(t, cli.Pick(f, spec()).Index, 2)
}

func TestSL18TypedOneLineCommand(t *testing.T) {
	var called []string
	sp := spec()
	sp.Line = func(l string) bool { called = append(called, l); return true }
	f := &fakeIO{hasSel: true, lines: []string{"100 cm in"},
		sels: []cli.SelResult{{Out: cli.OTyped, Ch: '1'}, {Out: cli.OSelect, Index: 2}}}
	r := cli.Pick(f, sp)
	eq(t, r.Index, 2) // the list came back
	eq(t, strings.Join(called, ","), "100 cm in")
}

func TestSL19UnknownWord(t *testing.T) {
	f := &fakeIO{hasSel: true, lines: []string{"zzz"},
		sels: []cli.SelResult{{Out: cli.OTyped, Ch: 'z'}, {Out: cli.OSelect, Index: 0}}}
	cli.Pick(f, spec())
	has(t, f.out.String(), "UNKNOWN_COMMAND")
	eq(t, f.selCalls, 2)
}

func TestSL20KeysActAtOnce(t *testing.T) {
	for _, out := range []cli.Outcome{cli.OBack, cli.OQuit} {
		f := &fakeIO{hasSel: true, sels: []cli.SelResult{{Out: out}}}
		cli.Pick(f, spec())
		eq(t, f.lineCalls, 0) // no prompt line was read
	}
}

func TestSL21NumberedList(t *testing.T) {
	f := &fakeIO{lines: []string{"2"}}
	eq(t, cli.Pick(f, spec()).Index, 1)
	has(t, f.out.String(), "  1) alpha")
	f = &fakeIO{lines: []string{"back"}}
	eq(t, cli.Pick(f, spec()).Kind, cli.PickBack)
	f = &fakeIO{lines: []string{"nope", "gamma"}}
	eq(t, cli.Pick(f, spec()).Index, 2)
	has(t, f.out.String(), "UNKNOWN_COMMAND")
}

// ------------------------------------------------------------------- X2, X3

func TestX2WidthHeightErase(t *testing.T) {
	long := strings.Repeat("x", 60)
	o := cli.Opts{Title: long, Labels: []string{long, long}, Back: true, Quit: true, Typing: true}
	for _, l := range cli.Draw(o, cli.State{}, cli.DrawCtx{Width: 12, Height: 24}) {
		if n := len([]rune(l)); n > 11 {
			t.Errorf("line is %d columns wide, max 11: %q", n, l)
		}
	}
	// A short terminal shrinks the window; a redraw moves up by the drawn lines.
	o = cli.Opts{Title: "T", Labels: labels(15)}
	eq(t, cli.EffWindow(o, 8), 5)
	s := &fakeScreen{w: 40, h: 8}
	cli.RunSelector(o, &fakeKeys{q: []cli.Key{kk(cli.KDown), kk(cli.KEnter)}}, s)
	n := len(cli.Draw(cli.Opts{Title: "T", Labels: labels(15), Window: 5}, cli.State{}, cli.DrawCtx{Width: 40, Height: 8}))
	has(t, s.buf.String(), fmt.Sprintf("\x1b[%dA", n))
}

func TestX3KeyBytes(t *testing.T) {
	cases := map[string]cli.Key{
		"\x1b[A": kk(cli.KUp), "\x1b[B": kk(cli.KDown), "\x1b": kk(cli.KEsc),
		"\x1b[H": kk(cli.KHome), "\x1b[4~": kk(cli.KEnd), "\x1b[5~": kk(cli.KPgUp),
		"\x1b[6~": kk(cli.KPgDn), "\x03": kk(cli.KCtrlC), "\x04": kk(cli.KCtrlD),
		"\r": kk(cli.KEnter), "x": ch('x'), "é": ch('é'), "\x01": kk(cli.KOther),
	}
	for in, want := range cases {
		eq(t, cli.ParseKey([]byte(in)), want)
	}
}