package arithmos.calculator

import arithmos.shared.*

// ---------- Tokens ----------
private sealed interface Tok
private data class TNum(val v: Double) : Tok
private data class TWord(val w: String, val raw: String) : Tok   // w is lower-case
private data class TSym(val c: Char) : Tok

private val WORDS = setOf("sqrt", "abs", "ans", "of")

/** Turns the line into tokens. Numbers: 12, 12.5, .5, 5.  (no 1e5, spec §3.2). */
private fun tokenize(s: String): List<Tok> {
    val out = ArrayList<Tok>()
    var i = 0
    while (i < s.length) {
        val c = s[i]
        when {
            c.isWhitespace() -> i++
            c in '0'..'9' || c == '.' -> {
                val start = i
                while (i < s.length && s[i] in '0'..'9') i++
                if (i < s.length && s[i] == '.') {
                    i++
                    while (i < s.length && s[i] in '0'..'9') i++
                }
                val text = s.substring(start, i)
                if (text.none { it in '0'..'9' }) fail(Code.INVALID_EXPRESSION, "Unexpected character '.'")
                val v = text.toDouble()
                if (v.isInfinite()) fail(Code.OVERFLOW, "That number is too large")
                out.add(TNum(v))
            }
            c in 'a'..'z' || c in 'A'..'Z' -> {
                val start = i
                while (i < s.length && (s[i] in 'a'..'z' || s[i] in 'A'..'Z')) i++
                val raw = s.substring(start, i)
                if (raw.lowercase() !in WORDS) fail(Code.INVALID_EXPRESSION, "Unknown word '$raw'")
                out.add(TWord(raw.lowercase(), raw))
            }
            c in "+-*/^()%" -> { out.add(TSym(c)); i++ }
            else -> fail(Code.INVALID_EXPRESSION, "Unexpected character '$c'")
        }
    }
    return out
}

// ---------- AST ----------
private sealed interface Node
private data class Num(val v: Double) : Node
private object AnsNode : Node
private data class Group(val e: Node) : Node          // parentheses: stops the "relative percent" rule (R1)
private data class Pct(val e: Node) : Node            // postfix %
private data class Neg(val e: Node) : Node
private data class Pos(val e: Node) : Node
private data class Bin(val op: String, val l: Node, val r: Node) : Node   // + - * / ^ of
private data class Call(val fn: String, val arg: Node) : Node

/**
 * Recursive descent, one function per precedence level (spec §3.3):
 * add < mul(* / of) < unary < power(^, right-assoc) < postfix(%) < primary.
 */
private class Parser(val t: List<Tok>) {
    var p = 0
    fun peek(): Tok? = t.getOrNull(p)
    fun isSym(c: Char) = (peek() as? TSym)?.c == c

    fun parse(): Node {
        if (t.isEmpty()) fail(Code.INVALID_EXPRESSION, "Nothing to calculate")
        val n = add()
        if (p < t.size) fail(Code.INVALID_EXPRESSION, "Unexpected symbol")   // leftovers, e.g. 2(3)
        return n
    }

    fun add(): Node {
        var l = mul()
        while (true) {
            val k = peek()
            if (k is TSym && (k.c == '+' || k.c == '-')) { p++; l = Bin(k.c.toString(), l, mul()) } else return l
        }
    }

    fun mul(): Node {
        var l = unary()
        while (true) {
            val k = peek()
            val op = when {
                k is TSym && (k.c == '*' || k.c == '/') -> k.c.toString()
                k is TWord && k.w == "of" -> "of"
                else -> return l
            }
            p++
            l = Bin(op, l, unary())
        }
    }

    fun unary(): Node {
        val k = peek()
        if (k is TSym && k.c == '-') { p++; return Neg(unary()) }
        if (k is TSym && k.c == '+') { p++; return Pos(unary()) }
        return power()
    }

    // The exponent is a unary, so 2^-1 works and 2^3^2 = 2^(3^2).
    fun power(): Node {
        val base = postfix()
        if (isSym('^')) { p++; return Bin("^", base, unary()) }
        return base
    }

