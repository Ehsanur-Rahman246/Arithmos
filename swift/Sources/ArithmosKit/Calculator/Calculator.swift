import Foundation

// MARK: - Tokenizer (spec §3.2)

private enum Tok: Equatable {
    case num(Double)
    case plus, minus, star, slash, caret, lparen, rparen, percent
    case word(String)                 // lower-cased keyword: sqrt, abs, ans, of
}

private func isDigit(_ c: Character) -> Bool {
    guard let a = c.asciiValue else { return false }
    return a >= 48 && a <= 57
}

private func isAsciiLetter(_ c: Character) -> Bool {
    guard let a = c.asciiValue else { return false }
    return (a >= 65 && a <= 90) || (a >= 97 && a <= 122)
}

private func tokenize(_ input: String) throws -> [Tok] {
    let chars = Array(input)
    var out: [Tok] = []
    var i = 0
    while i < chars.count {
        let c = chars[i]
        if c.isWhitespace { i += 1; continue }

        // Numbers: 12, 12.5, .5, 5.   (no exponent form in Release 1: 1e5 is an error)
        if isDigit(c) || (c == "." && i + 1 < chars.count && isDigit(chars[i + 1])) {
            var j = i
            while j < chars.count && isDigit(chars[j]) { j += 1 }
            if j < chars.count && chars[j] == "." {
                j += 1
                while j < chars.count && isDigit(chars[j]) { j += 1 }
            }
            var text = String(chars[i..<j])
            if text.hasPrefix(".") { text = "0" + text }
            if text.hasSuffix(".") { text += "0" }
            guard let v = Double(text) else {
                throw ArithmosError(.invalidExpression, "Unexpected symbol")
            }
            out.append(.num(v))
            i = j
            continue
        }

        // Words: only sqrt, abs, ans, of (case-insensitive)
        if isAsciiLetter(c) {
            var j = i
            while j < chars.count && isAsciiLetter(chars[j]) { j += 1 }
            let word = String(chars[i..<j])
            let lower = word.lowercased()
            guard ["sqrt", "abs", "ans", "of"].contains(lower) else {
                throw ArithmosError(.invalidExpression, "Unknown word '\(word)'")
            }
            out.append(.word(lower))
            i = j
            continue
        }

        switch c {
        case "+": out.append(.plus)
        case "-": out.append(.minus)
        case "*": out.append(.star)
        case "/": out.append(.slash)
        case "^": out.append(.caret)
        case "(": out.append(.lparen)
        case ")": out.append(.rparen)
        case "%": out.append(.percent)
        default: throw ArithmosError(.invalidExpression, "Unexpected character '\(c)'")
        }
        i += 1
    }
    return out
}

// MARK: - AST and parser (spec §3.3)

private indirect enum Node {
    case num(Double)
    case ans
    case neg(Node), pos(Node)
    case percent(Node)                // postfix %, its own node (spec §3.4)
    case group(Node)                  // parentheses: stops "relative percent" (200 + (10%) = 200.1)
    case bin(Character, Node, Node)   // + - * /   ("of" is parsed as *)
    case power(Node, Node)
    case call(String, Node)           // sqrt, abs
}

/// Precedence, high to low: parens/calls, postfix %, ^ (right-assoc),
/// unary +/-, * / of, + -.
private final class Parser {
    let toks: [Tok]
    var pos = 0
    init(_ toks: [Tok]) { self.toks = toks }

    func parse() throws -> Node {
        let n = try expr()
        if pos < toks.count { throw ArithmosError(.invalidExpression, "Unexpected symbol") }
        return n
    }

    func peek() -> Tok? { pos < toks.count ? toks[pos] : nil }

    func expr() throws -> Node {
        var left = try term()
        while let t = peek(), t == .plus || t == .minus {
            pos += 1
            let right = try term()
            left = .bin(t == .plus ? "+" : "-", left, right)
        }
        return left
    }

    func term() throws -> Node {
        var left = try unary()
        while let t = peek(), t == .star || t == .slash || t == .word("of") {
            pos += 1
            let right = try unary()
            left = .bin(t == .slash ? "/" : "*", left, right)
        }
        return left
    }

    func unary() throws -> Node {
        if let t = peek() {
            if t == .minus { pos += 1; return .neg(try unary()) }
            if t == .plus { pos += 1; return .pos(try unary()) }
        }
        return try power()
    }

