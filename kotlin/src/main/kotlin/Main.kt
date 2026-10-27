package arithmos

import arithmos.cli.ConsoleIo
import arithmos.cli.runInteractive
import arithmos.cli.runOneShot
import java.io.FileDescriptor
import java.io.FileOutputStream
import java.io.PrintStream
import kotlin.system.exitProcess

/** Entry point: argv -> one-shot mode, no argv -> the interactive menu. */
private fun realMain(args: List<String>): Int {
    if (args.isNotEmpty()) {
        val out = PrintStream(FileOutputStream(FileDescriptor.out), true, "UTF-8")
        val err = PrintStream(FileOutputStream(FileDescriptor.err), true, "UTF-8")
        return runOneShot(args, out, err)
    }
    runInteractive(ConsoleIo())
    return 0
}

fun main(args: Array<String>) {
    var code = 0
    // A 256 MB stack, so deeply nested expressions cannot overflow the default stack
    // (lines over 20 000 characters are rejected anyway).
    val t = Thread(null, { code = realMain(args.toList()) }, "arithmos", 256L * 1024 * 1024)
    t.start()
    t.join()
    exitProcess(code)
}