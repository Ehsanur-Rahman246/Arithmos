package arithmos.test

import arithmos.cli.*

/** Tiny test harness: counts passes, prints failures, exit status 1 on any failure. */
object H {
    var pass = 0
    var failed = 0
    fun check(name: String, ok: Boolean, detail: () -> String = { "" }) {
        if (ok) pass++ else { failed++; println("FAIL $name ${detail()}") }
    }
    fun eq(name: String, expected: Any?, actual: Any?) = check(name, expected == actual) { "expected <$expected> got <$actual>" }
    fun summary(): Int { println("$pass passed, $failed failed"); return if (failed == 0) 0 else 1 }
}

/** A scripted keyboard; counts enter()/leave() so tests can check raw mode is balanced. */
class FakeKeys(keys: List<Key>) : KeySource {
    private val q = ArrayDeque(keys)
    var entered = 0
    var left = 0
    override fun enter() { entered++ }
    override fun leave() { left++ }
    override fun read(): Key? = if (q.isEmpty()) null else q.removeFirst()
}

/** A screen that records everything written to it. */
class FakeScreen(val cols: Int = 80, val rows: Int = 24, override val color: Boolean = false) : Screen {
    val out = StringBuilder()
    override fun write(s: String) { out.append(s) }
    override fun size() = Pair(cols, rows)
}

/** A scripted Io: `selects` are the selector's answers, `lines` the typed lines. */
class FakeIo(private val selector: Boolean, val selects: MutableList<Outcome> = mutableListOf(),
             val lines: MutableList<String> = mutableListOf()) : Io {
    val out = StringBuilder()
    var readLines = 0
    var prefills = 0
    var selectCalls = 0
    override fun write(text: String) { out.append(text) }
    override fun readLine(prompt: String): String? { readLines++; return if (lines.isEmpty()) null else lines.removeAt(0) }
    override fun readLinePrefill(prompt: String, first: String): String? { prefills++; return if (lines.isEmpty()) null else lines.removeAt(0) }
    override val hasSelector: Boolean get() = selector
    override fun select(title: String, labels: List<String>, o: SelOpts): Outcome { selectCalls++; return selects.removeAt(0) }
}