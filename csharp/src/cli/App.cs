using System.Text;
using Arithmos.Calculator;
using Arithmos.Converter;
using Arithmos.Programmer;
using Arithmos.Shared;

namespace Arithmos.Cli;

/// <summary>Entry logic: argv -> one-shot mode or the interactive menu.</summary>
public static class App
{
    const string Usage =
        "Usage: arithmos                         interactive menu\n" +
        "       arithmos std <expression>        one calculation\n" +
        "       arithmos prog <command>          one programmer command\n" +
        "       arithmos convert <value> <from> <to>\n" +
        "       arithmos list [category]\n" +
        "Exit status: 0 success, 1 the line produced an Error [CODE], 2 bad usage.";

    public static int Run(string[] args)
    {
        Console.OutputEncoding = new UTF8Encoding(false); // "→ — ❯ ✔" must print correctly

        if (args.Length > 0) return OneShot(args, Console.Out, Console.Error);

        if (Terminal.IsInteractive())
        {
            Terminal.EnableAnsiOnWindows();
            // Safety net for SIGTERM and friends: make sure the cursor is visible again.
            AppDomain.CurrentDomain.ProcessExit += (_, _) => Console.Out.Write(Selector.ShowCursor);
        }
        return RunInteractive(new ConsoleIo());
    }

    // ───────────── interactive menu ─────────────
    public static int RunInteractive(IIo io)
    {
        var menu = new[]
        {
            new PickOption("Standard Calculator", "std", new[] { "standard", "std" }),
            new PickOption("Programmer Calculator", "prog", new[] { "programmer", "prog" }),
            new PickOption("Unit Converter", "conv", new[] { "converter", "convert" }),
            new PickOption("Exit", "exit", new[] { "exit" }, "0"),
        };

        while (true)
        {
            // The main menu offers quit but not back (it has nowhere to go back to).
            PickResult r = Pick.Ask(io, "Arithmos 1.0 — Core CLI", menu, back: false, quit: true, help: Tools.MenuHelp);
            if (r.Kind != PickKind.Chosen) return 0;

            Exit x = r.Id switch
            {
                "std" => Tools.RunStandard(io),
                "prog" => Tools.RunProgrammer(io),
                "conv" => Tools.RunConverter(io),
                _ => Exit.Quit
            };
            if (x != Exit.Back) return 0; // quit or end of input
        }
    }

    // ───────────── one-shot mode (R31) ─────────────
    /// <summary>
    /// Results and --help go to stdout; Error lines and the usage after bad input go to stderr.
    /// The command word is case-insensitive; "standard" and "programmer" are long forms.
    /// </summary>
    public static int OneShot(string[] args, TextWriter output, TextWriter error)
    {
        string cmd = args[0].ToLowerInvariant();
        string rest = string.Join(" ", args.Skip(1)).Trim();

        try
        {
            switch (cmd)
            {
                case "--help":
                case "-h":
                case "help":
                    output.WriteLine(Usage);
                    return 0;

                case "std":
                case "standard":
                    if (rest.Length == 0) return BadUsage(error, "Missing expression.");
                    output.WriteLine(new StandardCalculator().Evaluate(rest));
                    return 0;

                case "prog":
                case "programmer":
                    if (rest.Length == 0) return BadUsage(error, "Missing command.");
                    output.WriteLine(Tools.FormatProg(new ProgrammerCalculator().Execute(rest)));
                    return 0;

                case "convert":
                    if (rest.Length == 0) return BadUsage(error, "Missing arguments.");
                    output.WriteLine(new UnitConverter().Execute("convert " + rest));
                    return 0;

                case "list":
                    output.WriteLine(new UnitConverter().Execute(("list " + rest).Trim()));
                    return 0;

                default:
                    return BadUsage(error, $"Unknown command '{args[0]}'.");
            }
        }
        catch (ArithmosError e)
        {
            error.WriteLine($"Error [{e.Code}]: {e.Message}");
            return 1;
        }
        catch (Exception e)
        {
            error.WriteLine($"Error [INTERNAL]: {e.Message}");
            return 1;
        }
    }

    static int BadUsage(TextWriter error, string why)
    {
        error.WriteLine(why);
        error.WriteLine(Usage);
        return 2;
    }
}