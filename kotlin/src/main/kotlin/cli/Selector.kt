package arithmos.cli

/**
 * The arrow-key selector in three pure-ish layers:
 *   1. step()   key handling (pure)          2. render()  drawing (pure)
 *   3. run()    draw/read loop over an injectable KeySource and Screen.
 * (pick() in Pick.kt is the fourth layer.)
 */
object Selector {
    const val WINDOW = 10
    const val HIDE = "\u001b[?25l"
    const val SHOW = "\u001b[?25h"

    /** What one key does at a list of `count` rows with the selection on `index`. */
    fun step(index: Int, count: Int, key: Key, o: SelOpts, page: Int = WINDOW): Step {
        if (count == 0) return Ignore
        return when (key.kind) {
            KeyKind.UP -> Move((index - 1 + count) % count)          // wraps around
            KeyKind.DOWN -> Move((index + 1) % count)
            KeyKind.HOME -> Move(0)
            KeyKind.END -> Move(count - 1)
            KeyKind.PGUP -> Move(maxOf(0, index - page))
            KeyKind.PGDN -> Move(minOf(count - 1, index + page))
            KeyKind.ENTER -> Chosen(index)
            KeyKind.ESC -> if (o.back) GoBack else Ignore            // only when offered
            KeyKind.CTRL_C, KeyKind.CTRL_D -> EndOfInput
            KeyKind.OTHER -> Ignore                                  // other control keys
            KeyKind.CHAR -> when {
                key.ch == "b" && o.back -> GoBack                    // b and q act at once
                key.ch == "q" && o.quit -> GoQuit
                o.typing && key.ch.isNotBlank() -> Typed(key.ch)     // space does not start a typed line
                else -> Ignore
            }
        }
    }

    /** Rows shown: at most 10, and the whole block (title + rows + hint) must fit the terminal height. */
    fun windowSize(count: Int, rows: Int): Int = maxOf(1, minOf(WINDOW, count, rows - 3))

    /** Scrolls the window just enough to keep the selection visible. */
    fun fit(top: Int, index: Int, win: Int, count: Int): Int {
        var t = top
        if (index < t) t = index
        if (index >= t + win) t = index - win + 1
        return t.coerceIn(0, maxOf(0, count - win))
    }

    /** The hint line lists only the keys on offer. */
    fun hint(o: SelOpts): String {
        val p = arrayListOf("↑↓ move", "Enter select")
        if (o.back) p.add("Esc/b back")
        if (o.quit) p.add("q quit")
        if (o.typing) p.add("or type")
        return p.joinToString(" · ")
    }

    /** Cuts a line to `w` columns; longer lines end with "…". */
    fun clip(s: String, w: Int): String = if (s.length <= w) s else s.take(maxOf(0, w - 1)) + "…"

    /**
     * One screen line per list line, each at most (cols - 1) wide so a redraw can move up by
     * exactly the number of lines drawn. The selected row always has the ❯ pointer; with colour
     * it is also a full reverse-video bar.
     */
    fun render(title: String, labels: List<String>, index: Int, top: Int, win: Int, o: SelOpts,
               cols: Int, color: Boolean): List<String> {
        val w = maxOf(1, cols - 1)
        val out = ArrayList<String>()
        out.add(clip(title, w))
        for (i in top until minOf(top + win, labels.size)) {
            val sel = i == index
            var line = clip((if (sel) "❯ " else "  ") + labels[i], w)
            if (sel && color) line = "\u001b[7m" + line.padEnd(w) + "\u001b[0m"
            out.add(line)
        }
        out.add(clip(hint(o), w))
        return out
    }

    private fun erase(n: Int) = "\u001b[${n}A\u001b[J"        // up n lines, clear to the end of the screen

    /** Draw, read a key, repeat. Raw mode and the hidden cursor are always undone in `finally`. */
    fun run(keys: KeySource, screen: Screen, title: String, labels: List<String>, o: SelOpts): Outcome {
        var index = 0
        var top = 0
        var drawn = 0
        keys.enter()
        screen.write(HIDE)
        try {
            while (true) {
                val (cols, rows) = screen.size()                 // measured on every redraw: resizing works
                val win = windowSize(labels.size, rows)
                top = fit(top, index, win, labels.size)
                if (drawn > 0) screen.write(erase(drawn))
                val lines = render(title, labels, index, top, win, o, cols, screen.color)
                screen.write(lines.joinToString("\n") + "\n")
                drawn = lines.size

                val key = keys.read()
                val st: Step = if (key == null) EndOfInput else step(index, labels.size, key, o, win)
                when (st) {
                    is Move -> index = st.index
                    Ignore -> {}
                    is Outcome -> {
                        screen.write(erase(drawn))
                        if (st is Chosen) screen.write("✔ $title: ${labels[st.index]}\n")   // summary left behind
                        return st
                    }
                }
            }
        } finally {
            screen.write(SHOW)
            keys.leave()
        }
    }
}