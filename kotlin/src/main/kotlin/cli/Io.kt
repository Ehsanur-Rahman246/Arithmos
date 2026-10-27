package arithmos.cli

/** The selector's possible results. Step = what one key does; Outcome = how a selector ends. */
sealed interface Step
data class Move(val index: Int) : Step
object Ignore : Step
sealed interface Outcome : Step
data class Chosen(val index: Int) : Outcome
object GoBack : Outcome
object GoQuit : Outcome
object EndOfInput : Outcome
data class Typed(val text: String) : Outcome        // a printable key that starts a typed line

/** Which keys act at one selector (spec §2.1 / ARCHITECTURE selector rules). */
class SelOpts(val back: Boolean, val quit: Boolean, val typing: Boolean)

/** Injectable keyboard: raw mode is on only between enter() and leave(). read() = null at end of input. */
interface KeySource {
    fun enter()
    fun leave()
    fun read(): Key?
}

/** Injectable screen: size() is (columns, rows). */
interface Screen {
    fun write(s: String)
    fun size(): Pair<Int, Int>
    val color: Boolean
}

/** The one small io object every screen is built from. */
interface Io {
    fun write(text: String)
    fun readLine(prompt: String): String?                          // null at end of input
    fun readLinePrefill(prompt: String, first: String): String?    // a typed line that starts with `first`
    val hasSelector: Boolean
    fun select(title: String, labels: List<String>, o: SelOpts): Outcome
}