// Package cli is the only layer that does I/O: menus, prompt loops, the
// arrow-key selector and the tool bindings.
package cli

import "unicode/utf8"

// KeyKind is a decoded key press.
type KeyKind int

const (
	KNone KeyKind = iota
	KUp
	KDown
	KHome
	KEnd
	KPgUp
	KPgDn
	KEnter
	KEsc
	KCtrlC
	KCtrlD
	KChar  // a printable character (Ch)
	KOther // any other control key: ignored by the selector
)

// Key is one key press.
type Key struct {
	Kind KeyKind
	Ch   rune
}

// ParseKey turns one complete chunk of raw terminal bytes into a key (pure; test X3).
func ParseKey(b []byte) Key {
	if len(b) == 0 {
		return Key{}
	}
	switch c := b[0]; {
	case c == 0x03:
		return Key{Kind: KCtrlC}
	case c == 0x04:
		return Key{Kind: KCtrlD}
	case c == '\r' || c == '\n':
		return Key{Kind: KEnter}
	case c == 0x1b:
		return parseEsc(b)
	case c < 0x20 || c == 0x7f:
		return Key{Kind: KOther}
	}
	r, size := utf8.DecodeRune(b)
	if r == utf8.RuneError && size <= 1 {
		return Key{Kind: KOther}
	}
	return Key{Kind: KChar, Ch: r}
}

func parseEsc(b []byte) Key {
	if len(b) == 1 {
		return Key{Kind: KEsc} // a lone Esc
	}
	if len(b) >= 3 && (b[1] == '[' || b[1] == 'O') {
		switch string(b[2:]) {
		case "A":
			return Key{Kind: KUp}
		case "B":
			return Key{Kind: KDown}
		case "H", "1~", "7~":
			return Key{Kind: KHome}
		case "F", "4~", "8~":
			return Key{Kind: KEnd}
		case "5~":
			return Key{Kind: KPgUp}
		case "6~":
			return Key{Kind: KPgDn}
		}
	}
	return Key{Kind: KOther}
}

// SeqComplete reports whether b is a complete key sequence, so the raw reader
// knows when to stop waiting for more bytes.
func SeqComplete(b []byte) bool {
	if len(b) == 0 {
		return false
	}
	if b[0] != 0x1b {
		return utf8.FullRune(b)
	}
	if len(b) < 2 {
		return false // maybe a lone Esc: the reader decides by timeout
	}
	switch b[1] {
	case '[':
		return len(b) >= 3 && b[len(b)-1] >= 0x40 && b[len(b)-1] <= 0x7e
	case 'O':
		return len(b) >= 3
	}
	return true
}