package arithmos.cli

import arithmos.calculator.Calculator
import arithmos.converter.*
import arithmos.programmer.*
import arithmos.shared.*

/** How a tool's prompt loop ended. */
enum class Exit { BACK, QUIT, EOF }

private val WS = Regex("\\s+")
private fun cap(s: String) = s.replaceFirstChar { it.uppercase() }

/** Programmer result -> output lines (spec §4.4, R32). */
fun progLines(r: ProgResult): List<String> = when (r) {
    is Values -> fields(r.v).map { "${it.first}: ${it.second}" }
    is Line -> listOf(r.text)
    is BaseSet -> listOf("Input base: ${r.base.label}")
}

/** Runs a handler; every failure becomes one "Error [CODE]: message" line, so garbage never crashes. */
fun runLine(line: String, handle: (String) -> List<String>): String = try {
    handle(line).joinToString("") { it + "\n" }
} catch (e: ArithmosError) {
    "Error [${e.code}]: ${e.message}\n"
} catch (e: Exception) {
    "Error [INTERNAL]: ${e.message}\n"
} catch (e: StackOverflowError) {
    "Error [INTERNAL]: expression too deeply nested\n"
}

/**
 * The prompt loop of every tool: help/?, back, quit (case-insensitive), blank lines ignored,
 * end of input exits cleanly, every error printed as `Error [CODE]: message`.
 */
fun promptLoop(io: Io, prompt: String, intro: String, help: String, handle: (String) -> List<String>): Exit {
    io.write(intro + "\n")
    while (true) {
        val line = (io.readLine(prompt) ?: return Exit.EOF).trim()
        if (line.isEmpty()) continue
        when (line.lowercase()) {
            "back" -> return Exit.BACK
            "quit" -> return Exit.QUIT
            "help", "?" -> { io.write(help + "\n"); continue }
        }
        io.write(runLine(line, handle))
    }
}

private const val STANDARD_HELP = """Standard Calculator
  Operators: + - * / ^     Unary: -5  +5     Parentheses: ( )
  Percent: 50%   200 + 10%   20% of 150     Functions: sqrt(x)  abs(x)     Previous result: ans
  Commands: help (or ?), back, quit"""

private const val PROGRAMMER_HELP = """Programmer Calculator (64-bit signed)
  <value>                 show in HEX / DEC / OCT / BIN        prefixes: 0b 0o 0d 0x
  base <bin|oct|dec|hex>  set the input base
  [convert] <value> <from> <to>     e.g. 255 dec hex
  <a> AND|OR|XOR <b>      NOT <a>      <a> << n   <a> >> n (arithmetic)   <a> >>> n (logical)
  Commands: help (or ?), back, quit"""

private const val CONVERTER_HELP = """Unit Converter
  <value>                          convert with the chosen units
  [convert] <value> <from> <to>    e.g. 100 cm in      <value> <from> all lists every unit
  list   |   list <category>
  Commands: help (or ?), back (one step), quit"""

fun standardTool(io: Io): Exit {
    val calc = Calculator()
    return promptLoop(io, "standard> ", "Standard Calculator. Type an expression (help, back, quit).", STANDARD_HELP) {
        listOf(calc.evaluate(it))
    }
}

fun programmerTool(io: Io): Exit {
    val prog = Programmer()
    return promptLoop(io, "programmer> ", "Programmer Calculator. Type a value or a command (help, back, quit).", PROGRAMMER_HELP) {
        progLines(prog.run(it))
    }
}

/** True if `line` looks like a converter one-line command (convert/list or three words). Runs it. */
private fun converterLine(io: Io, conv: Converter, line: String): Boolean {
    val w = line.trim().split(WS)
    if (w[0].lowercase() !in setOf("convert", "list") && w.size != 3) return false
    io.write(runLine(line) { conv.run(it) })
    return true
}

private fun unitOptions(c: Category) =
    c.units.map { Option("${it.symbol} — ${it.name}", listOf(it.symbol, it.name)) }

/** The values prompt shows the units: `converter (m → yd)>`. `list` and the one-line forms still work. */
private fun valuesLoop(io: Io, conv: Converter, cat: Category, from: UnitDef, to: UnitDef): Exit =
    promptLoop(io, "converter (${from.symbol} → ${to.symbol})> ",
        "${cap(cat.name)}: ${from.name} → ${to.name}. Type a value (help, back, quit).", CONVERTER_HELP) { line ->
        val w = line.trim().split(WS)
        if (w.size == 1 && w[0].lowercase() !in setOf("list", "convert"))
            listOf("${formatNumber(conv.parseValue(w[0]))} ${from.symbol} = ${conv.convert(w[0], from.symbol, to.symbol)} ${to.symbol}")
        else conv.run(line)
    }

/** The guided flow: category -> from -> to -> values. `back` steps back one stage (spec §2.1, R23). */
fun converterTool(io: Io): Exit {
    val conv = Converter()
    val onLine = { line: String -> converterLine(io, conv, line) }
    var stage = 0
    var cat = CATEGORIES[0]
    var from = cat.units[0]
    var to = cat.units[0]
    while (true) {
        when (stage) {
            0 -> when (val r = pick(io, "Unit Converter — choose a category",
                CATEGORIES.map { Option(it.name) }, back = true, onLine = onLine)) {
                is Chosen -> { cat = CATEGORIES[r.index]; stage = 1 }
                GoBack -> return Exit.BACK
                GoQuit -> return Exit.QUIT
                else -> return Exit.EOF
            }
            1 -> when (val r = pick(io, "${cap(cat.name)} — convert from", unitOptions(cat), back = true, onLine = onLine)) {
                is Chosen -> { from = cat.units[r.index]; stage = 2 }
                GoBack -> stage = 0
                GoQuit -> return Exit.QUIT
                else -> return Exit.EOF
            }
            2 -> when (val r = pick(io, "${cap(cat.name)} — convert from ${from.symbol} to", unitOptions(cat), back = true, onLine = onLine)) {
                is Chosen -> { to = cat.units[r.index]; stage = 3 }
                GoBack -> stage = 1
                GoQuit -> return Exit.QUIT
                else -> return Exit.EOF
            }
            else -> when (valuesLoop(io, conv, cat, from, to)) {
                Exit.BACK -> stage = 2
                Exit.QUIT -> return Exit.QUIT
                Exit.EOF -> return Exit.EOF
            }
        }
    }
}

/** The main menu (spec §2.1). Returns when the user quits or input ends. */
fun runInteractive(io: Io) {
    val tools = listOf(
        Option("Standard Calculator", listOf("standard", "std")),
        Option("Programmer Calculator", listOf("programmer", "prog")),
        Option("Unit Converter", listOf("converter", "convert")))
    while (true) {
        val r = pick(io, "Arithmos 1.0 — Core CLI", tools, back = false, exitLabel = "Exit")
        val exit = when (r) {
            is Chosen -> when (r.index) { 0 -> standardTool(io); 1 -> programmerTool(io); else -> converterTool(io) }
            else -> return
        }
        if (exit != Exit.BACK) return
    }
}