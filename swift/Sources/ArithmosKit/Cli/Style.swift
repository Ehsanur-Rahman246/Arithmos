// Colour helper. `enabled` is false for pipes, tests and NO_COLOR.
struct Style {
    let enabled: Bool
    private func sgr(_ code: String, _ s: String) -> String {
        enabled ? "\u{1B}[\(code)m\(s)\u{1B}[0m" : s
    }
    func bold(_ s: String) -> String { sgr("1", s) }
    func dim(_ s: String) -> String { sgr("2", s) }
    func red(_ s: String) -> String { sgr("31", s) }
    func green(_ s: String) -> String { sgr("32", s) }
}