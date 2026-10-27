package arithmos.cli

import arithmos.calculator.Calculator
import arithmos.converter.Converter
import arithmos.programmer.Programmer
import arithmos.shared.ArithmosError
import java.io.PrintStream

val USAGE = """Usage: arithmos                              interactive menu
       arithmos std <expression>              one calculation
       arithmos prog <command>                one programmer command
       arithmos convert <value> <from> <to>   one conversion
       arithmos list [category]               list categories or units""".trimIndent()

/**
 * One-shot mode (R31): results and --help to `out`; `Error [CODE]` lines and usage after bad
 * input to `err`. Exit status 0 success, 1 an Error line, 2 bad usage.
 */
fun runOneShot(args: List<String>, out: PrintStream, err: PrintStream): Int {
    val cmd = args[0].lowercase()
    val rest = args.drop(1).joinToString(" ")
    fun usage(): Int { err.println(USAGE); return 2 }

    val lines: List<String> = try {
        when (cmd) {
            "help", "--help", "-h", "?" -> { out.println(USAGE); return 0 }
            "std", "standard" -> if (rest.isBlank()) return usage() else listOf(Calculator().evaluate(rest))
            "prog", "programmer" -> if (rest.isBlank()) return usage() else progLines(Programmer().run(rest))
            "convert" -> if (rest.isBlank()) return usage() else Converter().run(args.joinToString(" "))
            "list" -> Converter().run(args.joinToString(" "))
            else -> return usage()
        }
    } catch (e: ArithmosError) {
        err.println("Error [${e.code}]: ${e.message}")
        return 1
    } catch (e: Exception) {
        err.println("Error [INTERNAL]: ${e.message}")
        return 1
    }
    for (l in lines) out.println(l)
    return 0
}