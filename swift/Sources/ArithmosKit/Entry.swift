import Foundation

// A small box so the worker thread can hand an exit code back (Sendable-safe).
private final class ExitBox: @unchecked Sendable { var code: Int32 = 0 }

/// Runs the program on a thread with a large stack, so deeply nested expressions
/// (up to the 20 000-character line limit) cannot overflow the stack.
public func arithmosRun(_ arguments: [String]) -> Int32 {
    let box = ExitBox()
    let done = DispatchSemaphore(value: 0)
    let args = Array(arguments.dropFirst())          // drop the program name
    let thread = Thread {
        box.code = realMain(args)
        done.signal()
    }
    thread.stackSize = 256 << 20                      // 256 MB
    thread.start()
    done.wait()
    platformShutdown()                                // restore console modes / code pages (Windows)
    return box.code
}

private func realMain(_ args: [String]) -> Int32 {
    platformStartup()                                 // UTF-8 + ANSI escapes on (Windows)
    let env = ProcessInfo.processInfo.environment
    // Selector only on a real terminal (spec §2.1); ARITHMOS_PLAIN=1 forces numbered lists.
    let realTerminal = stdinIsTerminal() && stdoutIsTerminal()
        && env["TERM"] != "dumb" && env["ARITHMOS_PLAIN"] != "1"
    let colour = stdoutIsTerminal() && (env["NO_COLOR"] ?? "").isEmpty
    let io = ConsoleIo(selector: realTerminal, color: colour)
    if args.isEmpty { return runInteractive(io) }
    return runOneShot(args, io)
}