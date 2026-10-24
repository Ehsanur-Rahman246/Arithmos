package arithmos;

import arithmos.cli.Cli;
import arithmos.cli.ConsoleIo;
import arithmos.cli.Style;
import arithmos.cli.Terminal;
import java.io.FileDescriptor;
import java.io.FileOutputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;

/** Entry point: argv → one-shot mode, or the interactive menu. */
public final class Main {
    private Main() {}

    public static void main(String[] args) {
        // Always UTF-8, whatever the platform default is: the screens use ❯ ✔ → —.
        PrintStream out = new PrintStream(new FileOutputStream(FileDescriptor.out), false, StandardCharsets.UTF_8);
        PrintStream err = new PrintStream(new FileOutputStream(FileDescriptor.err), true, StandardCharsets.UTF_8);

        int status;
        if (args.length > 0) {
            status = Cli.oneShot(args, out, err);
        } else {
            Terminal terminal = Terminal.open(); // null → numbered lists
            String noColor = System.getenv("NO_COLOR");
            boolean color = terminal != null && (noColor == null || noColor.isEmpty());
            try {
                status = Cli.interactive(new ConsoleIo(out, new Style(color), terminal));
            } finally {
                if (terminal != null) terminal.close();
            }
        }
        out.flush();
        System.exit(status);
    }
}