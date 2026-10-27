package arithmos.cli

enum class KeyKind { UP, DOWN, HOME, END, PGUP, PGDN, ENTER, ESC, CTRL_C, CTRL_D, CHAR, OTHER }
data class Key(val kind: KeyKind, val ch: String = "")

/** POSIX: raw terminal bytes -> keys (pure, test X3). An arrow arrives as ONE chunk, so a lone ESC is ESC. */
fun parseKeys(b: ByteArray): List<Key> {
    val out = ArrayList<Key>()
    fun u(k: Int): Int = b[k].toInt() and 0xff
    var i = 0
    while (i < b.size) {
        val c = u(i)
        if (c == 0x1b) {
            if (i + 1 < b.size && (u(i + 1) == '['.code || u(i + 1) == 'O'.code)) {
                var j = i + 2
                val params = StringBuilder()
                while (j < b.size && u(j) in 0x30..0x3f) { params.append(u(j).toChar()); j++ }   // parameter bytes
                while (j < b.size && u(j) in 0x20..0x2f) j++                                      // intermediate bytes
                if (j >= b.size) { out.add(Key(KeyKind.OTHER)); break }
                val kind = when (u(j).toChar()) {
                    'A' -> KeyKind.UP
                    'B' -> KeyKind.DOWN
                    'H' -> KeyKind.HOME
                    'F' -> KeyKind.END
                    '~' -> when (params.toString()) {
                        "1", "7" -> KeyKind.HOME
                        "4", "8" -> KeyKind.END
                        "5" -> KeyKind.PGUP
                        "6" -> KeyKind.PGDN
                        else -> KeyKind.OTHER
                    }
                    else -> KeyKind.OTHER
                }
                out.add(Key(kind))
                i = j + 1
            } else {
                out.add(Key(KeyKind.ESC))
                i++
            }
            continue
        }
        when {
            c == 0x0a && i > 0 && u(i - 1) == 0x0d -> {}                 // \r\n counts once
            c == 0x0d || c == 0x0a -> out.add(Key(KeyKind.ENTER))
            c == 0x03 -> out.add(Key(KeyKind.CTRL_C))
            c == 0x04 -> out.add(Key(KeyKind.CTRL_D))
            c < 0x20 || c == 0x7f -> out.add(Key(KeyKind.OTHER))          // other control keys are ignored
            c < 0x80 -> out.add(Key(KeyKind.CHAR, c.toChar().toString()))
            else -> {                                                      // UTF-8 multi-byte character
                val n = if (c >= 0xf0) 4 else if (c >= 0xe0) 3 else if (c >= 0xc0) 2 else 1
                if (n == 1) out.add(Key(KeyKind.OTHER)) else {
                    val e = minOf(i + n, b.size)
                    out.add(Key(KeyKind.CHAR, String(b, i, e - i, Charsets.UTF_8)))
                    i = e - 1
                }
            }
        }
        i++
    }
    return out
}

/**
 * Windows: keys from _getwch (pure, test X3). An arrow or function key arrives as a 0 or 0xE0
 * prefix followed by a second code, which `next` supplies. Ctrl-C (3) arrives as a key because
 * the selector turns off ENABLE_PROCESSED_INPUT.
 */
fun winKey(first: Int, next: () -> Int): Key = when {
    first == 0 || first == 0xE0 -> Key(when (next()) {
        72 -> KeyKind.UP
        80 -> KeyKind.DOWN
        71 -> KeyKind.HOME
        79 -> KeyKind.END
        73 -> KeyKind.PGUP
        81 -> KeyKind.PGDN
        else -> KeyKind.OTHER
    })
    first == 13 -> Key(KeyKind.ENTER)
    first == 27 -> Key(KeyKind.ESC)
    first == 3 -> Key(KeyKind.CTRL_C)
    first == 4 -> Key(KeyKind.CTRL_D)
    first < 32 || first == 127 -> Key(KeyKind.OTHER)
    Character.isHighSurrogate(first.toChar()) -> Key(KeyKind.CHAR, "" + first.toChar() + next().toChar())
    else -> Key(KeyKind.CHAR, first.toChar().toString())
}