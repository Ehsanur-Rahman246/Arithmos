import Foundation

// MARK: - Bases (spec §4.2)

enum Base: String {
    case bin, oct, dec, hex
    var radix: Int {
        switch self { case .bin: return 2; case .oct: return 8; case .dec: return 10; case .hex: return 16 }
    }
    static func parse(_ s: String) -> Base? { Base(rawValue: s.lowercased()) }
}

/// Text of a value in a base. Negative values show the full 64-bit pattern in
/// hex/oct/bin (spec §4.4); dec shows the signed value.
func text(of v: Int64, in base: Base) -> String {
    if base == .dec { return String(v) }
    return String(UInt64(bitPattern: v), radix: base.radix, uppercase: true)
}

/// The four lines shown for a value.
func fields(_ v: Int64) -> [(label: String, value: String)] {
    [("HEX", text(of: v, in: .hex)), ("DEC", text(of: v, in: .dec)),
     ("OCT", text(of: v, in: .oct)), ("BIN", text(of: v, in: .bin))]
}

// MARK: - Literal parsing (spec §4.3)
// Never goes through Double. Order: prefix -> alphanumeric check -> digit check -> range.

private func digitValue(_ a: UInt8) -> Int? {
    switch a {
    case 48...57: return Int(a) - 48            // 0-9
    case 65...90: return Int(a) - 55            // A-Z
    case 97...122: return Int(a) - 87           // a-z
    default: return nil
    }
}

private func prefixBase(_ c: Character) -> Base? {
    switch String(c).lowercased() {
    case "b": return .bin
    case "o": return .oct
    case "d": return .dec
    case "x": return .hex
    default: return nil
    }
}

func parseLiteral(_ raw: String, base inputBase: Base) throws -> Int64 {
    var chars = Array(raw)
    var negative = false
    if chars.first == "-" { negative = true; chars.removeFirst() }
    if chars.isEmpty { throw ArithmosError(.invalidNumber, "'\(raw)' is not a number") }

    // A prefix counts only when something follows it (R30): "0B" in hex mode is 11,
    // "0B1" is binary 1, a bare "0x" in dec mode is INVALID_DIGIT ('X').
    var base = inputBase
    if chars.count >= 3, chars[0] == "0", let b = prefixBase(chars[1]) {
        base = b
        chars.removeFirst(2)
    }

    // 1) everything must be an ASCII letter or digit, else INVALID_NUMBER
    var values: [Int] = []
    for c in chars {
        guard let a = c.asciiValue, let v = digitValue(a) else {
            throw ArithmosError(.invalidNumber, "'\(raw)' is not a number")
        }
        values.append(v)
    }
    // 2) every digit must exist in the base
    for (idx, v) in values.enumerated() where v >= base.radix {
        throw ArithmosError(.invalidDigit,
            "'\(String(chars[idx]).uppercased())' is not a \(base.rawValue) digit")
    }
    // 3) accumulate the magnitude with overflow detection
    var mag: UInt64 = 0
    var overflow = false
    for v in values {
        let (m1, o1) = mag.multipliedReportingOverflow(by: UInt64(base.radix))
        let (m2, o2) = m1.addingReportingOverflow(UInt64(v))
        if o1 || o2 { overflow = true; break }
        mag = m2
    }
    let tooWide = (base == .dec || negative)
        ? "That number does not fit in 64 bits" : "That number needs more than 64 bits"
    if overflow { throw ArithmosError(.outOfRange, tooWide) }

    if negative {
        let limit = UInt64(1) << 63
        if mag > limit { throw ArithmosError(.outOfRange, tooWide) }
        return mag == limit ? Int64.min : -Int64(mag)
    }
    if base == .dec {
        if mag > UInt64(Int64.max) { throw ArithmosError(.outOfRange, tooWide) }
        return Int64(mag)
    }
    return Int64(bitPattern: mag)                 // raw bit pattern, reinterpreted as signed
}

// MARK: - Shifts (spec §4.5)

