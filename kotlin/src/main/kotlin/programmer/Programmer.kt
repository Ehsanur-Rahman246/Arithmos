package arithmos.programmer

import arithmos.shared.*
import java.math.BigInteger

/** The four bases of spec §4.2. */
enum class Base(val radix: Int, val label: String) { BIN(2, "bin"), OCT(8, "oct"), DEC(10, "dec"), HEX(16, "hex") }

/** What one programmer line produced. The cli layer turns it into text. */
sealed interface ProgResult
data class Values(val v: Long) : ProgResult          // show in all four bases
data class Line(val text: String) : ProgResult       // a plain line (convert)
data class BaseSet(val base: Base) : ProgResult      // `base hex`

fun baseOf(name: String): Base? = Base.values().firstOrNull { it.label == name.lowercase() }

/**
 * Kotlin's Long IS the spec's 64-bit signed two's-complement model. The java.lang.Long
 * helpers print negative values as their unsigned 64-bit pattern (spec §4.4).
 */
fun toBase(v: Long, b: Base): String = when (b) {
    Base.DEC -> v.toString()
    Base.HEX -> java.lang.Long.toHexString(v).uppercase()
    Base.OCT -> java.lang.Long.toOctalString(v)
    Base.BIN -> java.lang.Long.toBinaryString(v)
}

/** The four display fields in spec order. */
fun fields(v: Long): List<Pair<String, String>> = listOf(
    "HEX" to toBase(v, Base.HEX), "DEC" to toBase(v, Base.DEC),
    "OCT" to toBase(v, Base.OCT), "BIN" to toBase(v, Base.BIN)
)

private val TWO63: BigInteger = BigInteger.ONE.shiftLeft(63)
private val TWO64: BigInteger = BigInteger.ONE.shiftLeft(64)
private val WS = Regex("\\s+")
private val SHIFT = Regex("^(.*?)\\s*(>>>|<<|>>)\\s*(.*)$")        // spaces optional around shifts (R29)
private const val SHIFT_MSG = "A shift count must be a whole number from 0 to 63"

/**
 * Parses one literal (spec §4.2/4.3). Order: sign -> prefix -> character check
 * (INVALID_NUMBER) -> digit check (INVALID_DIGIT) -> range (OUT_OF_RANGE).
 * Digits go through BigInteger, never through double.
 */
fun parseLiteral(token: String, inputRadix: Int): Long {
    var s = token
    var neg = false
    if (s.startsWith("-")) { neg = true; s = s.substring(1) }

    // A prefix counts only when digits follow it (R30): "0B" in hex mode is the number 11.
    var radix = inputRadix
    if (s.length > 2 && s[0] == '0') {
        val p = when (s[1]) { 'b', 'B' -> 2; 'o', 'O' -> 8; 'd', 'D' -> 10; 'x', 'X' -> 16; else -> 0 }
        if (p != 0) { radix = p; s = s.substring(2) }
    }

    if (s.isEmpty() || !s.all { it in '0'..'9' || it in 'a'..'z' || it in 'A'..'Z' })
        fail(Code.INVALID_NUMBER, "'$token' is not a number")
    for (c in s) {
        val d = Character.digit(c, 16)
        if (d < 0 || d >= radix)
            fail(Code.INVALID_DIGIT, "'${c.uppercaseChar()}' is not a ${Base.values().first { it.radix == radix }.label} digit")
    }

    val t = s.trimStart('0')
    if (t.length > 70) fail(Code.OUT_OF_RANGE, "That number does not fit in 64 bits")   // far beyond 2^64
    val mag = if (t.isEmpty()) BigInteger.ZERO else BigInteger(t, radix)

    if (radix == 10) {                                       // decimal must fit the signed range
        val v = if (neg) mag.negate() else mag
        if (v < TWO63.negate() || v >= TWO63) fail(Code.OUT_OF_RANGE, "That number does not fit in 64 bits")
        return v.toLong()
    }
    if (neg) {                                               // "-FF": negate the magnitude, which may be up to 2^63
        if (mag > TWO63) fail(Code.OUT_OF_RANGE, "That number does not fit in 64 bits")
        return mag.negate().toLong()
    }
    if (mag >= TWO64) fail(Code.OUT_OF_RANGE, "That number needs more than 64 bits")
    return mag.toLong()                                      // raw bit pattern reinterpreted as signed
}

