import Foundation

// pick(): one question, many answers. Arrow-key selector on a real terminal,
// numbered list everywhere else (spec §2.1). Both are required.

struct PickOption {
    let label: String
    let aliases: [String]       // extra typed names (symbols, short names)
}

struct PickSpec {
    var title: String
    var options: [PickOption]
    var allowBack: Bool
    var allowQuit: Bool = true
    var exitRow: Bool = false                 // main menu: "0) Exit"
    /// Handles a typed one-line command. Returns true if the line was a command
    /// (it has printed its own result or error); false -> "Pick one from the list".
    var command: ((String) -> Bool)? = nil
}

enum PickResult: Equatable { case chosen(Int), back, quit, eof }

func plainList(_ spec: PickSpec, _ io: Io) -> String {
    var s = io.style.bold(spec.title) + "\n"
    for (i, o) in spec.options.enumerated() { s += "  \(i + 1)) \(o.label)\n" }   // R28 format
    if spec.exitRow { s += "  0) Exit\n" }
    return s
}

private func helpText(_ spec: PickSpec) -> String {
    var t = "Type a number or a name"
    if spec.command != nil { t += ", or a one-line command such as: convert 100 cm in" }
    t += ". Words: help (or ?)"
    if spec.allowBack { t += ", back" }
    t += ", quit."
    return t + "\n"
}

/// Interprets a typed line. Returns a result to leave pick(), nil to show the list again.
func handleTyped(_ raw: String, _ spec: PickSpec, _ io: Io) -> PickResult? {
    let line = trim(raw)
    if line.isEmpty { return nil }
    let lower = line.lowercased()
    if lower == "quit" { return .quit }
    if lower == "back", spec.allowBack { return .back }
    if lower == "help" || lower == "?" { io.write(helpText(spec)); return nil }
    if spec.exitRow, lower == "0" { return .quit }
    if let n = Int(lower), n >= 1, n <= spec.options.count { return .chosen(n - 1) }
    for (i, o) in spec.options.enumerated() {
        if o.label.lowercased() == lower || o.aliases.contains(where: { $0.lowercased() == lower }) {
            return .chosen(i)
        }
    }
    if let cmd = spec.command, cmd(line) { return nil }
    io.write(io.style.red(ArithmosError(.unknownCommand, "Pick one from the list").line) + "\n")
    return nil
}

func pick(_ io: Io, _ spec: PickSpec) -> PickResult {
    while true {
        let line: String
        if io.hasSelector {
            var labels = spec.options.map { $0.label }
            if spec.exitRow { labels.append("Exit") }
            let opts = SelectorOptions(title: spec.title, labels: labels,
                                       allowBack: spec.allowBack, allowQuit: spec.allowQuit,
                                       typing: true)
            switch io.select(opts) {
            case .chosen(let i): return i >= spec.options.count ? .quit : .chosen(i)
            case .goBack: return .back
            case .goQuit: return .quit
            case .endOfInput: return .eof
            case .typed(let c):        // the key opens a typed line; the rest is read normally
                guard let l = io.readLinePrefill(prompt: "> ", prefill: String(c)) else { return .eof }
                line = l
            }
        } else {
            io.write(plainList(spec, io))
            guard let l = io.readLine(prompt: "> ") else { return .eof }
            line = l
        }
        if let r = handleTyped(line, spec, io) { return r }
    }
}