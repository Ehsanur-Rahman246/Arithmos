package arithmos.converter

import arithmos.shared.*

/** Pure conversion logic; stateless. Handles the one-line forms (convert, shorthand, all, list). */
class Converter {
    private val number = Regex("[+-]?([0-9]+\\.?[0-9]*|\\.[0-9]+)")      // plain decimal only (R16)
    private val ws = Regex("\\s+")

    /** A plain decimal value; `1e3`, `1,000`, `abc` are INVALID_NUMBER. */
    fun parseValue(text: String): Double {
        if (!number.matches(text)) fail(Code.INVALID_NUMBER, "'$text' is not a number")
        val v = text.toDouble()
        if (v.isInfinite()) fail(Code.OVERFLOW, "That number is too large")
        return v
    }

    private fun find(symbol: String): Pair<Category, UnitDef> =
        BY_SYMBOL[symbol.lowercase()] ?: fail(Code.UNKNOWN_UNIT, "'$symbol' is not a known unit. Try: list")

    /** value x from.factor / to.factor, or the temperature formulas. */
    private fun compute(v: Double, cat: Category, f: UnitDef, t: UnitDef): Double {
        val r = if (cat.name == "temperature") temperature(v, f.symbol, t.symbol) else v * f.factor / t.factor
        if (r.isNaN() || r.isInfinite()) fail(Code.OVERFLOW, "Result is too large to represent")
        return r
    }

    /** Goes through degrees Celsius. The INPUT is checked against absolute zero in its own unit (R20). */
    private fun temperature(v: Double, from: String, to: String): Double {
        val limit = when (from) { "c" -> -273.15; "f" -> -459.67; else -> 0.0 }
        if (v < limit) fail(Code.BELOW_ABSOLUTE_ZERO, "That is below absolute zero")
        val c = when (from) { "c" -> v; "f" -> (v - 32.0) * 5.0 / 9.0; else -> v - 273.15 }
        return when (to) { "c" -> c; "f" -> c * 9.0 / 5.0 + 32.0; else -> c + 273.15 }
    }

    /** One conversion, formatted per spec §2.3. */
    fun convert(value: String, from: String, to: String): String {
        val (cat, f) = find(from)
        val (cat2, t) = find(to)
        if (cat !== cat2) fail(Code.INCOMPATIBLE_UNITS, "Cannot convert ${cat.name} to ${cat2.name}")
        return formatNumber(compute(parseValue(value), cat, f, t))
    }

    /** The `all` target: `symbol: value` per unit in table order. Any overflow fails the whole command (R18). */
    fun convertAll(value: String, from: String): List<String> {
        val (cat, f) = find(from)
        val v = parseValue(value)
        return cat.units.map { "${it.symbol}: ${formatNumber(compute(v, cat, f, it))}" }
    }

    private fun conv(value: String, from: String, to: String): List<String> =
        if (to.lowercase() == "all") convertAll(value, from) else listOf(convert(value, from, to))

    /** Runs one line: `convert v a b`, `v a b`, `list`, `list <category>`. */
    fun run(line: String): List<String> {
        val w = line.trim().split(ws).filter { it.isNotEmpty() }
        if (w.isEmpty()) fail(Code.UNKNOWN_COMMAND, "Type a value, e.g. 100")
        return when (w[0].lowercase()) {
            "list" -> when (w.size) {
                1 -> listOf(CATEGORIES.joinToString(", ") { it.name })
                2 -> {
                    val c = CATEGORIES.firstOrNull { it.name == w[1].lowercase() }
                        ?: fail(Code.UNKNOWN_COMMAND, "'${w[1]}' is not a category. Try: list")
                    listOf(c.units.joinToString(", ") { it.symbol })
                }
                else -> fail(Code.UNKNOWN_COMMAND, "Use: list  or  list <category>")
            }
            "convert" -> {
                if (w.size != 4) fail(Code.UNKNOWN_COMMAND, "Use: convert <value> <from> <to>")
                conv(w[1], w[2], w[3])
            }
            else -> {
                if (w.size != 3) fail(Code.UNKNOWN_COMMAND, "Not a command. Try: convert 100 cm in")
                conv(w[0], w[1], w[2])
            }
        }
    }
}