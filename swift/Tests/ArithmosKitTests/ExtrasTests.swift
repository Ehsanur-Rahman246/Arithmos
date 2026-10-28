import XCTest

@testable import ArithmosKit

/// Swift extras: formatting boundaries, settled amendments, garbage input,
/// one-shot exit codes, scripted sessions.
final class ExtrasTests: XCTestCase {

    private func std(_ s: String) throws -> String { try StandardCalculator().calculate(s) }
    private func dec(_ p: ProgrammerCalculator, _ s: String) throws -> Int64 {
        guard case .value(let v) = try p.run(s) else {
            XCTFail("not a value: \(s)")
            return 0
        }
        return v
    }

    // MARK: Formatting boundaries (spec §2.3, R10)
    func testFormatting() throws {
        XCTAssertEqual(try formatNumber(100000000000.5), "100000000001")  // half away from zero
        XCTAssertEqual(try formatNumber(999999999999.5), "1000000000000")  // carry out of the top
        XCTAssertEqual(try formatNumber(0.000001), "0.000001")  // 1e-6 is plain
        XCTAssertEqual(try formatNumber(0.0000001), "1e-7")
        XCTAssertEqual(try formatNumber(1e15), "1e+15")  // 1e15 is scientific
        XCTAssertEqual(try formatNumber(123_456_789_012_345), "123456789012000")
        XCTAssertEqual(try formatNumber(-0.0), "0")
        XCTAssertEqual(try formatNumber(-2.5), "-2.5")
        XCTAssertEqual(try formatNumber(0.5), "0.5")
        XCTAssertEqual(try formatNumber(9.46073047258e27), "9.46073047258e+27")
        XCTAssertEqual(errorCode { _ = try formatNumber(.infinity) }, "OVERFLOW")
        XCTAssertEqual(errorCode { _ = try formatNumber(.nan) }, "INVALID_EXPRESSION")
    }

    // MARK: Settled amendments R1–R20, R29–R30
    func testStandardAmendments() throws {
        XCTAssertEqual(try std("200 + (10%)"), "200.1")  // R1
        XCTAssertEqual(try std("200 + 5 * 10%"), "200.5")  // R2
        XCTAssertEqual(try std("2^50%"), "1.41421356237")  // R3
        XCTAssertEqual(try std("50%%"), "0.005")  // R4
        XCTAssertEqual(try std("5 of 10"), "50")  // R5
        XCTAssertEqual(try std("10^-400"), "0")  // R9
        let c = StandardCalculator()
        _ = try c.calculate("4")
        XCTAssertEqual(try c.calculate("ANS + 1"), "5")  // R6
        for bad in ["1e5", ".", "5.5.5", "2 3", "sqrt 4", "of 5", "()", "$", "", "   "] {
            XCTAssertEqual(errorCode { _ = try self.std(bad) }, "INVALID_EXPRESSION", bad)
        }
        XCTAssertEqual(errorCode { _ = try self.std("(-8)^(1/3)") }, "DOMAIN_ERROR")
        // Deep nesting needs the big stack the real program runs on (arithmosRun).
        let deep = String(repeating: "(", count: 500) + "1" + String(repeating: ")", count: 500)
        XCTAssertEqual(onBigStack { try? StandardCalculator().calculate(deep) }, "1")
    }

    func testProgrammerAmendments() throws {
        let p = ProgrammerCalculator()
        XCTAssertEqual(try dec(p, "NOT 0xFF"), -256)  // R12
        XCTAssertEqual(try dec(p, "NOT -1"), 0)
        XCTAssertEqual(errorCode { _ = try p.run("1 << 0x3") }, "INVALID_SHIFT")  // R13
        XCTAssertEqual(errorCode { _ = try p.run("1 << 2.5") }, "INVALID_SHIFT")
        XCTAssertEqual(try dec(p, "-0x80"), -128)  // R14
        XCTAssertEqual(try dec(p, "1<<3"), 8)  // R29
        XCTAssertEqual(try dec(p, "-8>>>1"), 9_223_372_036_854_775_804)
        XCTAssertEqual(errorCode { _ = try p.run("0x") }, "INVALID_DIGIT")  // R30
        guard case .converted(let s) = try p.run("convert FFFFFFFFFFFFFFFF hex dec") else {
            return XCTFail()
        }
        XCTAssertEqual(s, "-1")  // R15
        _ = try p.run("base hex")
        XCTAssertEqual(try dec(p, "A AND F"), 10)  // R11
        XCTAssertEqual(try dec(p, "DEC"), 3564)
        XCTAssertEqual(try dec(p, "0B"), 11)  // R30
        guard case .baseSet(let b) = try p.run("BASE Dec") else { return XCTFail() }
        XCTAssertEqual(b.rawValue, "dec")  // R32
    }

