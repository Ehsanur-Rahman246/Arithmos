#if !os(Windows)
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// POSIX terminal layer (Linux, macOS). The only POSIX file that touches termios.
// On Windows this whole file is excluded; TerminalWindows.swift provides the same
// names (ConsoleIo, TerminalScreen, stdinIsTerminal, ...).

// MARK: Restoring the terminal
// The terminal is raw only while a selector is on screen. It is restored by
// TerminalKeys.leave() and, for SIGTERM / SIGHUP, by a handler installed only
// while a selector is on screen.

private var gSaved = termios()
private var gRaw = false

private func restoreTerminal() {
    if gRaw {
        var t = gSaved
        tcsetattr(STDIN_FILENO, TCSANOW, &t)
        gRaw = false
    }
}

private func onTerminate(_ sig: Int32) {
    restoreTerminal()
    let show = Array("\u{1B}[?25h".utf8)
    _ = write(STDOUT_FILENO, show, show.count)       // cursor visible again
    _exit(128 + sig)
}

// MARK: Byte input shared by line reading and key reading
// One buffer for both, so type-ahead is never lost between a selector and a prompt.

final class ByteInput {
    private var buf: [UInt8] = []
    private var pos = 0
    private var eof = false

    private func fill() -> Bool {
        if eof { return false }
        var tmp = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(STDIN_FILENO, &tmp, tmp.count)
            if n > 0 { buf = Array(tmp[0..<n]); pos = 0; return true }
            if n < 0 && errno == EINTR { continue }
            eof = true
            return false
        }
    }

    func next() -> UInt8? {
        if pos >= buf.count { if !fill() { return nil } }
        let b = buf[pos]
        pos += 1
        return b
    }

    /// True if a byte can be read within `ms` milliseconds (tells a lone Esc from an arrow key).
    func hasPending(ms: Int) -> Bool {
        if pos < buf.count { return true }
        if eof { return false }
        var p = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        return poll(&p, 1, Int32(ms)) > 0
    }

    /// A whole line without the newline; nil at end of input.
    func readLine() -> String? {
        var bytes: [UInt8] = []
        var gotAny = false
        while let b = next() {
            gotAny = true
            if b == 0x0A { break }
            bytes.append(b)
        }
        if !gotAny { return nil }
        if bytes.last == 0x0D { bytes.removeLast() }
        return String(decoding: bytes, as: UTF8.self)
    }
}

// MARK: Keys

final class TerminalKeys: KeySource {
    private let input: ByteInput
    private var original = termios()
    init(input: ByteInput) { self.input = input }

    func enter() {
        guard tcgetattr(STDIN_FILENO, &original) == 0 else { return }
        gSaved = original
        var raw = original
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO | ISIG)     // Ctrl-C arrives as a key
        withUnsafeMutableBytes(of: &raw.c_cc) { p in
            p[Int(VMIN)] = 1                                // block for one byte
            p[Int(VTIME)] = 0
        }
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)
        gRaw = true
        signal(SIGTERM, onTerminate)
        signal(SIGHUP, onTerminate)
    }

    func leave() {
        restoreTerminal()
        signal(SIGTERM, SIG_DFL)
        signal(SIGHUP, SIG_DFL)
    }

    func readKey() -> Key {
        guard let b0 = input.next() else { return .ctrlD }  // end of input
        var chunk = [b0]
        if b0 == 0x1B {
            // An arrow key arrives as one chunk; a lone Esc has nothing after it.
            if input.hasPending(ms: 40), let b1 = input.next() {
                chunk.append(b1)
                if b1 == 0x5B || b1 == 0x4F {
                    while input.hasPending(ms: 40), let b = input.next() {
                        chunk.append(b)
                        if b >= 0x40 && b <= 0x7E { break }   // final byte
                    }
                }
            }
        } else if b0 >= 0xC0 {                                // rest of a UTF-8 character
            let extra = b0 >= 0xF0 ? 3 : (b0 >= 0xE0 ? 2 : 1)
            for _ in 0..<extra {
                if input.hasPending(ms: 40), let b = input.next() { chunk.append(b) }
            }
        }
        return parseKeys(chunk).first ?? .other
    }
}

// MARK: Screen

final class TerminalScreen: Screen {
    let color: Bool
    init(color: Bool) { self.color = color }

    func write(_ s: String) { fputs(s, stdout); fflush(stdout) }

    func size() -> (cols: Int, rows: Int) {
        var ws = winsize()
        #if canImport(Glibc)
        let rc = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws)
        #else
        let rc = ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws)
        #endif
        if rc == 0, ws.ws_col > 0, ws.ws_row > 0 { return (Int(ws.ws_col), Int(ws.ws_row)) }
        let env = ProcessInfo.processInfo.environment
        return (Int(env["COLUMNS"] ?? "") ?? 80, Int(env["LINES"] ?? "") ?? 24)
    }
}

// MARK: The real Io

final class ConsoleIo: Io {
    let style: Style
    let hasSelector: Bool
    private let input = ByteInput()
    private let keys: TerminalKeys
    private let screen: TerminalScreen

    init(selector: Bool, color: Bool) {
        hasSelector = selector
        style = Style(enabled: color)
        keys = TerminalKeys(input: input)
        screen = TerminalScreen(color: color)
    }

    func write(_ text: String) { fputs(text, stdout); fflush(stdout) }
    func writeError(_ text: String) { fputs(text, stderr); fflush(stderr) }

    func readLine(prompt: String) -> String? {
        write(prompt)
        let l = input.readLine()
        if l == nil { write("\n") }                  // end of input: finish the prompt line
        return l
    }

    func readLinePrefill(prompt: String, prefill: String) -> String? {
        write(prompt + prefill)
        guard let rest = input.readLine() else { write("\n"); return nil }
        return prefill + rest
    }

    func select(_ options: SelectorOptions) -> SelectorOutcome {
        runSelector(options, keys: keys, screen: screen)
    }
}

// MARK: Platform hooks (same names and meaning as in TerminalWindows.swift)

func stdinIsTerminal() -> Bool { isatty(STDIN_FILENO) != 0 }
func stdoutIsTerminal() -> Bool { isatty(STDOUT_FILENO) != 0 }
func platformStartup() {}     // nothing to switch on: POSIX terminals speak ANSI and UTF-8
func platformShutdown() {}
#endif