import Foundation

/// The one I/O seam: engines never touch stdin/stdout; the CLI talks through this.
/// Tests supply a fake; the real one is `ConsoleIo`.
protocol Io: AnyObject {
    var style: Style { get }
    var hasSelector: Bool { get }                 // true only on a real terminal
    func write(_ text: String)                    // stdout
    func writeError(_ text: String)               // stderr (one-shot errors)
    func readLine(prompt: String) -> String?      // nil at end of input
    func readLinePrefill(prompt: String, prefill: String) -> String?
    func select(_ options: SelectorOptions) -> SelectorOutcome   // only if hasSelector
}

func splitWords(_ s: String) -> [String] {
    s.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
}

func trim(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }