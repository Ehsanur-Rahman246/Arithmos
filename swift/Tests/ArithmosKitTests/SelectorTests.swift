import XCTest
@testable import ArithmosKit

/// Selector tests SL1–SL21 (docs/test-cases.md) plus X2 and X3.
final class SelectorTests: XCTestCase {

    private func opts(_ labels: [String], back: Bool = true, quit: Bool = true,
                      typing: Bool = false) -> SelectorOptions {
        SelectorOptions(title: "Title", labels: labels, allowBack: back, allowQuit: quit, typing: typing)
    }
    private func press(_ k: Key, _ s: inout SelectorState, _ o: SelectorOptions, window: Int = 10) -> SelectorOutcome? {
        handleKey(k, &s, o, window: window)
    }
    private let pickSpec = PickSpec(title: "Pick", options: [
        PickOption(label: "alpha", aliases: ["a1"]), PickOption(label: "beta", aliases: [])],
        allowBack: true)

    // SL1 — up/down move, wrap around, home/end
    func testSL1() {
        let o = opts(["a", "b", "c"]); var s = SelectorState()
        _ = press(.up, &s, o, window: 3);   XCTAssertEqual(s.index, 2)
        _ = press(.down, &s, o, window: 3); XCTAssertEqual(s.index, 0)
        _ = press(.end, &s, o, window: 3);  XCTAssertEqual(s.index, 2)
        _ = press(.home, &s, o, window: 3); XCTAssertEqual(s.index, 0)
    }

    // SL2 — long lists scroll in a window of 10
    func testSL2() {
        let o = opts((0..<25).map { "item \($0)" }); var s = SelectorState()
        XCTAssertEqual(windowSize(count: 25, rows: 40), 10)
        for _ in 0..<10 { _ = press(.down, &s, o) }
        XCTAssertEqual(s.index, 10); XCTAssertEqual(s.top, 1)
        s = SelectorState(); _ = press(.up, &s, o)
        XCTAssertEqual(s.index, 24); XCTAssertEqual(s.top, 15)
        _ = press(.pageUp, &s, o); XCTAssertEqual(s.index, 14)
        _ = press(.pageDown, &s, o); XCTAssertEqual(s.index, 24)
    }

    // SL3 — Enter selects; Esc / b / q only work when offered
    func testSL3() {
        var s = SelectorState(); s.index = 1
        XCTAssertEqual(press(.enter, &s, opts(["a", "b"])), .chosen(1))
        let off = opts(["a", "b"], back: false, quit: false)
        XCTAssertNil(press(.esc, &s, off)); XCTAssertNil(press(.char("b"), &s, off)); XCTAssertNil(press(.char("q"), &s, off))
        let on = opts(["a", "b"])
        XCTAssertEqual(press(.esc, &s, on), .goBack); XCTAssertEqual(press(.char("b"), &s, on), .goBack)
        XCTAssertEqual(press(.char("q"), &s, on), .goQuit)
    }

    // SL4 — Ctrl-C / Ctrl-D abort; other control keys are ignored
    func testSL4() {
        var s = SelectorState(); let o = opts(["a", "b"], typing: true)
        XCTAssertEqual(press(.ctrlC, &s, o), .endOfInput); XCTAssertEqual(press(.ctrlD, &s, o), .endOfInput)
        XCTAssertNil(press(.other, &s, o)); XCTAssertNil(press(.backspace, &s, o))
    }

    // SL5 — typing on: a printable key ends the selector and carries the character
    func testSL5() {
        var s = SelectorState()
        XCTAssertEqual(press(.char("x"), &s, opts(["a"], typing: true)), .typed("x"))
        XCTAssertEqual(press(.char("5"), &s, opts(["a"], typing: true)), .typed("5"))
    }

    // SL6 — typing off: printable keys are ignored
    func testSL6() {
        var s = SelectorState()
        XCTAssertNil(press(.char("x"), &s, opts(["a"], typing: false)))
    }

    // SL7 — typing on: Esc, b, q, arrows and Enter keep their meaning
    func testSL7() {
        var s = SelectorState(); let o = opts(["a", "b"], typing: true)
        XCTAssertEqual(press(.esc, &s, o), .goBack); XCTAssertEqual(press(.char("b"), &s, o), .goBack)
        XCTAssertEqual(press(.char("q"), &s, o), .goQuit)
        XCTAssertNil(press(.down, &s, o)); XCTAssertEqual(s.index, 1)
        XCTAssertEqual(press(.enter, &s, o), .chosen(1))
    }

