import XCTest

@testable import ArithmosKit

/// Runs the 175 shared cases from docs/release-1-cases.json (spec §7, test-cases.md).
final class CasesTests: XCTestCase {

    private enum Outcome {
        case lines([String])
        case fields([String: String])
        case error(String)
    }

    /// One session per case (setup lines and steps share it).
    private final class Session {
        let std = StandardCalculator()
        let prog = ProgrammerCalculator()
        let conv = ArithmosConverter()
    }

    private func exec(_ tool: String, _ line: String, _ s: Session) -> Outcome {
        do {
            switch tool {
            case "standard":
                return .lines([try s.std.calculate(line)])
            case "programmer":
                switch try s.prog.run(line) {
                case .value(let v):
                    var d: [String: String] = [:]
                    for f in fields(v) { d[f.label] = f.value }
                    return .fields(d)
                case .converted(let t): return .lines([t])
                case .baseSet(let b): return .lines([b.rawValue])
                }
            default:
                return .lines(try s.conv.run(line))
            }
        } catch let e as ArithmosError {
            return .error(e.code.rawValue)
        } catch {
            return .error("OTHER")
        }
    }

    private func check(_ id: String, _ step: [String: Any], _ tool: String, _ s: Session) {
        guard let input = step["input"] as? String else { return XCTFail("\(id): no input") }
        let got = exec(tool, input, s)
        if let code = step["error"] as? String {
            guard case .error(let c) = got else {
                return XCTFail("\(id): expected \(code), got \(got)")
            }
            XCTAssertEqual(c, code, id)
        } else if let want = step["expected"] as? String {
            guard case .lines(let l) = got else {
                return XCTFail("\(id): expected text, got \(got)")
            }
            XCTAssertEqual(l.joined(separator: "\n"), want, id)
        } else if let want = step["expected"] as? [String: String] {
            guard case .fields(let f) = got else {
                return XCTFail("\(id): expected fields, got \(got)")
            }
            for (k, v) in want { XCTAssertEqual(f[k], v, "\(id) \(k)") }
        } else if let want = step["expectedContains"] as? [String] {
            guard case .lines(let l) = got else {
                return XCTFail("\(id): expected lines, got \(got)")
            }
            for w in want { XCTAssertTrue(l.contains(w), "\(id): missing '\(w)' in \(l)") }
        } else {
            XCTFail("\(id): no outcome in case")
        }
    }

    func testSharedCases() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: casesPath()))
        let cases = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(cases.count, 175)  // no shared case may be skipped
        for c in cases {
            let id = c["id"] as? String ?? "?"
            let tool = c["tool"] as? String ?? ""
            let session = Session()
            for line in (c["setup"] as? [String]) ?? [] { _ = exec(tool, line, session) }
            if let steps = c["steps"] as? [[String: Any]] {
                for step in steps { check(id, step, tool, session) }
            } else {
                check(id, c, tool, session)
            }
        }
    }
}
