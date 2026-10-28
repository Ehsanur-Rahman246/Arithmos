// Arrow-key selector in three pure-ish layers (SL1–SL15):
//   1. key handling (handleKey)      2. drawing (renderSelector)
//   3. draw/read loop (runSelector) over an injectable keyboard and screen.
// pick() (Pick.swift) is the fourth layer.

struct SelectorOptions {
    var title: String
    var labels: [String]
    var allowBack: Bool        // Esc / b
    var allowQuit: Bool        // q
    var typing: Bool           // any other printable key opens a typed line
    var maxWindow: Int = 10    // lists longer than this scroll
}

enum SelectorOutcome: Equatable {
    case chosen(Int), goBack, goQuit, endOfInput, typed(Character)
}

struct SelectorState {
    var index = 0
    var top = 0
}

protocol KeySource: AnyObject {
    func enter()               // raw mode on
    func leave()               // raw mode off (must always run)
    func readKey() -> Key      // blocking; .ctrlD at end of input
}

protocol Screen: AnyObject {
    var color: Bool { get }
    func write(_ s: String)
    func size() -> (cols: Int, rows: Int)
}

// MARK: Layer 1 — key handling (pure)

/// Rows shown at once: at most `max`, never more than the list, and the whole block
/// (title + rows + hint) must fit the terminal height (X2).
func windowSize(count: Int, rows: Int, max cap: Int = 10) -> Int {
    max(1, min(cap, count, rows - 3))
}

func clampTop(_ s: inout SelectorState, count: Int, window: Int) {
    if s.index < s.top { s.top = s.index }
    if s.index >= s.top + window { s.top = s.index - window + 1 }
    s.top = max(0, min(s.top, count - window))
}

private func isPrintable(_ c: Character) -> Bool {
    !c.isWhitespace && c.unicodeScalars.allSatisfy { $0.value >= 0x20 && $0.value != 0x7F }
}

/// Returns an outcome when the selector should end, nil to keep going.
func handleKey(_ key: Key, _ s: inout SelectorState, _ o: SelectorOptions,
               window: Int) -> SelectorOutcome? {
    let n = o.labels.count
    switch key {
    case .up:       s.index = (s.index - 1 + n) % n           // wraps
    case .down:     s.index = (s.index + 1) % n
    case .home:     s.index = 0
    case .end:      s.index = n - 1
    case .pageUp:   s.index = max(0, s.index - window)
    case .pageDown: s.index = min(n - 1, s.index + window)
    case .enter:    return .chosen(s.index)
    case .esc:      if o.allowBack { return .goBack }
    case .ctrlC, .ctrlD: return .endOfInput
    case .char(let c):
        let lower = String(c).lowercased()
        if lower == "b", o.allowBack { return .goBack }        // act at once, no prompt line
        if lower == "q", o.allowQuit { return .goQuit }
        if o.typing, isPrintable(c) { return .typed(c) }       // space/control keys never start a line
    default: break                                             // other control keys: ignored
    }
    clampTop(&s, count: n, window: window)
    return nil
}

// MARK: Layer 2 — drawing (pure)

/// One logical line = one screen line: cut at width and end with "…" (X2).
func fit(_ s: String, _ width: Int) -> String {
    let w = max(1, width)
    if s.count <= w { return s }
    return String(s.prefix(w - 1)) + "…"
}

/// The hint lists only the keys on offer (SL11, SL12).
func hintText(_ o: SelectorOptions) -> String {
    var parts = ["↑↓ move", "Enter select"]
    if o.allowBack { parts.append("Esc/b back") }
    if o.allowQuit { parts.append("q quit") }
    if o.typing { parts.append("or type") }
    return parts.joined(separator: " · ")
}

func renderSelector(_ o: SelectorOptions, _ s: SelectorState, window: Int,
                    cols: Int, color: Bool) -> [String] {
    let width = max(1, cols - 1)
    let st = Style(enabled: color)
    var lines = [st.bold(fit(o.title, width))]
    let end = min(o.labels.count, s.top + window)
    for i in s.top..<end {
        let selected = (i == s.index)
        let text = fit((selected ? "❯ " : "  ") + o.labels[i], width)   // pointer even without colour
        if selected && color {                                          // full reverse-video bar
            let pad = String(repeating: " ", count: max(0, width - text.count))
            lines.append("\u{1B}[7m" + text + pad + "\u{1B}[0m")
        } else {
            lines.append(text)
        }
    }
    lines.append(st.dim(fit(hintText(o), width)))
    return lines
}

func eraseSequence(_ lines: Int) -> String { "\u{1B}[\(lines)A\r\u{1B}[J" }

// MARK: Layer 3 — the loop

func runSelector(_ o: SelectorOptions, keys: KeySource, screen: Screen) -> SelectorOutcome {
    var state = SelectorState()
    var drawn = 0
    var outcome: SelectorOutcome = .endOfInput
    keys.enter()
    screen.write("\u{1B}[?25l")                                   // hide cursor
    while true {
        let (cols, rows) = screen.size()                          // measured on every redraw
        let window = windowSize(count: o.labels.count, rows: rows, max: o.maxWindow)
        clampTop(&state, count: o.labels.count, window: window)
        if drawn > 0 { screen.write(eraseSequence(drawn)) }
        let lines = renderSelector(o, state, window: window, cols: cols, color: screen.color)
        screen.write(lines.joined(separator: "\n") + "\n")
        drawn = lines.count
        let key = keys.readKey()
        if let out = handleKey(key, &state, o, window: window) { outcome = out; break }
    }
    if drawn > 0 { screen.write(eraseSequence(drawn)) }
    if case .chosen(let i) = outcome {                            // leave "✔ title: label" behind
        let width = max(1, screen.size().cols - 1)
        screen.write(Style(enabled: screen.color).green(fit("✔ \(o.title): \(o.labels[i])", width)) + "\n")
    }
    screen.write("\u{1B}[?25h")                                   // show cursor again
    keys.leave()
    return outcome
}