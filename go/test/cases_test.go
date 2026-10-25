// Runs the shared cases from docs/release-1-cases.json (loader contract:
// test-cases.md). Set CASES=path to use another file.
package arithmos_test

import (
	"encoding/json"
	"os"
	"strings"
	"testing"

	"arithmos/internal/calculator"
	"arithmos/internal/converter"
	"arithmos/internal/programmer"
	"arithmos/internal/shared"
)

type step struct {
	Input    string          `json:"input"`
	Expected json.RawMessage `json:"expected"`
	Error    string          `json:"error"`
}

type tcase struct {
	ID               string          `json:"id"`
	Tool             string          `json:"tool"`
	Input            string          `json:"input"`
	Setup            []string        `json:"setup"`
	Steps            []step          `json:"steps"`
	Expected         json.RawMessage `json:"expected"`
	ExpectedContains []string        `json:"expectedContains"`
	Error            string          `json:"error"`
}

type outcome struct {
	err   error
	text  string
	lines []string
	res   programmer.Result
}

type session struct {
	tool string
	calc *calculator.Calculator
	prog *programmer.Programmer
}

func newSession(tool string) *session {
	return &session{tool: tool, calc: calculator.New(), prog: programmer.New()}
}

func (s *session) run(line string) outcome {
	switch s.tool {
	case "standard":
		txt, err := s.calc.Run(line)
		return outcome{err: err, text: txt, lines: []string{txt}}
	case "programmer":
		r, err := s.prog.Execute(line)
		return outcome{err: err, text: r.Text, res: r}
	}
	lines, err := converter.Execute(line)
	o := outcome{err: err, lines: lines}
	if len(lines) > 0 {
		o.text = lines[0]
	}
	return o
}

func check(t *testing.T, id string, o outcome, expected json.RawMessage, contains []string, code string) {
	t.Helper()
	if code != "" {
		if got := shared.CodeOf(o.err); got != code {
			t.Errorf("%s: want error %s, got %q (err=%v)", id, code, got, o.err)
		}
		return
	}
	if o.err != nil {
		t.Errorf("%s: unexpected error: %v", id, o.err)
		return
	}
	if len(expected) > 0 {
		if expected[0] == '"' { // a string
			var want string
			json.Unmarshal(expected, &want)
			if o.text != want {
				t.Errorf("%s: want %q, got %q", id, want, o.text)
			}
		} else { // an object of HEX/DEC/OCT/BIN
			var want map[string]string
			json.Unmarshal(expected, &want)
			if o.res.Kind != programmer.KindValue {
				t.Errorf("%s: expected a value result", id)
				return
			}
			got := programmer.FormatMap(o.res.Value)
			for k, v := range want {
				if got[k] != v {
					t.Errorf("%s: %s want %s, got %s", id, k, v, got[k])
				}
			}
		}
	}
	for _, c := range contains {
		found := false
		for _, l := range o.lines {
			if l == c {
				found = true
			}
		}
		if !found {
			t.Errorf("%s: output lacks line %q (got %s)", id, c, strings.Join(o.lines, " | "))
		}
	}
}

func TestSharedCases(t *testing.T) {
	path := os.Getenv("CASES")
	if path == "" {
		path = "../../docs/release-1-cases.json"
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("cannot read cases: %v", err)
	}
	var cases []tcase
	if err := json.Unmarshal(data, &cases); err != nil {
		t.Fatal(err)
	}
	if path == "../../docs/release-1-cases.json" && len(cases) != 175 {
		t.Fatalf("expected 175 shared cases, found %d", len(cases))
	}
	for _, c := range cases {
		s := newSession(c.Tool)
		for _, line := range c.Setup {
			s.run(line)
		}
		if len(c.Steps) > 0 {
			for i, st := range c.Steps {
				check(t, c.ID+"#"+string(rune('1'+i)), s.run(st.Input), st.Expected, nil, st.Error)
			}
			continue
		}
		check(t, c.ID, s.run(c.Input), c.Expected, c.ExpectedContains, c.Error)
	}
}