    // SL8 — typing on: space and control keys do not start a typed line
    func testSL8() {
        var s = SelectorState(); let o = opts(["a"], typing: true)
        XCTAssertNil(press(.char(" "), &s, o)); XCTAssertNil(press(.other, &s, o))
    }

    // SL9 — the selected row is highlighted as a full bar
    func testSL9() {
        let lines = renderSelector(opts(["one", "two"]), SelectorState(), window: 2, cols: 20, color: true)
        XCTAssertTrue(lines[1].contains("\u{1B}[7m"))
        XCTAssertEqual(stripAnsi(lines[1]).count, 19)          // padded to width - 1
        XCTAssertFalse(lines[2].contains("\u{1B}[7m"))
    }

    // SL10 — plain mode still marks the selected row with the pointer
    func testSL10() {
        let lines = renderSelector(opts(["one", "two"]), SelectorState(), window: 2, cols: 40, color: false)
        XCTAssertTrue(lines[1].hasPrefix("❯ one")); XCTAssertTrue(lines[2].hasPrefix("  two"))
    }

    // SL11 — hint line lists only the keys on offer
    func testSL11() {
        let h = hintText(opts(["a"], back: false, quit: false, typing: false))
        XCTAssertFalse(h.contains("Esc")); XCTAssertFalse(h.contains("quit")); XCTAssertFalse(h.contains("type"))
        XCTAssertTrue(h.contains("Enter"))
    }

    // SL12 — hint shows Esc/b back and "or type" when typing is on
    func testSL12() {
        let h = hintText(opts(["a"], typing: true))
        XCTAssertTrue(h.contains("Esc/b back")); XCTAssertTrue(h.contains("or type")); XCTAssertTrue(h.contains("q quit"))
    }

    // SL13 — loop: keys in, index out, summary left behind, cursor restored
    func testSL13() {
        let keys = FakeKeys([.down, .enter]); let screen = FakeScreen()
        XCTAssertEqual(runSelector(opts(["a", "b", "c"]), keys: keys, screen: screen), .chosen(1))
        XCTAssertTrue(screen.text.contains("✔ Title: b"))
        XCTAssertTrue(screen.text.hasSuffix("\u{1B}[?25h"))
        XCTAssertEqual(keys.enters, 1); XCTAssertEqual(keys.leaves, 1)
    }

    // SL14 — loop: Esc, ignored keys, Ctrl-C
    func testSL14() {
        XCTAssertEqual(runSelector(opts(["a"]), keys: FakeKeys([.other, .esc]), screen: FakeScreen()), .goBack)
        let k = FakeKeys([.ctrlC])
        XCTAssertEqual(runSelector(opts(["a"]), keys: k, screen: FakeScreen()), .endOfInput)
        XCTAssertEqual(k.leaves, 1)
    }

    // SL15 — loop: a typed key returns its character and restores the cursor
    func testSL15() {
        let screen = FakeScreen(); let keys = FakeKeys([.char("x")])
        XCTAssertEqual(runSelector(opts(["a"], typing: true), keys: keys, screen: screen), .typed("x"))
        XCTAssertTrue(screen.text.hasSuffix("\u{1B}[?25h")); XCTAssertEqual(keys.leaves, 1)
    }

    // SL16 — pick() uses the selector when present and maps its results
    func testSL16() {
        func result(_ r: SelectorOutcome) -> PickResult { pick(FakeIo(selector: true, selectResults: [r]), pickSpec) }
        XCTAssertEqual(result(.chosen(1)), .chosen(1)); XCTAssertEqual(result(.goBack), .back)
        XCTAssertEqual(result(.goQuit), .quit); XCTAssertEqual(result(.endOfInput), .eof)
    }

    // SL17 — pick(): a typed name or number selects it
    func testSL17() {
        let byName = FakeIo(lines: ["alpha"], selector: true, selectResults: [.typed("a")])
        XCTAssertEqual(pick(byName, pickSpec), .chosen(0))
        let byAlias = FakeIo(lines: ["A1"], selector: true, selectResults: [.typed("A")])
        XCTAssertEqual(pick(byAlias, pickSpec), .chosen(0))
        let byNumber = FakeIo(lines: ["2"], selector: true, selectResults: [.typed("2")])
        XCTAssertEqual(pick(byNumber, pickSpec), .chosen(1))
    }