private fun shiftCount(s: String): Int {
    if (s.isEmpty() || !s.all { it in '0'..'9' }) fail(Code.INVALID_SHIFT, SHIFT_MSG)
    val t = s.trimStart('0')
    if (t.length > 2) fail(Code.INVALID_SHIFT, SHIFT_MSG)
    val n = if (t.isEmpty()) 0 else t.toInt()
    if (n > 63) fail(Code.INVALID_SHIFT, SHIFT_MSG)
    return n
}

/** One Programmer Calculator session: holds the input base. */
class Programmer {
    var base: Base = Base.DEC
        private set

    fun run(line: String): ProgResult {
        val text = line.trim()
        if (text.isEmpty()) fail(Code.UNKNOWN_COMMAND, "Type a number or a command. Try help")

        SHIFT.matchEntire(text)?.let { return shift(it) }

        val w = text.split(WS)
        val first = w[0].lowercase()
        return when {
            first == "base" -> {
                if (w.size != 2) fail(Code.INVALID_BASE, "Use: base bin | oct | dec | hex")
                val b = baseOf(w[1]) ?: fail(Code.INVALID_BASE, "'${w[1]}' is not a base. Use bin, oct, dec or hex")
                base = b
                BaseSet(b)
            }
            first == "convert" -> {
                if (w.size != 4) fail(Code.UNKNOWN_COMMAND, "Use: convert <value> <from> <to>")
                convert(w[1], w[2], w[3])
            }
            first == "not" -> {
                if (w.size != 2) fail(Code.UNKNOWN_COMMAND, "Use: NOT <value>")
                Values(parseLiteral(w[1], base.radix).inv())
            }
            w.size == 1 -> Values(parseLiteral(w[0], base.radix))
            // The operator is always the MIDDLE word, so hex words like DEC or FACE stay numbers (R11).
            w.size == 3 && w[1].lowercase() in setOf("and", "or", "xor") -> {
                val a = parseLiteral(w[0], base.radix)
                val b = parseLiteral(w[2], base.radix)
                Values(when (w[1].lowercase()) { "and" -> a and b; "or" -> a or b; else -> a xor b })
            }
            // Three words whose last two are base names: `convert` is optional (R24).
            w.size == 3 && baseOf(w[1]) != null && baseOf(w[2]) != null -> convert(w[0], w[1], w[2])
            else -> fail(Code.UNKNOWN_COMMAND, "Not a command. Try help")
        }
    }

    private fun shift(m: MatchResult): ProgResult {
        val lhs = m.groupValues[1].trim()
        val op = m.groupValues[2]
        val rhs = m.groupValues[3].trim()
        if (lhs.isEmpty() || rhs.isEmpty()) fail(Code.UNKNOWN_COMMAND, "Not a command. Try help")
        val v = parseLiteral(lhs, base.radix)
        val n = shiftCount(rhs)                              // always decimal, 0..63
        return Values(when (op) { "<<" -> v shl n; ">>" -> v shr n; else -> v ushr n })
    }

    /** `convert <value> <from> <to>`: the explicit FROM base reads the value, not the input base. */
    private fun convert(value: String, from: String, to: String): ProgResult {
        val fb = baseOf(from) ?: fail(Code.INVALID_BASE, "'$from' is not a base. Use bin, oct, dec or hex")
        val tb = baseOf(to) ?: fail(Code.INVALID_BASE, "'$to' is not a base. Use bin, oct, dec or hex")
        return Line(toBase(parseLiteral(value, fb.radix), tb))
    }
}