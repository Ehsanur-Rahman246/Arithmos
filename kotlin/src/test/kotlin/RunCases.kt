package arithmos.test

import arithmos.calculator.Calculator
import arithmos.cli.*
import arithmos.converter.*
import arithmos.programmer.*
import arithmos.shared.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.PrintStream
import kotlin.system.exitProcess

/** One session per case: calculator `ans` and the programmer input base live across steps. */
private class Session {
    val calc = Calculator()
    val prog = Programmer()
    val conv = Converter()
}

/** Runs one line. Result: List<String> (text lines), Map (programmer fields) or Code (an error). */
private fun exec(tool: String, s: Session, line: String): Any = try {
    when (tool) {
        "standard" -> listOf(s.calc.evaluate(line))
        "programmer" -> when (val r = s.prog.run(line)) {
            is Values -> fields(r.v).toMap()
            else -> progLines(r)
        }
        else -> s.conv.run(line)
    }
} catch (e: ArithmosError) { e.code }

/** Asserts results and codes only, never prompt text (docs/test-cases.md loader contract). */
private fun check(id: String, spec: Map<*, *>, res: Any) {
    val err = spec["error"] as String?
    val exp = spec["expected"]
    when {
        err != null -> H.eq(id, err, (res as? Code)?.name ?: "no error: $res")
        exp is String -> H.eq(id, listOf(exp), res)
        exp is Map<*, *> -> {
            val m = res as? Map<*, *>
            for ((k, v) in exp) H.eq("$id.$k", v, m?.get(k))
        }
        spec["expectedContains"] != null ->
            for (s in spec["expectedContains"] as List<*>) H.check("$id contains $s", (res as? List<*>)?.contains(s) == true) { "got $res" }
    }
}

private fun runCase(c: Map<*, *>) {
    val id = c["id"] as String
    val tool = c["tool"] as String
    val s = Session()
    (c["setup"] as List<*>?)?.forEach { exec(tool, s, it as String) }      // e.g. `base hex`
    val steps = c["steps"] as List<*>?
    if (steps != null) for ((n, st) in steps.withIndex()) {
        st as Map<*, *>
        check("$id.${n + 1}", st, exec(tool, s, st["input"] as String))
    } else check(id, c, exec(tool, s, c["input"] as String))
}

private fun fmt(name: String, expected: String, x: Double) = H.eq("format $name", expected, formatNumber(x))