    // ^ binds tighter than unary minus (-2^2 = -4); the exponent may itself be
    // unary or another power (2^-1, 2^3^2 = 2^(3^2)).
    func power() throws -> Node {
        let base = try postfix()
        if let t = peek(), t == .caret {
            pos += 1
            let exponent = try unary()
            return .power(base, exponent)
        }
        return base
    }

    func postfix() throws -> Node {
        var n = try primary()
        while let t = peek(), t == .percent { pos += 1; n = .percent(n) }
        return n
    }

    func primary() throws -> Node {
        guard let t = peek() else {
            throw ArithmosError(.invalidExpression, "The expression ends too early")
        }
        pos += 1
        switch t {
        case .num(let v):
            return .num(v)
        case .lparen:
            let inner = try expr()
            try closeParen()
            return .group(inner)
        case .word(let w):
            switch w {
            case "ans":
                return .ans
            case "sqrt", "abs":
                guard let next = peek(), next == .lparen else {
                    throw ArithmosError(.invalidExpression, "\(w) needs parentheses, like \(w)(4)")
                }
                pos += 1
                let inner = try expr()
                try closeParen()
                return .call(w, inner)
            default:
                throw ArithmosError(.invalidExpression, "Unexpected '\(w)'")
            }
        default:
            throw ArithmosError(.invalidExpression, "Unexpected symbol")
        }
    }

    func closeParen() throws {
        guard let t = peek(), t == .rparen else {
            throw ArithmosError(.invalidExpression, "Missing closing parenthesis")
        }
        pos += 1
    }
}

// MARK: - Evaluator (spec §3.4, §3.5)

/// NaN and infinity never leave the evaluator: they become DOMAIN_ERROR / OVERFLOW.
private func checked(_ v: Double) throws -> Double {
    if v.isNaN { throw ArithmosError(.domainError, "The result is not a number") }
    if v.isInfinite { throw ArithmosError(.overflow, "The result is too large") }
    return v
}

private func eval(_ n: Node, _ ans: Double) throws -> Double {
    switch n {
    case .num(let v): return try checked(v)
    case .ans: return ans
    case .neg(let x): let v = try eval(x, ans); return -v
    case .pos(let x): return try eval(x, ans)
    case .group(let x): return try eval(x, ans)
    case .percent(let x): let v = try eval(x, ans); return v / 100

    case .bin(let op, let l, let r):
        let a = try eval(l, ans)
        let b: Double
        // A % that is the DIRECT right operand of + or - is relative to the left side.
        if (op == "+" || op == "-"), case .percent(let inner) = r {
            let p = try eval(inner, ans)
            b = a * (p / 100)
        } else {
            b = try eval(r, ans)
        }
        switch op {
        case "+": return try checked(a + b)
        case "-": return try checked(a - b)
        case "*": return try checked(a * b)
        default:
            if b == 0 { throw ArithmosError(.divByZero, "Cannot divide by zero") }
            return try checked(a / b)
        }

    case .power(let l, let r):
        let a = try eval(l, ans)
        let e = try eval(r, ans)
        if a == 0 && e == 0 { throw ArithmosError(.undefined, "0^0 is undefined") }
        if a == 0 && e < 0 {
            throw ArithmosError(.divByZero, "Zero cannot be raised to a negative power")
        }
        if a < 0 && e != e.rounded() {
            throw ArithmosError(.domainError, "A negative number cannot have a fractional power")
        }
        return try checked(pow(a, e))          // 10^-400 underflows to 0 (no error)

    case .call(let name, let x):
        let v = try eval(x, ans)
        if name == "sqrt" {
            if v < 0 {
                throw ArithmosError(.domainError, "Cannot take the square root of a negative number")
            }
            return v.squareRoot()
        }
        return v.magnitude
    }
}

// MARK: - Session

final class StandardCalculator {
    /// Last successful result; 0 before the first calculation. A failed line leaves it alone.
    private(set) var ans: Double = 0

    /// Evaluates one line and returns the formatted result.
    func calculate(_ line: String) throws -> String {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { throw ArithmosError(.invalidExpression, "Nothing to calculate") }
        if text.count > 20_000 {
            throw ArithmosError(.invalidExpression, "The expression is too long")
        }
        let ast = try Parser(try tokenize(text)).parse()
        let value = try eval(ast, ans)
        let shown = try formatNumber(value)
        ans = value                                   // only after full success
        return shown
    }
}