/// The shift count is always a plain decimal 0-63.
private func parseShiftCount(_ s: String) throws -> Int {
    let bad = ArithmosError(.invalidShift, "A shift count must be a whole number from 0 to 63")
    guard !s.isEmpty, s.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { throw bad }
    let trimmed = s.drop(while: { $0 == "0" })
    if trimmed.count > 2 { throw bad }
    let n = trimmed.isEmpty ? 0 : Int(trimmed)!
    guard n <= 63 else { throw bad }
    return n
}

/// Finds a shift operator, so "1<<3" works like "1 << 3" (R29).
private func splitShift(_ line: String) -> (left: String, op: String, right: String)? {
    for op in [">>>", ">>", "<<"] {
        if let r = line.range(of: op) {
            return (String(line[..<r.lowerBound]), op, String(line[r.upperBound...]))
        }
    }
    return nil
}

// MARK: - Session

enum ProgrammerOutput {
    case value(Int64)         // show all four bases
    case converted(String)    // just the converted number
    case baseSet(Base)        // "base hex"
}

final class ProgrammerCalculator {
    private(set) var inputBase: Base = .dec

    private let notACommand = ArithmosError(.unknownCommand, "Not a command. Try help")

    func run(_ line: String) throws -> ProgrammerOutput {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw ArithmosError(.unknownCommand, "Type a number or a command. Try help")
        }

        // Shifts first: operator characters can appear without spaces.
        if trimmed.contains("<") || trimmed.contains(">"), let s = splitShift(trimmed) {
            let l = splitWords(s.left), r = splitWords(s.right)
            guard l.count == 1, r.count == 1 else { throw notACommand }
            let v = try parseLiteral(l[0], base: inputBase)
            let n = try parseShiftCount(r[0])
            switch s.op {
            case "<<": return .value(v &<< Int64(n))                       // bits past 63 dropped
            case ">>": return .value(v &>> Int64(n))                       // arithmetic
            default:   return .value(Int64(bitPattern: UInt64(bitPattern: v) &>> UInt64(n)))  // logical
            }
        }

        let words = splitWords(trimmed)
        let w0 = words[0].lowercased()

        if w0 == "base" {
            guard words.count == 2 else {
                throw ArithmosError(.invalidBase, "Use: base bin | oct | dec | hex")
            }
            guard let b = Base.parse(words[1]) else { throw badBase(words[1]) }
            inputBase = b
            return .baseSet(b)
        }
        if w0 == "convert" {
            guard words.count == 4 else {
                throw ArithmosError(.unknownCommand, "Use: convert <value> <from> <to>")
            }
            return try convert(words[1], words[2], words[3])
        }
        if w0 == "not" {
            guard words.count == 2 else { throw ArithmosError(.unknownCommand, "Use: NOT <value>") }
            return .value(~(try parseLiteral(words[1], base: inputBase)))
        }
        if words.count == 1 {
            return .value(try parseLiteral(words[0], base: inputBase))
        }
        if words.count == 3 {
            let op = words[1].lowercased()
            // R11: the operator is always the middle word, so hex numbers like DEC still work.
            if op == "and" || op == "or" || op == "xor" {
                let a = try parseLiteral(words[0], base: inputBase)
                let b = try parseLiteral(words[2], base: inputBase)
                switch op {
                case "and": return .value(a & b)
                case "or":  return .value(a | b)
                default:    return .value(a ^ b)
                }
            }
            // "255 dec hex": the word `convert` is optional (R24).
            if Base.parse(words[1]) != nil && Base.parse(words[2]) != nil {
                return try convert(words[0], words[1], words[2])
            }
        }
        throw notACommand
    }

    private func convert(_ value: String, _ from: String, _ to: String) throws -> ProgrammerOutput {
        guard let f = Base.parse(from) else { throw badBase(from) }
        guard let t = Base.parse(to) else { throw badBase(to) }
        let v = try parseLiteral(value, base: f)      // explicit `from`, not the input base
        return .converted(text(of: v, in: t))
    }

    private func badBase(_ s: String) -> ArithmosError {
        ArithmosError(.invalidBase, "'\(s)' is not a base. Use bin, oct, dec or hex")
    }
}