//go:build windows

package cli

import (
	"os"
	"syscall"
	"unsafe"
)

var (
	kernel32            = syscall.NewLazyDLL("kernel32.dll")
	msvcrt              = syscall.NewLazyDLL("msvcrt.dll")
	pGetConsoleMode     = kernel32.NewProc("GetConsoleMode")
	pSetConsoleMode     = kernel32.NewProc("SetConsoleMode")
	pGetConsoleOutputCP = kernel32.NewProc("GetConsoleOutputCP")
	pSetConsoleOutputCP = kernel32.NewProc("SetConsoleOutputCP")
	pGetCSBI            = kernel32.NewProc("GetConsoleScreenBufferInfo")
	pGetwch             = msvcrt.NewProc("_getwch")
)

const (
	enableProcessedInput = 0x0001
	enableVTProcessing   = 0x0004
)

type coord struct{ X, Y int16 }
type smallRect struct{ Left, Top, Right, Bottom int16 }
type csbi struct {
	Size, CursorPosition coord
	Attributes           uint16
	Window               smallRect
	MaxWindowSize        coord
}

func consoleMode(h syscall.Handle) (uint32, bool) {
	var m uint32
	r, _, _ := pGetConsoleMode.Call(uintptr(h), uintptr(unsafe.Pointer(&m)))
	return m, r != 0
}

// A real console has a console mode on both handles; Git Bash (mintty) does not.
func platformIsTerminal() bool {
	_, a := consoleMode(syscall.Handle(os.Stdin.Fd()))
	_, b := consoleMode(syscall.Handle(os.Stdout.Fd()))
	return a && b
}

// platformSetup switches the console to UTF-8 and ANSI escapes while the
// program runs, and returns the function that restores both.
func platformSetup() func() {
	h := syscall.Handle(os.Stdout.Fd())
	mode, ok := consoleMode(h)
	cp, _, _ := pGetConsoleOutputCP.Call()
	pSetConsoleOutputCP.Call(65001)
	if ok {
		pSetConsoleMode.Call(uintptr(h), uintptr(mode|enableVTProcessing))
	}
	return func() {
		if ok {
			pSetConsoleMode.Call(uintptr(h), uintptr(mode))
		}
		pSetConsoleOutputCP.Call(cp)
	}
}

func platformSize() (int, int) {
	var info csbi
	r, _, _ := pGetCSBI.Call(os.Stdout.Fd(), uintptr(unsafe.Pointer(&info)))
	if r == 0 {
		return 80, 24
	}
	return int(info.Window.Right-info.Window.Left) + 1, int(info.Window.Bottom-info.Window.Top) + 1
}

// winKeys reads single keys with _getwch. Ctrl-C is delivered as a key (not a
// signal) only while a selector is on screen.
type winKeys struct {
	in   syscall.Handle
	mode uint32
	ok   bool
}

func platformKeys() KeySource { return &winKeys{} }

func (k *winKeys) Enter() error {
	k.in = syscall.Handle(os.Stdin.Fd())
	k.mode, k.ok = consoleMode(k.in)
	if k.ok {
		pSetConsoleMode.Call(uintptr(k.in), uintptr(k.mode&^enableProcessedInput))
	}
	return nil
}

func (k *winKeys) Leave() {
	if k.ok {
		pSetConsoleMode.Call(uintptr(k.in), uintptr(k.mode))
	}
}

func getwch() int {
	r, _, _ := pGetwch.Call()
	return int(r)
}

func (k *winKeys) ReadKey() (Key, error) {
	c := getwch()
	switch c {
	case 0, 0xE0: // extended key: a second code follows
		switch getwch() {
		case 72:
			return Key{Kind: KUp}, nil
		case 80:
			return Key{Kind: KDown}, nil
		case 71:
			return Key{Kind: KHome}, nil
		case 79:
			return Key{Kind: KEnd}, nil
		case 73:
			return Key{Kind: KPgUp}, nil
		case 81:
			return Key{Kind: KPgDn}, nil
		}
		return Key{Kind: KOther}, nil
	case 3:
		return Key{Kind: KCtrlC}, nil
	case 4:
		return Key{Kind: KCtrlD}, nil
	case 13:
		return Key{Kind: KEnter}, nil
	case 27:
		return Key{Kind: KEsc}, nil
	}
	if c < 0x20 || c == 0x7f {
		return Key{Kind: KOther}, nil
	}
	return Key{Kind: KChar, Ch: rune(c)}, nil
}