package arithmos.cli

/** One answer in a list. `aliases` are extra typed names (for units: the symbol and the name). */
class Option(val label: String, val aliases: List<String> = emptyList())

/**
 * One question, many answers. With a selector: arrows (Esc/b back, q quit, any other printable
 * key starts a typed line). Without one (pipes, files, tests, ARITHMOS_PLAIN=1): a numbered list.
 * A typed line may be a number, a name/alias, back, quit, help, or - via [onLine] - a one-line
 * command (returns true if it handled the line). Anything else is an error and the list comes back.
 * [exitLabel] adds the "0) Exit" row of the main menu.
 */
fun pick(io: Io, title: String, options: List<Option>, back: Boolean, quit: Boolean = true,
         exitLabel: String? = null, onLine: ((String) -> Boolean)? = null): Outcome {
    val labels = options.map { it.label } + listOfNotNull(exitLabel)
    while (true) {
        val raw: String = if (io.hasSelector) {
            when (val r = io.select(title, labels, SelOpts(back, quit, true))) {
                is Chosen -> return if (exitLabel != null && r.index == options.size) GoQuit else r
                GoBack -> return GoBack
                GoQuit -> return GoQuit
                EndOfInput -> return EndOfInput
                is Typed -> io.readLinePrefill("> ", r.text) ?: return EndOfInput
            }
        } else {
            io.write(listing(title, labels, exitLabel != null, back))
            io.readLine("> ") ?: return EndOfInput
        }

        val line = raw.trim()
        if (line.isEmpty()) continue
        val lo = line.lowercase()
        when {
            lo == "quit" -> return GoQuit
            lo == "back" && back -> return GoBack
            lo == "help" || lo == "?" -> { io.write("Type a number or a name from the list. back goes back, quit exits.\n"); continue }
            exitLabel != null && (lo == "0" || lo == exitLabel.lowercase()) -> return GoQuit
            lo.toIntOrNull() in 1..options.size -> return Chosen(lo.toInt() - 1)
            else -> {
                val idx = options.indexOfFirst { o -> o.label.lowercase() == lo || o.aliases.any { it.lowercase() == lo } }
                if (idx >= 0) return Chosen(idx)
                if (onLine != null && onLine(line)) continue          // a one-line command ran; show the list again
                io.write("Error [UNKNOWN_COMMAND]: Pick one from the list\n")
            }
        }
    }
}

/** The numbered list of the plain mode: `  1) label`. */
private fun listing(title: String, labels: List<String>, hasExit: Boolean, back: Boolean): String {
    val sb = StringBuilder(title).append('\n')
    val n = if (hasExit) labels.size - 1 else labels.size
    for (i in 0 until n) sb.append("  ${i + 1}) ${labels[i]}\n")
    if (hasExit) sb.append("  0) ${labels.last()}\n")
    sb.append("Type a number or a name").append(if (back) ", back" else "").append(", quit or help\n")
    return sb.toString()
}