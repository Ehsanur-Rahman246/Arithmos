package arithmos.cli

import java.io.BufferedReader
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.io.PrintStream
import java.lang.foreign.Arena
import java.lang.foreign.FunctionDescriptor
import java.lang.foreign.Linker
import java.lang.foreign.MemorySegment
import java.lang.foreign.SymbolLookup
import java.lang.foreign.ValueLayout
import java.lang.invoke.MethodHandle

/** Environment checks. */
object Term {
    val isWindows: Boolean = System.getProperty("os.name").lowercase().contains("win")
    fun plain() = System.getenv("ARITHMOS_PLAIN") == "1"
    fun dumb() = System.getenv("TERM") == "dumb"

    /** True when stdin AND stdout are a terminal. JDK 22+ adds Console.isTerminal(); older JDKs
     *  only return a Console when both are terminals, so a missing method means "yes". */
    fun isTerminal(): Boolean {
        val c = System.console() ?: return false
        return try {
            java.lang.Boolean.TRUE == java.io.Console::class.java.getMethod("isTerminal").invoke(c)
        } catch (e: NoSuchMethodException) { true } catch (e: Exception) { true }
    }
}

/** Runs `stty <args>` against /dev/tty and returns its output, or null on failure. */
fun stty(args: String): String? = try {
    val p = ProcessBuilder(listOf("stty") + args.split(" "))
        .redirectInput(ProcessBuilder.Redirect.from(File("/dev/tty")))
        .redirectErrorStream(true).start()
    val text = p.inputStream.readBytes().toString(Charsets.UTF_8).trim()
    if (p.waitFor() == 0) text else null
} catch (e: Exception) { null }

// ---------------------------------------------------------------- POSIX

/**
 * Java has no raw-mode API, so `stty` on /dev/tty does it: -icanon -echo -isig, blocking 1-byte
 * reads. The saved settings (`stty -g`) are restored in leave(), which is idempotent so a
 * shutdown hook can call it too. After a lone ESC byte we wait 25 ms: an arrow key arrives as
 * one chunk, so bytes still pending mean an escape sequence.
 */
class PosixKeys : KeySource {
    private var saved: String? = null
    private var tty: FileInputStream? = null
    private val queue = ArrayDeque<Key>()

    override fun enter() {
        saved = stty("-g") ?: throw IllegalStateException("stty failed")
        stty("-icanon -echo -isig min 1 time 0")
        tty = FileInputStream("/dev/tty")
    }

    override fun leave() {
        saved?.let { stty(it) }
        saved = null
        tty?.close()
        tty = null
        queue.clear()
    }

    override fun read(): Key? {
        while (queue.isEmpty()) {
            val inp = tty ?: return null
            val first = inp.read()
            if (first < 0) return null
            val buf = ByteArrayOutputStream()
            buf.write(first)
            if (first == 0x1b) Thread.sleep(25) else if (first >= 0xc0) Thread.sleep(2)
            while (inp.available() > 0 && buf.size() < 64) buf.write(inp.read())
            queue.addAll(parseKeys(buf.toByteArray()))
        }
        return queue.removeFirst()
    }
}

class PosixScreen(private val out: PrintStream, override val color: Boolean) : Screen {
    private var cached = Pair(80, 24)
    private var at = 0L
    override fun write(s: String) { out.print(s); out.flush() }

    /** (columns, rows) from `stty size`, cached for 150 ms. */
    override fun size(): Pair<Int, Int> {
        val now = System.currentTimeMillis()
        if (now - at > 150) {
            val p = stty("size")?.split(" ")?.mapNotNull { it.toIntOrNull() }
            cached = if (p != null && p.size == 2 && p[0] > 0 && p[1] > 0) Pair(p[1], p[0]) else Pair(80, 24)
            at = now
        }
        return cached
    }
}

// ---------------------------------------------------------------- Windows

/**
 * Windows console through the foreign-function API (JDK 22+): kernel32 for the console mode,
 * code page and window size, msvcrt `_getwch` for keys. No child processes. Run with
 * --enable-native-access=ALL-UNNAMED (JDK 24+ prints a warning without it).
 */
object Win {
    private val arena = Arena.ofAuto()
    private val linker = Linker.nativeLinker()
    private val I = ValueLayout.JAVA_INT
    private val P = ValueLayout.ADDRESS

    private fun fn(lib: String, name: String, d: FunctionDescriptor): MethodHandle =
        linker.downcallHandle(SymbolLookup.libraryLookup(lib, Arena.global()).find(name).orElseThrow(), d)

    private val getStdHandle by lazy { fn("kernel32", "GetStdHandle", FunctionDescriptor.of(P, I)) }
    private val getConsoleMode by lazy { fn("kernel32", "GetConsoleMode", FunctionDescriptor.of(I, P, P)) }
    private val setConsoleMode by lazy { fn("kernel32", "SetConsoleMode", FunctionDescriptor.of(I, P, I)) }
    private val getCp by lazy { fn("kernel32", "GetConsoleOutputCP", FunctionDescriptor.of(I)) }
    private val setCp by lazy { fn("kernel32", "SetConsoleOutputCP", FunctionDescriptor.of(I, I)) }
    private val getInfo by lazy { fn("kernel32", "GetConsoleScreenBufferInfo", FunctionDescriptor.of(I, P, P)) }
    private val getwch by lazy { fn("msvcrt", "_getwch", FunctionDescriptor.of(I)) }

