import XCTest
@testable import ArithmosKit

/// Default location of the shared cases: <repo>/docs/release-1-cases.json
/// (derived from this file's path, so it works from any working directory).
/// `CASES=path` overrides it.
func casesPath() -> String {
    if let p = ProcessInfo.processInfo.environment["CASES"] { return p }
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 { url.deleteLastPathComponent() }          // -> swift/
    return url.deletingLastPathComponent().appendingPathComponent("docs/release-1-cases.json").path
}

/// The error code thrown by `body`, or nil if it succeeded ("OTHER" for a non-Arithmos error).
func errorCode(_ body: () throws -> Void) -> String? {
    do { try body(); return nil }
    catch let e as ArithmosError { return e.code.rawValue }
    catch { return "OTHER" }
}

/// Fake terminal I/O: scripted input lines, scripted selector results, captured output.
final class FakeIo: Io {
    var out = "", err = ""
    var lines: [String]
    var selectResults: [SelectorOutcome]
    var hasSelector: Bool
    var selectCalls = 0, readCalls = 0
    let style = Style(enabled: false)

    init(lines: [String] = [], selector: Bool = false, selectResults: [SelectorOutcome] = []) {
        self.lines = lines
        self.hasSelector = selector
        self.selectResults = selectResults
    }
    func write(_ text: String) { out += text }
    func writeError(_ text: String) { err += text }
    func readLine(prompt: String) -> String? {
        readCalls += 1
        out += prompt
        return lines.isEmpty ? nil : lines.removeFirst()
    }
    func readLinePrefill(prompt: String, prefill: String) -> String? {
        readCalls += 1
        return lines.isEmpty ? nil : lines.removeFirst()      // the script supplies the full line
    }
    func select(_ options: SelectorOptions) -> SelectorOutcome {
        selectCalls += 1
        return selectResults.isEmpty ? .endOfInput : selectResults.removeFirst()
    }
}

final class FakeKeys: KeySource {
    var queue: [Key]
    var enters = 0, leaves = 0
    init(_ keys: [Key]) { queue = keys }
    func enter() { enters += 1 }
    func leave() { leaves += 1 }
    func readKey() -> Key { queue.isEmpty ? .ctrlD : queue.removeFirst() }
}

final class FakeScreen: Screen {
    var text = ""
    var cols: Int, rows: Int
    let color: Bool
    init(cols: Int = 80, rows: Int = 24, color: Bool = false) {
        self.cols = cols; self.rows = rows; self.color = color
    }
    func write(_ s: String) { text += s }
    func size() -> (cols: Int, rows: Int) { (cols, rows) }
}

/// Removes ESC [ … <letter> sequences.
func stripAnsi(_ s: String) -> String {
    var out = ""
    var it = s.makeIterator()
    while let c = it.next() {
        if c == "\u{1B}" {
            while let d = it.next(), !d.isLetter {}
            continue
        }
        out.append(c)
    }
    return out
}

private final class StackBox<T>: @unchecked Sendable { var value: T? }

/// Runs `body` on a 256 MB-stack thread (as the real program does) and returns its result.
/// Needed for tests that nest deeply: the test runner's own thread has a small stack.
func onBigStack<T>(_ body: @escaping () -> T) -> T {
    let box = StackBox<T>()
    let done = DispatchSemaphore(value: 0)
    let thread = Thread {
        box.value = body()
        done.signal()
    }
    thread.stackSize = 256 << 20
    thread.start()
    done.wait()
    return box.value!
}