// One-shot mode (spec §2.1, R31). Results and --help go to stdout; `Error [CODE]`
// lines and usage after bad input go to stderr. Exit: 0 ok, 1 Error [CODE], 2 bad usage.

private let usageText = """
    Usage: arithmos                         interactive menu
           arithmos std "<expression>"      one calculation
           arithmos prog <command...>       one programmer command
           arithmos convert <v> <from> <to> one conversion
           arithmos list [category]         list categories or units
    """

func runOneShot(_ args: [String], _ io: Io) -> Int32 {
    func usage() -> Int32 {
        io.writeError(usageText + "\n")
        return 2
    }

    guard let word = args.first?.lowercased() else { return usage() }
    if word == "--help" || word == "-h" || word == "help" {
        io.write(usageText + "\n")
        return 0
    }
    let rest = Array(args.dropFirst())
    let line = rest.joined(separator: " ")
    do {
        switch word {
        case "std", "standard":
            if rest.isEmpty { return usage() }
            io.write(try StandardCalculator().calculate(line) + "\n")
        case "prog", "programmer":
            if rest.isEmpty { return usage() }
            io.write(
                programmerLines(try ProgrammerCalculator().run(line)).joined(separator: "\n") + "\n"
            )
        case "convert":
            if rest.isEmpty { return usage() }
            io.write(try ArithmosConverter().run("convert " + line).joined(separator: "\n") + "\n")
        case "list":
            io.write(try ArithmosConverter().run("list " + line).joined(separator: "\n") + "\n")
        default:
            return usage()
        }
        return 0
    } catch let e as ArithmosError {
        io.writeError(e.line + "\n")
        return 1
    } catch {
        io.writeError("Error [INTERNAL]: \(error)\n")
        return 1
    }
}
