import Foundation

/// Spec §2.3: 12 significant digits, half away from zero, trailing zeros trimmed,
/// plain notation for 1e-6 <= |x| < 1e15, otherwise <mantissa>e<sign><exponent>.
///
/// `%.34e` prints the EXACT binary value of the double (glibc / Apple libc), so the
/// digit string can be rounded by hand. printf's own rounding is never used for the
/// 12-digit step, because on exact ties it would round half to even.
func formatNumber(_ x: Double) throws -> String {
    if x.isNaN { throw ArithmosError(.invalidExpression, "Result is not a number") }
    if x.isInfinite { throw ArithmosError(.overflow, "Result is too large to represent") }
    if x == 0 { return "0" }                         // also turns -0 into 0

    let negative = x < 0
    let text = String(format: "%.34e", x.magnitude)  // e.g. "1.2345...e+05"
    guard let eIndex = text.firstIndex(of: "e"),
          var exp = Int(text[text.index(after: eIndex)...]) else {
        throw ArithmosError(.internalError, "Cannot format number")
    }
    let digits = text[..<eIndex].compactMap { $0.wholeNumberValue }   // 35 digits, no "."

    // Round the digit string to 12 significant digits, half away from zero.
    let keep = 12
    var head = Array(digits[0..<keep])
    if digits[keep] >= 5 {                            // exact expansion: >=5 means >= half
        var i = keep - 1
        while i >= 0 {
            if head[i] == 9 { head[i] = 0; i -= 1 } else { head[i] += 1; break }
        }
        if i < 0 {                                    // carried out of the top: 999… -> 1000…
            head = [1] + [Int](repeating: 0, count: keep - 1)
            exp += 1
        }
    }
    while head.count > 1 && head.last == 0 { head.removeLast() }   // trim zeros
    let body = head.map { String($0) }.joined()

    var out: String
    if exp >= -6 && exp < 15 {                        // plain notation
        if exp >= 0 {
            let intLen = exp + 1
            if body.count <= intLen {
                out = body + String(repeating: "0", count: intLen - body.count)
            } else {
                out = String(body.prefix(intLen)) + "." + String(body.dropFirst(intLen))
            }
        } else {
            out = "0." + String(repeating: "0", count: -exp - 1) + body
        }
    } else {                                          // scientific notation
        var mantissa = String(body.prefix(1))
        if body.count > 1 { mantissa += "." + String(body.dropFirst()) }
        out = mantissa + "e" + (exp < 0 ? "-" : "+") + String(abs(exp))
    }
    return negative ? "-" + out : out
}