    func testConverterAmendments() throws {
        let c = ArithmosConverter()
        XCTAssertEqual(errorCode { _ = try c.run("convert 1e3 m cm") }, "INVALID_NUMBER")  // R16
        XCTAssertEqual(errorCode { _ = try c.run("list foo") }, "UNKNOWN_COMMAND")  // R19
        XCTAssertEqual(errorCode { _ = try c.run("convert 1 m") }, "UNKNOWN_COMMAND")
        XCTAssertEqual(
            errorCode { _ = try c.run("convert " + String(repeating: "9", count: 400) + " m cm") },
            "OVERFLOW")
        XCTAssertEqual(errorCode { _ = try c.run("convert 1e300 ly all") }, "INVALID_NUMBER")
        XCTAssertEqual(errorCode { _ = try c.run("convert " + String(repeating: "9", count: 300) + " ly pm") }, "OVERFLOW")
        // R20: exactly at absolute zero is allowed and lists all three
        for line in ["convert 0 k all", "convert -273.15 c all", "convert -459.67 f all"] {
            XCTAssertEqual(try c.run(line).count, 3, line)
        }
        XCTAssertEqual(errorCode { _ = try c.run("convert -0.01 k all") }, "BELOW_ABSOLUTE_ZERO")
        XCTAssertEqual(
            try c.run("list").first,
            "length, mass, area, volume, time, speed, digital, energy, power, pressure, angle, temperature"
        )
        XCTAssertEqual(
            try c.run("list pressure").first,
            "pa, hpa, kpa, mpa, mbar, bar, atm, psi, mmhg, inhg, torr")
    }

    // MARK: Garbage input must never crash (release goal 4)
    func testGarbageInput() {
        let junk = [
            "", " ", "\t", "((((", "))))", "%%%", "^^", "1 +* 2", "é", "🙂", "\u{0}",
            "99999999999999999999999999", "-", "--5", "0x", "0b", "base", "convert", "list a b c",
            "<<", ">>>", "1 << ", "NOT", "AND", "1 AND", "ans ans", "sqrt()", "abs(",
            String(repeating: "9", count: 5000),
        ]
        let std = StandardCalculator()
        let prog = ProgrammerCalculator()
        let conv = ArithmosConverter()
        for j in junk {
            XCTAssertNotEqual(errorCode { _ = try std.calculate(j) }, "OTHER", j)
            XCTAssertNotEqual(errorCode { _ = try prog.run(j) }, "OTHER", j)
            XCTAssertNotEqual(errorCode { _ = try conv.run(j) }, "OTHER", j)
        }
    }

    // MARK: One-shot exit codes (R21, R31)
    func testOneShot() {
        var io = FakeIo()
        XCTAssertEqual(runOneShot(["std", "20% of 150"], io), 0)
        XCTAssertEqual(io.out, "30\n")
        io = FakeIo()
        XCTAssertEqual(runOneShot(["STANDARD", "10 / 0"], io), 1)  // command word is case-insensitive
        XCTAssertTrue(io.err.contains("Error [DIV_BY_ZERO]"))
        XCTAssertEqual(io.out, "")
        io = FakeIo()
        XCTAssertEqual(runOneShot(["prog", "0xFF", "AND", "0x0F"], io), 0)
        XCTAssertTrue(io.out.contains("DEC: 15"))
        io = FakeIo()
        XCTAssertEqual(runOneShot(["convert", "100", "cm", "in"], io), 0)
        XCTAssertEqual(io.out, "39.3700787402\n")
        io = FakeIo()
        XCTAssertEqual(runOneShot(["list", "length"], io), 0)
        io = FakeIo()
        XCTAssertEqual(runOneShot(["nonsense"], io), 2)
        XCTAssertTrue(io.err.contains("Usage"))
        io = FakeIo()
        XCTAssertEqual(runOneShot(["std"], io), 2)
        io = FakeIo()
        XCTAssertEqual(runOneShot(["--help"], io), 0)
        XCTAssertTrue(io.out.contains("Usage"))
    }

    // MARK: Scripted sessions (numbered lists, as in pipes)
    func testScriptedStandardSession() {
        let io = FakeIo(lines: ["1", "5 + 5", "ans * 2", "10 / 0", "ans", "", "help", "back", "0"])
        XCTAssertEqual(runInteractive(io), 0)
        XCTAssertTrue(io.out.contains("10\n"))
        XCTAssertTrue(io.out.contains("20\n"))
        XCTAssertTrue(io.out.contains("Error [DIV_BY_ZERO]"))
        XCTAssertTrue(io.out.contains("Standard Calculator"))
    }

    func testScriptedConverterGuidedFlow() {
        // category 'length' (1) -> from 'm' -> to 'yd' -> value 100 -> back out -> quit
        let io = FakeIo(lines: ["length", "m", "yd", "100", "back", "back", "back", "back", "quit"])
        XCTAssertEqual(runInteractive(io), 0 == 0 ? 0 : 1)
        _ = io
        let io2 = FakeIo(lines: ["3", "1", "m", "yd", "100", "quit"])
        XCTAssertEqual(runInteractive(io2), 0)
        XCTAssertTrue(io2.out.contains("converter (m → yd)> "))
        XCTAssertTrue(io2.out.contains("100 m = 109.361329834 yd"))
    }

    func testEndOfInputExitsCleanly() {
        XCTAssertEqual(runInteractive(FakeIo(lines: [])), 0)
        XCTAssertEqual(runInteractive(FakeIo(lines: ["2"])), 0)
    }
}
