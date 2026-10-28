import Foundation

// Menus, prompt loops and the guided converter. The only layer that turns
// values into text and errors into `Error [CODE]: message`.

enum ToolExit { case back, quit }  // end of input counts as quit

private let standardHelp = """
    Standard Calculator
      + - * / ^   ( )   50%   20% of 150   sqrt(x)   abs(x)   ans
      Not supported: 1e5 input, implicit multiplication (2(3)).
      Commands: help (or ?), back, quit
    """

private let programmerHelp = """
    Programmer Calculator (64-bit signed)
      <value>                  show in HEX, DEC, OCT, BIN (prefixes 0b 0o 0d 0x)
      base <bin|oct|dec|hex>   set the input base
      [convert] <v> <from> <to>   e.g. 255 dec hex
      <a> AND|OR|XOR <b>   NOT <a>   <a> << n   <a> >> n   <a> >>> n   (n = 0-63, decimal)
      Commands: help (or ?), back, quit
    """

private let converterHelp = """
    Unit Converter
      <value>                      convert with the units chosen above
      [convert] <value> <from> <to|all>   e.g. 100 cm in
      list   list <category>
      Commands: help (or ?), back, quit
    """

private func printError(_ io: Io, _ error: Error) {
    if let e = error as? ArithmosError {
        io.write(io.style.red(e.line) + "\n")
    } else {
        io.write(io.style.red("Error [INTERNAL]: \(error)") + "\n")  // never crash on bad input
    }
}

/// One prompt loop for all three tools: help/?, back, quit, blank lines ignored,
/// end of input exits cleanly, every error printed as `Error [CODE]: message`.
func promptLoop(
    _ io: Io, prompt: String, intro: String?, help: String,
    handle: (String) throws -> [String]
) -> ToolExit {
    if let intro = intro { io.write(intro + "\n") }
    while true {
        guard let raw = io.readLine(prompt: prompt) else { return .quit }
        let line = trim(raw)
        if line.isEmpty { continue }
        switch line.lowercased() {
        case "quit": return .quit
        case "back": return .back
        case "help", "?":
            io.write(help + "\n")
            continue
        default: break
        }
        do {
            let out = try handle(line)
            if !out.isEmpty { io.write(out.joined(separator: "\n") + "\n") }
        } catch {
            printError(io, error)
        }
    }
}

func runStandard(_ io: Io) -> ToolExit {
    let calc = StandardCalculator()
    return promptLoop(
        io, prompt: "standard> ",
        intro: "Standard Calculator — type an expression (help, back, quit).",
        help: standardHelp
    ) { line in [try calc.calculate(line)] }
}

func runProgrammer(_ io: Io) -> ToolExit {
    let prog = ProgrammerCalculator()
    return promptLoop(
        io, prompt: "programmer> ",
        intro: "Programmer Calculator — 64-bit signed (help, back, quit).",
        help: programmerHelp
    ) { line in programmerLines(try prog.run(line)) }
}

func programmerLines(_ out: ProgrammerOutput) -> [String] {
    switch out {
    case .value(let v): return fields(v).map { "\($0.label): \($0.value)" }
    case .converted(let s): return [s]
    case .baseSet(let b): return ["Input base: \(b.rawValue)"]  // R32
    }
}

// MARK: Guided converter (R22): category -> from -> to -> values

private func unitOptions(_ c: Category) -> [PickOption] {
    c.units.map { PickOption(label: "\($0.symbol) — \($0.name)", aliases: [$0.symbol, $0.name]) }
}

/// A typed one-line command at a converter picker: convert…, list…, or "<v> <from> <to>".
private func converterLineCommand(_ io: Io, _ conv: ArithmosConverter) -> (String) -> Bool {
    return { line in
        let words = splitWords(line)
        guard let w0 = words.first?.lowercased(),
            w0 == "list" || w0 == "convert" || words.count == 3
        else { return false }
        do { io.write(try conv.run(line).joined(separator: "\n") + "\n") } catch {
            printError(io, error)
        }
        return true
    }
}

func runConverter(_ io: Io) -> ToolExit {
    let conv = ArithmosConverter()
    let command = converterLineCommand(io, conv)
    var stage = 0
    var cat = conv.categories[0]
    var from = cat.units[0]
    var to = cat.units[0]

    while true {
        switch stage {
        case 0:  // category
            let spec = PickSpec(
                title: "Unit Converter — choose a category",
                options: conv.categories.map { PickOption(label: $0.name, aliases: []) },
                allowBack: true, command: command)
            switch pick(io, spec) {
            case .chosen(let i):
                cat = conv.categories[i]
                stage = 1
            case .back: return .back  // first screen -> main menu
            case .quit, .eof: return .quit
            }
        case 1:  // from-unit
            let spec = PickSpec(
                title: "\(cat.name.capitalized) — convert from",
                options: unitOptions(cat), allowBack: true, command: command)
            switch pick(io, spec) {
            case .chosen(let i):
                from = cat.units[i]
                stage = 2
            case .back: stage = 0
            case .quit, .eof: return .quit
            }
        case 2:  // to-unit
            let spec = PickSpec(
                title: "\(cat.name.capitalized) — convert from \(from.symbol) to",
                options: unitOptions(cat), allowBack: true, command: command)
            switch pick(io, spec) {
            case .chosen(let i):
                to = cat.units[i]
                stage = 3
            case .back: stage = 1
            case .quit, .eof: return .quit
            }
        default:  // values prompt shows the units
            let c = cat
            let f = from
            let t = to
            let r = promptLoop(
                io, prompt: "converter (\(f.symbol) → \(t.symbol))> ",
                intro: nil, help: converterHelp
            ) { line in
                let words = splitWords(line)
                if words.count == 1, words[0].lowercased() != "list" {  // a bare value
                    let v = try conv.parseValue(words[0])
                    let result = try conv.convertUnits(v, c, f, t)
                    let left = try formatNumber(v)
                    let right = try formatNumber(result)
                    return ["\(left) \(f.symbol) = \(right) \(t.symbol)"]
                }
                return try conv.run(line)  // one-line forms still work
            }
            switch r {
            case .back: stage = 2
            case .quit: return .quit
            }
        }
    }
}

// MARK: Main menu (spec §2.1)

func runInteractive(_ io: Io) -> Int32 {
    let options = [
        PickOption(label: "Standard Calculator", aliases: ["standard", "std"]),
        PickOption(label: "Programmer Calculator", aliases: ["programmer", "prog"]),
        PickOption(label: "Unit Converter", aliases: ["converter", "convert"]),
    ]
    while true {
        let spec = PickSpec(
            title: "Arithmos 1.0 — Core CLI", options: options,
            allowBack: false, exitRow: true)
        let exit: ToolExit
        switch pick(io, spec) {
        case .chosen(0): exit = runStandard(io)
        case .chosen(1): exit = runProgrammer(io)
        case .chosen(2): exit = runConverter(io)
        default: return 0  // quit / end of input
        }
        if exit == .quit { return 0 }
    }
}
