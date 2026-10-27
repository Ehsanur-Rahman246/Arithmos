package arithmos.test

import arithmos.cli.*
import kotlin.system.exitProcess

private val ALL = SelOpts(back = true, quit = true, typing = true)
private val NONE = SelOpts(back = false, quit = false, typing = false)
private fun key(k: KeyKind) = Key(k)
private fun chr(s: String) = Key(KeyKind.CHAR, s)
private fun bytes(vararg v: Int) = ByteArray(v.size) { v[it].toByte() }

/** Selector tests SL1-SL21 (docs/test-cases.md) plus X2 (widths, window, erase) and X3 (raw keys). */
fun main() {
    val abc = listOf("a", "b", "c")
    val opts = listOf(Option("length"), Option("mass"), Option("area"))

    // SL1 up/down move, wrap around, home/end
    H.eq("SL1 up wraps", Move(2), Selector.step(0, 3, key(KeyKind.UP), ALL))
    H.eq("SL1 down wraps", Move(0), Selector.step(2, 3, key(KeyKind.DOWN), ALL))
    H.eq("SL1 home", Move(0), Selector.step(2, 3, key(KeyKind.HOME), ALL))
    H.eq("SL1 end", Move(2), Selector.step(0, 3, key(KeyKind.END), ALL))

    // SL2 long lists scroll in a window of 10
    val many = (0 until 15).map { "item $it" }
    H.eq("SL2 window", 10, Selector.windowSize(15, 24))
    val top = Selector.fit(0, 12, 10, 15)
    val shown = Selector.render("T", many, 12, top, 10, ALL, 80, false)
    H.eq("SL2 line count", 12, shown.size)
    H.check("SL2 selected visible", shown.contains("❯ item 12"))
    H.check("SL2 scrolled", shown.none { it.endsWith("item 0") })

    // SL3 Enter selects; Esc / b / q only work when offered
    H.eq("SL3 enter", Chosen(1), Selector.step(1, 3, key(KeyKind.ENTER), NONE))
    H.eq("SL3 esc off", Ignore, Selector.step(0, 3, key(KeyKind.ESC), NONE))
    H.eq("SL3 esc on", GoBack, Selector.step(0, 3, key(KeyKind.ESC), SelOpts(true, false, false)))
    H.eq("SL3 b off", Ignore, Selector.step(0, 3, chr("b"), NONE))
    H.eq("SL3 q on", GoQuit, Selector.step(0, 3, chr("q"), SelOpts(false, true, false)))

    // SL4 Ctrl-C / Ctrl-D abort; other control keys are ignored
    H.eq("SL4 ctrl-c", EndOfInput, Selector.step(0, 3, key(KeyKind.CTRL_C), NONE))
    H.eq("SL4 ctrl-d", EndOfInput, Selector.step(0, 3, key(KeyKind.CTRL_D), ALL))
    H.eq("SL4 other", Ignore, Selector.step(0, 3, key(KeyKind.OTHER), ALL))

    // SL5 typing on: a printable key ends the selector and carries the character
    H.eq("SL5", Typed("x"), Selector.step(0, 3, chr("x"), ALL))
    // SL6 typing off: printable keys are ignored
    H.eq("SL6", Ignore, Selector.step(0, 3, chr("x"), NONE))
    // SL7 typing on: Esc, b, q, arrows and Enter keep their meaning
    H.eq("SL7 esc", GoBack, Selector.step(0, 3, key(KeyKind.ESC), ALL))
    H.eq("SL7 b", GoBack, Selector.step(0, 3, chr("b"), ALL))
    H.eq("SL7 q", GoQuit, Selector.step(0, 3, chr("q"), ALL))
    H.eq("SL7 up", Move(2), Selector.step(0, 3, key(KeyKind.UP), ALL))
    H.eq("SL7 enter", Chosen(0), Selector.step(0, 3, key(KeyKind.ENTER), ALL))
    // SL8 typing on: space and control keys do not start a typed line
    H.eq("SL8 space", Ignore, Selector.step(0, 3, chr(" "), ALL))
    H.eq("SL8 control", Ignore, Selector.step(0, 3, key(KeyKind.OTHER), ALL))

    // SL9 the selected row is a full reverse-video bar (colour on)
    val bar = Selector.render("T", abc, 0, 0, 3, ALL, 40, true)
    H.check("SL9 bar", bar[1].startsWith("\u001b[7m") && bar[1].endsWith("\u001b[0m"))
    H.check("SL9 others plain", !bar[2].contains("\u001b"))
    // SL10 plain mode still marks the selected row with the pointer
    val plain = Selector.render("T", abc, 1, 0, 3, ALL, 40, false)
    H.check("SL10", plain[2].startsWith("❯ ") && !plain[2].contains("\u001b") && plain[1].startsWith("  "))

    // SL11 the hint lists only the keys on offer
    val h0 = Selector.hint(NONE)
    H.check("SL11", h0.contains("Enter") && !h0.contains("back") && !h0.contains("quit") && !h0.contains("type"))
    // SL12 the hint shows Esc/b back and "or type" when typing is on
    val h1 = Selector.hint(ALL)
    H.check("SL12", h1.contains("Esc/b back") && h1.contains("or type") && h1.contains("q quit"))

    // SL13 loop: keys in, index out, summary left behind, cursor restored
    run {
        val k = FakeKeys(listOf(key(KeyKind.DOWN), key(KeyKind.ENTER)))
        val s = FakeScreen()
        H.eq("SL13 result", Chosen(1), Selector.run(k, s, "T", abc, ALL))
        H.check("SL13 summary", s.out.contains("✔ T: b"))
        H.check("SL13 cursor", s.out.endsWith(Selector.SHOW))
        H.eq("SL13 raw balanced", Pair(1, 1), Pair(k.entered, k.left))
    }
    // SL14 loop: Esc, ignored keys, Ctrl-C
    H.eq("SL14 esc", GoBack, Selector.run(FakeKeys(listOf(key(KeyKind.OTHER), key(KeyKind.ESC))), FakeScreen(), "T", abc, ALL))
    H.eq("SL14 ctrl-c", EndOfInput, Selector.run(FakeKeys(listOf(key(KeyKind.CTRL_C))), FakeScreen(), "T", abc, ALL))
    // SL15 loop: a typed key returns its character and restores the cursor
    run {
        val k = FakeKeys(listOf(chr("x")))
        val s = FakeScreen()
        H.eq("SL15 typed", Typed("x"), Selector.run(k, s, "T", abc, ALL))
        H.check("SL15 cursor", s.out.endsWith(Selector.SHOW) && k.left == 1)
    }

    // SL16 pick() uses the selector when present and maps its results
    fun pickWith(sel: Outcome, exit: String? = null): Outcome {
        val io = FakeIo(true); io.selects.add(sel)
        return pick(io, "T", opts, back = true, exitLabel = exit)
    }
    H.eq("SL16 chosen", Chosen(1), pickWith(Chosen(1)))
    H.eq("SL16 back", GoBack, pickWith(GoBack))
    H.eq("SL16 quit", GoQuit, pickWith(GoQuit))
    H.eq("SL16 eof", EndOfInput, pickWith(EndOfInput))
    H.eq("SL16 exit row", GoQuit, pickWith(Chosen(3), "Exit"))

    // SL17 pick(): a typed name or number selects it
    run {
        val io = FakeIo(true, lines = mutableListOf("mass")); io.selects.add(Typed("m"))
        H.eq("SL17 name", Chosen(1), pick(io, "T", opts, back = true))
        val io2 = FakeIo(true, lines = mutableListOf("3")); io2.selects.add(Typed("3"))
        H.eq("SL17 number", Chosen(2), pick(io2, "T", opts, back = true))
    }
    // SL18 pick(): a typed one-line command runs and the list comes back
    run {
        val seen = mutableListOf<String>()
        val io = FakeIo(true, lines = mutableListOf("100 cm in")); io.selects.add(Typed("1")); io.selects.add(Chosen(0))
        val r = pick(io, "T", opts, back = true, onLine = { seen.add(it); true })
        H.eq("SL18 result", Chosen(0), r)
        H.eq("SL18 command", listOf("100 cm in"), seen)
        H.eq("SL18 list again", 2, io.selectCalls)
    }
    // SL19 pick(): an unknown typed word is an error and the list comes back
    run {
        val io = FakeIo(true, lines = mutableListOf("foo")); io.selects.add(Typed("f")); io.selects.add(Chosen(2))
        H.eq("SL19 result", Chosen(2), pick(io, "T", opts, back = true))
        H.check("SL19 error", io.out.contains("Error [UNKNOWN_COMMAND]"))
    }
    // SL20 pick(): b, q and Esc act at once, with no prompt line
    run {
        val io = FakeIo(true); io.selects.add(GoBack)
        H.eq("SL20 result", GoBack, pick(io, "T", opts, back = true))
        H.eq("SL20 no prompt", Pair(0, 0), Pair(io.readLines, io.prefills))
    }
    // SL21 pick(): without a selector (pipes) the numbered list works as before
    run {
        val io = FakeIo(false, lines = mutableListOf("2"))
        H.eq("SL21 number", Chosen(1), pick(io, "T", opts, back = true))
        H.check("SL21 rows", io.out.contains("  1) length") && io.out.contains("  2) mass"))
        val io2 = FakeIo(false, lines = mutableListOf("zzz", "back"))
        H.eq("SL21 back", GoBack, pick(io2, "T", opts, back = true))
        H.check("SL21 error", io2.out.contains("Error [UNKNOWN_COMMAND]"))
        H.eq("SL21 eof", EndOfInput, pick(FakeIo(false), "T", opts, back = true))
    }

    // X2 lines never wider than the terminal; the window shrinks on a short terminal; erase moves up by the line count
    val narrow = Selector.render("A very long title that does not fit", listOf("x".repeat(50), "b"), 0, 0, 2, ALL, 20, false)
    H.check("X2 width", narrow.all { it.length <= 19 })
    H.eq("X2 short terminal", 5, Selector.windowSize(30, 8))
    H.check("X2 height", Selector.render("T", many, 0, 0, 5, ALL, 80, false).size <= 7)
    run {
        val s = FakeScreen()
        Selector.run(FakeKeys(listOf(key(KeyKind.ENTER))), s, "T", abc, ALL)
        H.check("X2 erase", s.out.contains("\u001b[5A"))          // title + 3 rows + hint = 5 lines
    }

    // X3 raw terminal bytes become keys (POSIX) and ReadKey lines become keys (Windows)
    H.eq("X3 up", listOf(key(KeyKind.UP)), parseKeys(bytes(0x1b, '['.code, 'A'.code)))
    H.eq("X3 down", listOf(key(KeyKind.DOWN)), parseKeys(bytes(0x1b, '['.code, 'B'.code)))
    H.eq("X3 lone esc", listOf(key(KeyKind.ESC)), parseKeys(bytes(0x1b)))
    H.eq("X3 home/end", listOf(key(KeyKind.HOME), key(KeyKind.END)), parseKeys(bytes(0x1b, '['.code, 'H'.code, 0x1b, '['.code, 'F'.code)))
    H.eq("X3 pgup/pgdn", listOf(key(KeyKind.PGUP), key(KeyKind.PGDN)),
        parseKeys(bytes(0x1b, '['.code, '5'.code, '~'.code, 0x1b, '['.code, '6'.code, '~'.code)))
    H.eq("X3 ctrl", listOf(key(KeyKind.CTRL_C), key(KeyKind.CTRL_D)), parseKeys(bytes(3, 4)))
    H.eq("X3 enter", listOf(key(KeyKind.ENTER)), parseKeys(bytes(0x0d)))
    H.eq("X3 utf-8", listOf(chr("é")), parseKeys(bytes(0xc3, 0xa9)))
    H.eq("X3 win up", key(KeyKind.UP), winKey(0xE0) { 72 })
    H.eq("X3 win ctrl-c", key(KeyKind.CTRL_C), winKey(3) { 0 })
    H.eq("X3 win char", chr("a"), winKey(97) { 0 })
    H.eq("X3 win enter/esc", listOf(key(KeyKind.ENTER), key(KeyKind.ESC)), listOf(winKey(13) { 0 }, winKey(27) { 0 }))

    exitProcess(H.summary())
}