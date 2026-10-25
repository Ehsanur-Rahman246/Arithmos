package cli

import (
	"fmt"
	"io"
	"os"
	"strings"

	"arithmos/internal/calculator"
	"arithmos/internal/converter"
	"arithmos/internal/programmer"
)

const usage = `Usage:
  arithmos                          interactive menu
  arithmos std "<expression>"       one calculation        (also: standard)
  arithmos prog <command>           one programmer command (also: programmer)
  arithmos convert <value> <from> <to|all>
  arithmos list [category]
Exit status: 0 success, 1 the line produced an Error [CODE], 2 bad usage.
`

// useSelector: stdin and stdout are terminals, TERM is not dumb and
// ARITHMOS_PLAIN is not 1. Otherwise the numbered lists are used.
func useSelector() bool {
	return os.Getenv("ARITHMOS_PLAIN") != "1" && os.Getenv("TERM") != "dumb" && platformIsTerminal()
}

// Main is the entry point: argv -> one-shot mode or the interactive menu.
func Main(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) > 0 {
		return RunOneShot(args, stdout, stderr)
	}
	if useSelector() {
		defer platformSetup()() // UTF-8 + ANSI on Windows; restored on exit
		RunInteractive(NewTerminalIO(stdin, stdout))
	} else {
		RunInteractive(NewPlainIO(stdin, stdout))
	}
	return 0
}

// RunOneShot runs one command. Results go to stdout; Error [CODE] lines and
// the usage after bad input go to stderr (R31).
func RunOneShot(args []string, stdout, stderr io.Writer) int {
	bad := func() int { fmt.Fprint(stderr, usage); return 2 }
	cmd, rest := strings.ToLower(args[0]), args[1:]
	var run func() ([]string, error)
	switch cmd {
	case "-h", "--help", "help":
		fmt.Fprint(stdout, usage)
		return 0
	case "std", "standard":
		if len(rest) == 0 {
			return bad()
		}
		c := calculator.New()
		run = func() ([]string, error) {
			s, err := c.Run(strings.Join(rest, " "))
			return []string{s}, err
		}
	case "prog", "programmer":
		if len(rest) == 0 {
			return bad()
		}
		p := programmer.New()
		run = func() ([]string, error) {
			r, err := p.Execute(strings.Join(rest, " "))
			if err != nil {
				return nil, err
			}
			return progLines(r), nil
		}
	case "convert":
		if len(rest) == 0 {
			return bad()
		}
		run = func() ([]string, error) { return converter.Execute("convert " + strings.Join(rest, " ")) }
	case "list":
		run = func() ([]string, error) { return converter.Execute(strings.TrimSpace("list " + strings.Join(rest, " "))) }
	default:
		return bad()
	}
	lines, err := safeRun(run)
	if err != nil {
		fmt.Fprintln(stderr, errLine(err))
		return 1
	}
	fmt.Fprintln(stdout, strings.Join(lines, "\n"))
	return 0
}