    // SL18 — pick(): a typed one-line command runs and the list comes back
    func testSL18() {
        var ran: [String] = []
        var spec = pickSpec
        spec.command = { ran.append($0); return true }
        let io = FakeIo(lines: ["100 cm in"], selector: true, selectResults: [.typed("1"), .goBack])
        XCTAssertEqual(pick(io, spec), .back)
        XCTAssertEqual(ran, ["100 cm in"]); XCTAssertEqual(io.selectCalls, 2)
    }

    // SL19 — pick(): an unknown typed word is an error and the list comes back
    func testSL19() {
        let io = FakeIo(lines: ["zzz"], selector: true, selectResults: [.typed("z"), .goQuit])
        XCTAssertEqual(pick(io, pickSpec), .quit)
        XCTAssertTrue(io.out.contains("UNKNOWN_COMMAND")); XCTAssertEqual(io.selectCalls, 2)
    }

    // SL20 — pick(): b, q and Esc act at once, with no prompt line
    func testSL20() {
        for r in [SelectorOutcome.goBack, .goQuit] {
            let io = FakeIo(selector: true, selectResults: [r])
            _ = pick(io, pickSpec)
            XCTAssertEqual(io.readCalls, 0)
        }
        let keys = FakeKeys([.char("b")])                       // and through the real loop
        XCTAssertEqual(runSelector(opts(["a"], typing: true), keys: keys, screen: FakeScreen()), .goBack)
    }

    // SL21 — pick(): without a selector (pipes) the numbered list works as before
    func testSL21() {
        let io = FakeIo(lines: ["2"], selector: false)
        XCTAssertEqual(pick(io, pickSpec), .chosen(1))
        XCTAssertTrue(io.out.contains("  1) alpha")); XCTAssertTrue(io.out.contains("  2) beta"))
        XCTAssertEqual(pick(FakeIo(lines: ["back"]), pickSpec), .back)
        XCTAssertEqual(pick(FakeIo(lines: []), pickSpec), .eof)
        XCTAssertEqual(pick(FakeIo(lines: ["b"], selector: false), pickSpec), .eof)   // "b" is not a word here
    }

    // X2 — lines never wider than the terminal; window shrinks on a short terminal;
    //      erase moves up by the drawn line count
    func testX2() {
        let labels = (1...30).map { "item number \($0) with a rather long label text" }
        let o = opts(labels)
        let lines = renderSelector(o, SelectorState(), window: windowSize(count: 30, rows: 8), cols: 20, color: true)
        XCTAssertTrue(lines.allSatisfy { stripAnsi($0).count <= 19 })
        XCTAssertEqual(windowSize(count: 30, rows: 8), 5)
        XCTAssertEqual(lines.count, 7)                           // title + 5 rows + hint
        let screen = FakeScreen(cols: 20, rows: 8, color: true)
        _ = runSelector(o, keys: FakeKeys([.enter]), screen: screen)
        XCTAssertTrue(screen.text.contains("\u{1B}[7A"))
    }

    // X3 — raw terminal bytes become keys
    func testX3() {
        XCTAssertEqual(parseKeys([0x1B, 0x5B, 0x41]), [.up])
        XCTAssertEqual(parseKeys([0x1B, 0x5B, 0x42]), [.down])
        XCTAssertEqual(parseKeys([0x1B, 0x4F, 0x41]), [.up])
        XCTAssertEqual(parseKeys([0x1B, 0x5B, 0x48, 0x1B, 0x5B, 0x46]), [.home, .end])
        XCTAssertEqual(parseKeys([0x1B, 0x5B, 0x35, 0x7E, 0x1B, 0x5B, 0x36, 0x7E]), [.pageUp, .pageDown])
        XCTAssertEqual(parseKeys([0x1B]), [.esc])
        XCTAssertEqual(parseKeys([0x03, 0x04, 0x0D]), [.ctrlC, .ctrlD, .enter])
        XCTAssertEqual(parseKeys([0xC3, 0xA9]), [.char("é")])
        XCTAssertEqual(parseKeys(Array("x ".utf8)), [.char("x"), .char(" ")])
    }
}