    private fun call(h: MethodHandle, vararg a: Any): Any = h.invokeWithArguments(a.toList())
    private fun handle(n: Int): MemorySegment = call(getStdHandle, n) as MemorySegment

    private fun mode(h: MemorySegment): Int? {
        val buf = arena.allocate(4L, 4L)
        return if (call(getConsoleMode, h, buf) as Int != 0) buf.get(I, 0L) else null
    }

    private var savedIn: Int? = null
    private var savedOut: Int? = null
    private var savedCp: Int? = null

    /** True when the foreign calls work (JDK 22+ on Windows); otherwise numbered lists are used. */
    val available: Boolean by lazy {
        try { getStdHandle; getConsoleMode; setConsoleMode; getCp; setCp; getInfo; getwch; true } catch (e: Throwable) { false }
    }

    /** ANSI escapes (ENABLE_VIRTUAL_TERMINAL_PROCESSING = 4) and UTF-8 while the program runs. */
    fun prepare() {
        val out = handle(-11)
        savedOut = mode(out)
        savedOut?.let { call(setConsoleMode, out, it or 4) }
        savedCp = call(getCp) as Int
        call(setCp, 65001)
    }

    /** Raw input while a selector is on screen: clear ENABLE_PROCESSED_INPUT so Ctrl-C arrives as a key. */
    fun rawIn(on: Boolean) {
        val hin = handle(-10)
        if (on) {
            savedIn = mode(hin)
            savedIn?.let { call(setConsoleMode, hin, it and 1.inv()) }
        } else {
            savedIn?.let { call(setConsoleMode, hin, it) }
            savedIn = null
        }
    }

    /** Undoes everything; idempotent, so the shutdown hook can call it too. */
    fun restore() {
        try {
            rawIn(false)
            savedOut?.let { call(setConsoleMode, handle(-11), it) }
            savedCp?.let { call(setCp, it) }
        } catch (e: Throwable) { }
        savedOut = null
        savedCp = null
    }

    /** One UTF-16 unit from the keyboard, or null if the read fails (0xFFFF). */
    fun readWch(): Int? = (call(getwch) as Int).let { if (it == 0xFFFF) null else it }

    /** (columns, rows) of the visible window, from CONSOLE_SCREEN_BUFFER_INFO.srWindow. */
    fun size(): Pair<Int, Int> {
        val buf = arena.allocate(24L, 8L)
        if (call(getInfo, handle(-11), buf) as Int == 0) return Pair(80, 24)
        val s = ValueLayout.JAVA_SHORT_UNALIGNED
        val cols = buf.get(s, 14L) - buf.get(s, 10L) + 1
        val rows = buf.get(s, 16L) - buf.get(s, 12L) + 1
        return if (cols > 0 && rows > 0) Pair(cols, rows) else Pair(80, 24)
    }
}

class WinKeys : KeySource {
    override fun enter() { Win.rawIn(true) }
    override fun leave() { Win.rawIn(false) }
    override fun read(): Key? {
        val first = Win.readWch() ?: return null
        return winKey(first) { Win.readWch() ?: 0 }
    }
}

class WinScreen(private val out: PrintStream, override val color: Boolean) : Screen {
    override fun write(s: String) { out.print(s); out.flush() }
    override fun size(): Pair<Int, Int> = Win.size()
}

// ---------------------------------------------------------------- The real Io

/** stdin/stdout for real. Chooses the selector only on a real terminal (and not ARITHMOS_PLAIN=1). */
class ConsoleIo : Io {
    val out = PrintStream(FileOutputStream(FileDescriptor.out), false, "UTF-8")
    private val inp = BufferedReader(InputStreamReader(System.`in`, Charsets.UTF_8))
    private val tty = Term.isTerminal()
    private var keys: KeySource? = null
    private var screen: Screen? = null
    private var broken = false                         // the selector failed once: use numbered lists from now on

    init {
        val color = System.getenv("NO_COLOR") == null
        if (tty && Term.isWindows && Win.available) Win.prepare()
        if (tty && !Term.plain() && !Term.dumb()) {
            if (Term.isWindows) {
                if (Win.available) { keys = WinKeys(); screen = WinScreen(out, color) }
            } else if (stty("-g") != null) {
                keys = PosixKeys()
                screen = PosixScreen(out, color)
            }
        }
        // Ctrl-C, SIGTERM, SIGHUP: never leave the terminal raw or the cursor hidden.
        Runtime.getRuntime().addShutdownHook(Thread {
            try { keys?.leave() } catch (e: Exception) { }
            if (keys != null) { out.print(Selector.SHOW); out.flush() }
            if (Term.isWindows && Win.available) Win.restore()
        })
    }

    override fun write(text: String) { out.print(text); out.flush() }

    override fun readLine(prompt: String): String? {
        write(prompt)
        val line = inp.readLine()
        if (line == null && tty) write("\n")           // end of input: leave the prompt line cleanly
        return line
    }

    override fun readLinePrefill(prompt: String, first: String): String? {
        write(prompt + first)                           // the key that started the line is already on screen
        val rest = inp.readLine() ?: return null
        return first + rest
    }

    override val hasSelector: Boolean get() = keys != null && !broken

    override fun select(title: String, labels: List<String>, o: SelOpts): Outcome =
        try {
            Selector.run(keys!!, screen!!, title, labels, o)
        } catch (e: Exception) {
            broken = true                               // pick() will show the numbered list instead
            write(Selector.SHOW)
            Typed("")
        }
}