private fun extras() {
    // --- number formatting boundaries (spec §2.3)
    fmt("1e15", "1e+15", 1e15)
    fmt("15 digits", "123456789012000", 123456789012345.0)      // rounded to 12 significant digits
    fmt("rounds up to 1e15", "1e+15", 999999999999999.0)        // 15 nines round up to 1e+15
    fmt("1e-6", "0.000001", 1e-6); fmt("1e-7", "1e-7", 1e-7); fmt("-0", "0", -0.0)
    fmt("1e-6", "0.000001", 1e-6); fmt("1e-7", "1e-7", 1e-7); fmt("-0", "0", -0.0)
    fmt("tie", "100000000001", 100000000000.5); fmt("noise", "0.3", 0.1 + 0.2); fmt("1.5e20", "1.5e+20", 1.5e20)
    fmt("long", "1.23456789012e+19", 12345678901234567890.0); fmt("neg", "-2.5", -2.5)

    // --- settled amendments R1-R20
    val c = Calculator()
    for ((l, e) in listOf("200 + (10%)" to "200.1", "200 + 5 * 10%" to "200.5", "2^50%" to "1.41421356237",
        "50%%" to "0.005", "5 of 10" to "50", "10^-400" to "0", "100000000000.5" to "100000000001"))
        H.eq("R $l", e, c.evaluate(l))
    H.eq("R6 ANS", "0", Calculator().evaluate("ANS"))           // fresh session: ans starts at 0
    for (l in listOf("1e5", ".", "5.5.5", "2 3", "of 5", "sqrt 4", "()"))
        H.eq("R err $l", Code.INVALID_EXPRESSION, (exec("standard", Session(), l) as? Code))
    fun dec(s: Session, l: String) = (exec("programmer", s, l) as? Map<*, *>)?.get("DEC")
    val hex = Session().also { it.prog.run("base hex") }
    H.eq("R11 A AND F", "10", dec(hex, "A AND F")); H.eq("R11 DEC", "3564", dec(hex, "DEC"))
    H.eq("R30 0B", "11", dec(hex, "0B"))
    val d = Session()
    H.eq("R12 NOT 0xFF", "-256", dec(d, "NOT 0xFF")); H.eq("R12 NOT -1", "0", dec(d, "NOT -1"))
    H.eq("R14 -0x80", "-128", dec(d, "-0x80")); H.eq("R29 1<<3", "8", dec(d, "1<<3"))
    H.eq("R13", Code.INVALID_SHIFT, exec("programmer", d, "1 << 0x3"))
    H.eq("R30 0x in dec", Code.INVALID_DIGIT, exec("programmer", d, "0x"))
    H.eq("R15", listOf("-1"), exec("programmer", d, "convert FFFFFFFFFFFFFFFF hex dec"))
    H.eq("R16", Code.INVALID_NUMBER, exec("converter", d, "convert 1e3 m cm"))
    H.eq("R17", Code.OVERFLOW, exec("converter", d, "convert ${"9".repeat(309)} m m"))
    H.eq("R19", Code.UNKNOWN_COMMAND, exec("converter", d, "list foo"))
    H.check("R20 limit", (exec("converter", d, "convert 0 k all") as? List<*>)?.contains("c: -273.15") == true)

    // --- unit table sanity
    H.eq("twelve categories", 12, CATEGORIES.size)
    H.eq("symbols unique", CATEGORIES.sumOf { it.units.size }, BY_SYMBOL.size)

    // --- garbage never crashes: only ArithmosError may escape an engine
    val garbage = listOf("", " ", "((((", "))))", "%", "of", "sqrt", "1 <<", ">>>", "0x", "-", "\uD83D\uDE42", "1e999",
        "999999999999999999999999999", "convert", "list a b c", "NOT NOT", "base", "1 + + + 1", "ans ans", "\t", "1 << 1 << 1")
    for (g in garbage) for (tool in listOf("standard", "programmer", "converter")) {
        try { exec(tool, Session(), g) } catch (e: Throwable) { H.check("garbage $tool '$g'", false) { e.toString() } }
    }

    // --- a scripted CLI session through the numbered lists
    val io = FakeIo(false, lines = mutableListOf("1", "25 + 17", "back", "2", "0xFF", "back", "3", "list", "back", "quit"))
    runInteractive(io)
    val text = io.out.toString()
    H.check("session std", text.contains("\n42\n")); H.check("session prog", text.contains("HEX: FF"))
    H.check("session conv", text.contains("length, mass, area"))

    // --- one-shot exit codes (0 / 1 / 2) and stream routing
    fun shot(vararg a: String): Triple<Int, String, String> {
        val o = ByteArrayOutputStream(); val e = ByteArrayOutputStream()
        val code = runOneShot(a.toList(), PrintStream(o, true, "UTF-8"), PrintStream(e, true, "UTF-8"))
        return Triple(code, o.toString("UTF-8").trim(), e.toString("UTF-8").trim())
    }
    H.eq("shot std", Pair(0, "14"), shot("std", "2 + 3 * 4").let { it.first to it.second })
    H.eq("shot error code", 1, shot("std", "10 / 0").first)
    H.check("shot error on stderr", shot("std", "10 / 0").third.startsWith("Error [DIV_BY_ZERO]"))
    H.eq("shot usage", 2, shot("bogus").first)
    H.eq("shot convert", "39.3700787402", shot("convert", "100", "cm", "in").second)
    H.eq("shot prog", 0, shot("PROG", "5 AND 3").first)
}

fun main(args: Array<String>) {
    val path = args.firstOrNull() ?: "../docs/release-1-cases.json"
    val cases = Json.parse(File(path).readText()) as List<*>
    for (c in cases) runCase(c as Map<*, *>)
    H.eq("175 shared cases", 175, cases.size)
    extras()
    exitProcess(H.summary())
}