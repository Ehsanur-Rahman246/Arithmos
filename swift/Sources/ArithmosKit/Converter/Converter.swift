import Foundation

final class ArithmosConverter {
    let categories = unitTable
    private var index: [String: (cat: Int, unit: Int)] = [:]

    init() {
        // Symbols are unique across categories, so the category is inferred from them.
        for (ci, c) in categories.enumerated() {
            for (ui, u) in c.units.enumerated() { index[u.symbol] = (ci, ui) }
        }
    }

    private func lookup(_ symbol: String) -> (cat: Int, unit: Int)? { index[symbol.lowercased()] }

    // MARK: Values

    /// A plain decimal: optional sign, digits, optional single dot. No 1e3, no 1,000.
    func parseValue(_ s: String) throws -> Double {
        let bad = ArithmosError(.invalidNumber, "'\(s)' is not a number")
        let bytes = Array(s.utf8)
        var i = 0
        var negative = false
        if i < bytes.count, bytes[i] == 43 || bytes[i] == 45 {
            negative = bytes[i] == 45
            i += 1
        }
        var digits = 0
        var dots = 0
        for b in bytes[i...] {
            if b >= 48 && b <= 57 { digits += 1 } else if b == 46 { dots += 1 } else { throw bad }
        }
        guard digits > 0, dots <= 1 else { throw bad }
        var body = String(decoding: bytes[i...], as: UTF8.self)
        if body.hasPrefix(".") { body = "0" + body }
        if body.hasSuffix(".") { body += "0" }
        guard let v = Double(body) else { throw bad }
        if v.isInfinite { throw ArithmosError(.overflow, "That number is too large") }
        return negative ? -v : v
    }

    /// Absolute-zero limits in each scale (checked on the input, in its own scale).
    private func checkAbsoluteZero(_ v: Double, _ symbol: String) throws {
        let limit: Double = symbol == "c" ? -273.15 : (symbol == "f" ? -459.67 : 0)
        if v < limit { throw ArithmosError(.belowAbsoluteZero, "That is below absolute zero") }
    }

    /// value x from.factor / to.factor, or the temperature formulas through Celsius.
    func convertUnits(_ v: Double, _ c: Category, _ f: Unit, _ t: Unit) throws -> Double {
        if c.isTemperature {
            try checkAbsoluteZero(v, f.symbol)
            let celsius: Double
            switch f.symbol {
            case "f": celsius = (v - 32) * 5 / 9
            case "k": celsius = v - 273.15
            default: celsius = v
            }
            switch t.symbol {
            case "f": return celsius * 9 / 5 + 32
            case "k": return celsius + 273.15
            default: return celsius
            }
        }
        let r = v * f.factor / t.factor
        guard r.isFinite else { throw ArithmosError(.overflow, "Result is too large to represent") }
        return r
    }

    // MARK: Commands

    /// `convert <value> <from> <to|all>`. Returns the lines to print.
    func convert(_ valueText: String, _ fromText: String, _ toText: String) throws -> [String] {
        let value = try parseValue(valueText)
        guard let f = lookup(fromText) else { throw unknown(fromText) }
        let cat = categories[f.cat]
        let from = cat.units[f.unit]

        if toText.lowercased() == "all" {  // every unit of the category, table order
            if cat.isTemperature { try checkAbsoluteZero(value, from.symbol) }
            var lines: [String] = []  // built fully first: no partial output
            for u in cat.units {
                let r = try convertUnits(value, cat, from, u)
                lines.append("\(u.symbol): \(try formatNumber(r))")
            }
            return lines
        }
        guard let t = lookup(toText) else { throw unknown(toText) }
        guard t.cat == f.cat else {
            throw ArithmosError(
                .incompatibleUnits,
                "Cannot convert \(cat.name) to \(categories[t.cat].name)")
        }
        let r = try convertUnits(value, cat, from, cat.units[t.unit])
        return [try formatNumber(r)]
    }

    /// One line: `convert <v> <from> <to>`, `<v> <from> <to>`, `list`, `list <category>`.
    func run(_ line: String) throws -> [String] {
        let words = splitWords(line)
        guard let first = words.first else {
            throw ArithmosError(.unknownCommand, "Type a value, e.g. 100")
        }
        let w0 = first.lowercased()
        if w0 == "list" {
            if words.count == 1 { return [categories.map { $0.name }.joined(separator: ", ")] }
            if words.count == 2 {
                guard let c = categories.first(where: { $0.name == words[1].lowercased() }) else {
                    throw ArithmosError(
                        .unknownCommand, "'\(words[1])' is not a category. Try: list")
                }
                return [c.units.map { $0.symbol }.joined(separator: ", ")]
            }
            throw ArithmosError(.unknownCommand, "Use: list  or  list <category>")
        }
        if w0 == "convert" {
            guard words.count == 4 else {
                throw ArithmosError(.unknownCommand, "Use: convert <value> <from> <to>")
            }
            return try convert(words[1], words[2], words[3])
        }
        if words.count == 3 { return try convert(words[0], words[1], words[2]) }
        throw ArithmosError(.unknownCommand, "Not a command. Try: convert 100 cm in")
    }

    private func unknown(_ s: String) -> ArithmosError {
        ArithmosError(.unknownUnit, "'\(s)' is not a known unit. Try: list")
    }
}
