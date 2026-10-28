#if os(Windows)
import Foundation
import WinSDK

// Windows console layer. Keys come from the console input handle with
// ENABLE_VIRTUAL_TERMINAL_INPUT on, so arrows arrive as ESC [ A etc. and the same
// pure parseKeys() (test X3) turns them into keys.
// NOTE: on current toolchains the WinSDK functions return a plain Bool.

private let kProcessedInput: DWORD = 0x0001
private let kLineInput: DWORD = 0x0002
private let kEchoInput: DWORD = 0x0004
private let kVirtualTerminalInput: DWORD = 0x0200
private let kVirtualTerminalProcessing: DWORD = 0x0004   // output flag
private let kUtf8: UINT = 65001

// STD_INPUT_HANDLE = -10, STD_OUTPUT_HANDLE = -11
private func stdHandle(_ n: Int32) -> HANDLE? {
    let h = GetStdHandle(DWORD(bitPattern: n))
    if h == nil || h == INVALID_HANDLE_VALUE { return nil }
    return h
}
private func inHandle() -> HANDLE? { stdHandle(-10) }
private func outHandle() -> HANDLE? { stdHandle(-11) }

private func isConsole(_ h: HANDLE?) -> Bool {
    guard let h = h else { return false }
    var mode: DWORD = 0
    return GetConsoleMode(h, &mode)                // fails for pipes, files and mintty
}

// A real console means "a real terminal" here (instead of isatty).
func stdinIsTerminal() -> Bool { isConsole(inHandle()) }
func stdoutIsTerminal() -> Bool { isConsole(outHandle()) }

// MARK: Startup / shutdown: UTF-8 and ANSI escapes on while running, restored on exit.

private var started = false
private var savedOutMode: DWORD = 0
private var savedOutCP: UINT = 0
private var savedInCP: UINT = 0

func platformStartup() {
    guard stdoutIsTerminal(), !started, let out = outHandle() else { return }
    started = true
    savedOutCP = GetConsoleOutputCP()
    savedInCP = GetConsoleCP()
    SetConsoleOutputCP(kUtf8)
    SetConsoleCP(kUtf8)
    if GetConsoleMode(out, &savedOutMode) {
        _ = SetConsoleMode(out, savedOutMode | kVirtualTerminalProcessing)
    }
}

func platformShutdown() {
    guard started else { return }
    started = false
    if let out = outHandle() { _ = SetConsoleMode(out, savedOutMode) }
    SetConsoleOutputCP(savedOutCP)
    SetConsoleCP(savedInCP)
}

// MARK: Keys

final class WindowsKeys: KeySource {
    private var queue: [Key] = []
    private var cookedMode: DWORD = 0
    private var raw = false

    func enter() {
        guard let h = inHandle(), GetConsoleMode(h, &cookedMode) else { return }
        // No line buffering, no echo, Ctrl-C delivered as a key (0x03), VT escape sequences on.
        let mode = (cookedMode & ~(kProcessedInput | kLineInput | kEchoInput)) | kVirtualTerminalInput
        raw = SetConsoleMode(h, mode)
    }

    func leave() {                                   // always runs: the console is never left raw
        if raw, let h = inHandle() { _ = SetConsoleMode(h, cookedMode) }
        raw = false
    }

    func readKey() -> Key {
        if queue.isEmpty {
            guard let h = inHandle() else { return .ctrlD }
            var buf = [UInt8](repeating: 0, count: 64)
            var n: DWORD = 0
            // Blocks until at least one byte; an arrow key arrives as one chunk,
            // a lone Esc as a single byte.
            let ok = ReadFile(h, &buf, DWORD(buf.count), &n, nil)
            if !ok || n == 0 { return .ctrlD }
            queue = parseKeys(Array(buf[0..<Int(n)]))
        }
        return queue.isEmpty ? .other : queue.removeFirst()
    }
}

// MARK: Screen

final class TerminalScreen: Screen {
    let color: Bool
    init(color: Bool) { self.color = color }

    func write(_ s: String) { FileHandle.standardOutput.write(Data(s.utf8)) }

    func size() -> (cols: Int, rows: Int) {
        var info = CONSOLE_SCREEN_BUFFER_INFO()
        if let h = outHandle(), GetConsoleScreenBufferInfo(h, &info) {
            // The visible window, not the (much taller) scroll-back buffer.
            let cols = Int(info.srWindow.Right) - Int(info.srWindow.Left) + 1
            let rows = Int(info.srWindow.Bottom) - Int(info.srWindow.Top) + 1
            if cols > 0 && rows > 0 { return (cols, rows) }
        }
        return (80, 24)
    }
}

// MARK: The real Io

final class ConsoleIo: Io {
    let style: Style
    let hasSelector: Bool
    private let keys = WindowsKeys()
    private let screen: TerminalScreen

    init(selector: Bool, color: Bool) {
        hasSelector = selector
        style = Style(enabled: color)
        screen = TerminalScreen(color: color)
    }

    func write(_ text: String) { FileHandle.standardOutput.write(Data(text.utf8)) }
    func writeError(_ text: String) { FileHandle.standardError.write(Data(text.utf8)) }

    func readLine(prompt: String) -> String? {
        write(prompt)
        let l = Swift.readLine(strippingNewline: true)
        if l == nil { write("\n") }                  // end of input: finish the prompt line
        return l
    }

    func readLinePrefill(prompt: String, prefill: String) -> String? {
        write(prompt + prefill)
        guard let rest = Swift.readLine(strippingNewline: true) else { write("\n"); return nil }
        return prefill + rest
    }

    func select(_ options: SelectorOptions) -> SelectorOutcome {
        runSelector(options, keys: keys, screen: screen)
    }
}
#endif