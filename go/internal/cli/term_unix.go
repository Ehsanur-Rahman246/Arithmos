//go:build !windows

package cli

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
)

// stty runs stty against the controlling terminal and returns its output.
func stty(args ...string) (string, error) {
	tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return "", err
	}
	defer tty.Close()
	cmd := exec.Command("stty", args...)
	cmd.Stdin = tty
	out, err := cmd.Output()
	return strings.TrimSpace(string(out)), err
}

func platformIsTerminal() bool {
	for _, f := range []*os.File{os.Stdin, os.Stdout} {
		fi, err := f.Stat()
		if err != nil || fi.Mode()&os.ModeCharDevice == 0 {
			return false
		}
	}
	_, err := stty("-g")
	return err == nil
}

func platformSetup() func() { return func() {} }

func platformSize() (int, int) {
	out, err := stty("size") // "rows cols"
	f := strings.Fields(out)
	if err != nil || len(f) != 2 {
		return 80, 24
	}
	h, e1 := strconv.Atoi(f[0])
	w, e2 := strconv.Atoi(f[1])
	if e1 != nil || e2 != nil || w < 1 || h < 1 {
		return 80, 24
	}
	return w, h
}

// unixKeys puts the tty in raw mode only while a selector is on screen.
// `min 0 time 1` makes read() return after 0.1 s with no byte, which is how a
// lone Esc is told from an arrow key.
type unixKeys struct {
	fd    int
	saved string
	sigc  chan os.Signal
	done  chan struct{}
}

func platformKeys() KeySource { return &unixKeys{} }

func (k *unixKeys) Enter() error {
	saved, err := stty("-g")
	if err != nil {
		return err
	}
	k.saved = saved
	if _, err := stty("-icanon", "-echo", "-isig", "min", "0", "time", "1"); err != nil {
		return err
	}
	fd, err := syscall.Open("/dev/tty", syscall.O_RDONLY, 0)
	if err != nil {
		stty(k.saved)
		return err
	}
	k.fd = fd
	// A kill must not leave the terminal raw.
	k.sigc = make(chan os.Signal, 1)
	k.done = make(chan struct{})
	signal.Notify(k.sigc, syscall.SIGTERM, syscall.SIGHUP)
	go func(sigc chan os.Signal, done chan struct{}, saved string) {
		select {
		case s := <-sigc:
			stty(saved)
			fmt.Fprint(os.Stdout, "\x1b[?25h")
			code := 1
			if sg, ok := s.(syscall.Signal); ok {
				code = 128 + int(sg)
			}
			os.Exit(code)
		case <-done:
		}
	}(k.sigc, k.done, saved)
	return nil
}

func (k *unixKeys) Leave() {
	signal.Stop(k.sigc)
	close(k.done)
	syscall.Close(k.fd)
	stty(k.saved)
}

func (k *unixKeys) ReadKey() (Key, error) {
	var buf []byte
	for {
		var b [1]byte
		n, err := syscall.Read(k.fd, b[:])
		if err != nil && err != syscall.EINTR {
			return Key{}, err
		}
		if n != 1 { // timeout
			if len(buf) == 0 {
				continue // nothing typed yet: keep waiting
			}
			break // partial sequence (a lone Esc): decode what we have
		}
		buf = append(buf, b[0])
		if SeqComplete(buf) {
			break
		}
	}
	return ParseKey(buf), nil
}