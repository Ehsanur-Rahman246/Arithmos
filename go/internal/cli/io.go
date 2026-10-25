package cli

import (
	"bufio"
	"io"
	"os"
	"strings"
	"time"
)

// TermIO is the real Io. With keys == nil it is the numbered-list baseline
// (pipes, files, tests, dumb terminals, ARITHMOS_PLAIN=1).
type TermIO struct {
	in     *bufio.Reader
	out    io.Writer
	keys   KeySource
	color  bool
	screen *termScreen
}

// NewPlainIO has no selector.
func NewPlainIO(in io.Reader, out io.Writer) *TermIO {
	return &TermIO{in: bufio.NewReader(in), out: out}
}

// NewTerminalIO has the arrow-key selector. NO_COLOR=1 switches colour off.
func NewTerminalIO(in io.Reader, out io.Writer) *TermIO {
	t := &TermIO{in: bufio.NewReader(in), out: out, keys: platformKeys(), color: os.Getenv("NO_COLOR") == ""}
	t.screen = &termScreen{t: t}
	return t
}

func (t *TermIO) Write(s string) { io.WriteString(t.out, s) }

// ReadLine reads a whole line in the terminal's normal (cooked) mode.
func (t *TermIO) ReadLine(prompt string) (string, bool) {
	t.Write(prompt)
	s, err := t.in.ReadString('\n')
	if err != nil && s == "" {
		t.Write("\n") // end of input: leave the shell on a fresh line
		return "", false
	}
	return strings.TrimRight(s, "\r\n"), true
}

// ReadLinePrefill shows the key that opened the typed line, then reads the rest.
func (t *TermIO) ReadLinePrefill(prompt, prefill string) (string, bool) {
	t.Write(prompt + prefill)
	s, err := t.in.ReadString('\n')
	if err != nil && s == "" {
		t.Write("\n")
		return "", false
	}
	return prefill + strings.TrimRight(s, "\r\n"), true
}

func (t *TermIO) HasSelector() bool { return t.keys != nil }

func (t *TermIO) Select(o Opts) (SelResult, error) { return RunSelector(o, t.keys, t.screen) }

// termScreen measures the terminal on every redraw, cached for 150 ms.
type termScreen struct {
	t    *TermIO
	at   time.Time
	w, h int
}

func (s *termScreen) Write(x string) { s.t.Write(x) }
func (s *termScreen) Color() bool    { return s.t.color }
func (s *termScreen) Size() (int, int) {
	if s.w == 0 || time.Since(s.at) > 150*time.Millisecond {
		s.w, s.h = platformSize()
		s.at = time.Now()
	}
	return s.w, s.h
}