    fun postfix(): Node {
        var n = primary()
        while (isSym('%')) { p++; n = Pct(n) }
        return n
    }

    fun primary(): Node {
        val k = peek() ?: fail(Code.INVALID_EXPRESSION, "The expression ends too early")
        p++
        return when (k) {
            is TNum -> Num(k.v)
            is TWord -> when (k.w) {
                "ans" -> AnsNode
                "sqrt", "abs" -> {
                    if (!isSym('(')) fail(Code.INVALID_EXPRESSION, "${k.w} needs parentheses, like ${k.w}(4)")
                    p++
                    val a = add()
                    close()
                    Call(k.w, a)
                }
                else -> fail(Code.INVALID_EXPRESSION, "Unexpected '${k.w}'")   // a bare "of"
            }
            is TSym -> if (k.c == '(') { val e = add(); close(); Group(e) }
                       else fail(Code.INVALID_EXPRESSION, "Unexpected symbol")
        }
    }

    fun close() {
        if (peek() == null) fail(Code.INVALID_EXPRESSION, "Missing closing parenthesis")
        if (!isSym(')')) fail(Code.INVALID_EXPRESSION, "Unexpected symbol")
        p++
    }
}

// ---------- Evaluator ----------
/** NaN and Infinity never reach the user (ARCHITECTURE.md). */
private fun ck(x: Double): Double {
    if (x.isNaN()) fail(Code.DOMAIN_ERROR, "The result is not a number")
    if (x.isInfinite()) fail(Code.OVERFLOW, "The result is too large")
    return x
}

private fun eval(n: Node, ans: Double): Double = when (n) {
    is Num -> n.v
    AnsNode -> ans
    is Group -> eval(n.e, ans)
    is Pct -> ck(eval(n.e, ans) / 100)
    is Neg -> -eval(n.e, ans)
    is Pos -> eval(n.e, ans)
    is Call -> {
        val a = eval(n.arg, ans)
        if (n.fn == "sqrt") {
            if (a < 0) fail(Code.DOMAIN_ERROR, "Cannot take the square root of a negative number")
            Math.sqrt(a)
        } else Math.abs(a)
    }
    is Bin -> evalBin(n, ans)
}

private fun evalBin(n: Bin, ans: Double): Double {
    val l = eval(n.l, ans)
    // Spec §3.4: a % that is the DIRECT right operand of + or - is relative to the left side.
    val r = n.r
    if ((n.op == "+" || n.op == "-") && r is Pct) {
        val amount = l * (eval(r.e, ans) / 100)
        return ck(if (n.op == "+") l + amount else l - amount)
    }
    val rv = eval(r, ans)
    return when (n.op) {
        "+" -> ck(l + rv)
        "-" -> ck(l - rv)
        "*", "of" -> ck(l * rv)
        "/" -> {
            if (rv == 0.0) fail(Code.DIV_BY_ZERO, "Cannot divide by zero")
            ck(l / rv)
        }
        else -> power(l, rv)
    }
}

/** Spec §3.5 power rules. */
private fun power(b: Double, e: Double): Double {
    if (b == 0.0 && e == 0.0) fail(Code.UNDEFINED, "0^0 is undefined")
    if (b == 0.0 && e < 0) fail(Code.DIV_BY_ZERO, "Zero cannot be raised to a negative power")
    if (b < 0 && e != Math.floor(e)) fail(Code.DOMAIN_ERROR, "A negative number cannot have a fractional power")
    return ck(Math.pow(b, e))                       // 10^400 -> Infinity -> OVERFLOW; 10^-400 -> 0
}

/** One Standard Calculator session: holds `ans`, which changes only after a fully successful line. */
class Calculator {
    var ans: Double = 0.0
        private set

    /** Evaluates one line and returns the formatted result. Throws ArithmosError. */
    fun evaluate(line: String): String {
        if (line.length > 20_000) fail(Code.INVALID_EXPRESSION, "The expression is too long")
        val v = eval(Parser(tokenize(line)).parse(), ans)
        val text = formatNumber(v)
        ans = v                                     // only reached when everything succeeded
        return text
    }
}