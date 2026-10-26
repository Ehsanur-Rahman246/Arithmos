using Arithmos.Calculator;
using Arithmos.Converter;
using Arithmos.Programmer;
using Arithmos.Shared;

namespace Arithmos.Cli;

/// <summary>How a tool's loop ended.</summary>
public enum Exit { Back, Quit, Eof }

/// <summary>Prompt loops and tool bindings: engines in, text out.</summary>
public static class Tools
{
    // ───────────── help texts ─────────────
    public const string MenuHelp =
        "Pick a tool by number or name (1, std, prog, converter, 0 or exit).\n" +
        "  help (or ?)   show this text\n" +
        "  quit          leave the program";

    const string StandardHelp =
        "Standard Calculator\n" +
        "  Operators:  + - * / ^   unary + -   ( )   %   of\n" +
        "  Functions:  sqrt(x)  abs(x)        Previous result: ans\n" +
        "  Examples:   2 + 3 * 4    20% of 150    200 + 10%    sqrt(16)\n" +
        "  Commands:   help (or ?), back, quit";

    const string ProgrammerHelp =
        "Programmer Calculator (64-bit signed)\n" +
        "  Values:     255   0xFF   0b1010   0o17   0d9   -FF (in hex mode)\n" +
        "  Base:       base bin|oct|dec|hex\n" +
        "  Convert:    convert 255 dec hex   or   255 dec hex\n" +
        "  Bitwise:    5 AND 3   5 OR 3   5 XOR 3   NOT 5\n" +
        "  Shifts:     1 << 3   -8 >> 1 (arithmetic)   -8 >>> 1 (logical)   count 0-63, decimal\n" +
        "  Commands:   help (or ?), back, quit";

    const string ConverterHelp =
        "Unit Converter\n" +
        "  Guided: pick a category, a from-unit and a to-unit, then type values.\n" +
        "  One line (anywhere): convert 100 cm in   100 cm in   convert 1 km all   list   list length\n" +
        "  Commands: help (or ?), back, quit";

    // ───────────── generic prompt loop (calculators) ─────────────
    /// <summary>
    /// help/?, back, quit, blank lines ignored, EOF exits cleanly, every error printed as
    /// "Error [CODE]: message". Unexpected exceptions are caught too, so input never crashes it.
    /// </summary>
    public static Exit PromptLoop(IIo io, string prompt, string intro, string help, Func<string, string> run)
    {
        io.Write(intro + "\n");
        while (true)
        {
            string? raw = io.ReadLine(prompt);
            if (raw == null) return Exit.Eof;
            string line = raw.Trim();
            if (line.Length == 0) continue;

            string l = line.ToLowerInvariant();
            if (l is "help" or "?") { io.Write(help + "\n"); continue; }
            if (l == "back") return Exit.Back;
            if (l == "quit") return Exit.Quit;

            try { io.Write(run(line) + "\n"); }
            catch (ArithmosError e) { io.Write(Report.Error(io, e.Code, e.Message)); }
            catch (Exception e) { io.Write(Report.Error(io, "INTERNAL", e.Message)); }
        }
    }

    public static Exit RunStandard(IIo io)
    {
        var calc = new StandardCalculator();
        return PromptLoop(io, "standard> ",
            "Standard Calculator — type an expression (help for commands, back for the menu).",
            StandardHelp, calc.Evaluate);
    }

    public static Exit RunProgrammer(IIo io)
    {
        var prog = new ProgrammerCalculator();
        return PromptLoop(io, "programmer> ",
            "Programmer Calculator — 64-bit signed (help for commands, back for the menu).",
            ProgrammerHelp, line => FormatProg(prog.Execute(line)));
    }

    /// <summary>Spec §4.4: HEX, DEC, OCT, BIN for a value; just the number for a conversion.</summary>
    public static string FormatProg(ProgResult r) => r switch
    {
        ValueResult v => FormatValue(v.Value),
        TextResult t => t.Text,
        BaseResult b => $"Input base: {b.Name}",
        _ => ""
    };

    static string FormatValue(long v)
    {
        var (hex, dec, oct, bin) = ProgrammerCalculator.Describe(v);
        return $"HEX: {hex}\nDEC: {dec}\nOCT: {oct}\nBIN: {bin}";
    }

    // ───────────── guided converter ─────────────
    static string Cap(string s) => char.ToUpperInvariant(s[0]) + s[1..];

    /// <summary>
    /// A four-stage state machine: category -> from -> to -> values. "back" steps back one
    /// stage and leaves to the main menu from the first. One-line commands work at every stage.
    /// </summary>
    public static Exit RunConverter(IIo io)
    {
        var conv = new UnitConverter();

        // One-line forms: "convert ...", "list ...", or exactly three words ("100 cm in").
        bool TryCommand(string line)
        {
            string[] w = line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
            if (w.Length == 0) return false;
            string w0 = w[0].ToLowerInvariant();
            if (w0 != "convert" && w0 != "list" && w.Length != 3) return false;
            try { io.Write(conv.Execute(line) + "\n"); }
            catch (ArithmosError e) { io.Write(Report.Error(io, e.Code, e.Message)); }
            return true;
        }

        int stage = 0;
        Category? cat = null;
        Unit? from = null, to = null;

        while (true)
        {
            if (stage == 0)
            {
                var opts = conv.Categories.Select(c => new PickOption(c.Name, c.Name)).ToList();
                PickResult r = Pick.Ask(io, "Unit Converter — choose a category", opts, true, true, ConverterHelp, TryCommand);
                if (r.Kind == PickKind.Back) return Exit.Back;
                if (r.Kind == PickKind.Quit) return Exit.Quit;
                if (r.Kind == PickKind.Eof) return Exit.Eof;
                cat = conv.Categories.First(c => c.Name == r.Id);
                stage = 1;
            }
            else if (stage == 1 || stage == 2)
            {
                string title = stage == 1
                    ? $"{Cap(cat!.Name)} — convert from"
                    : $"{Cap(cat!.Name)} — convert from {from!.Symbol} to";

                // Rows read "m — metre"; a symbol or the name selects them.
                var opts = cat.Units
                    .Select(u => new PickOption($"{u.Symbol} — {u.Name}", u.Symbol, new[] { u.Symbol, u.Name }))
                    .ToList();

                PickResult r = Pick.Ask(io, title, opts, true, true, ConverterHelp, TryCommand);
                if (r.Kind == PickKind.Back) { stage--; continue; }
                if (r.Kind == PickKind.Quit) return Exit.Quit;
                if (r.Kind == PickKind.Eof) return Exit.Eof;

                Unit chosen = cat.Units.First(u => u.Symbol == r.Id);
                if (stage == 1) from = chosen; else to = chosen;
                stage++;
            }
            else
            {
                Exit? leave = ValuesPrompt(io, conv, from!, to!, out bool goBack);
                if (leave != null) return leave.Value;
                if (goBack) stage = 2;
            }
        }
    }

    /// <summary>The values prompt shows the units: "converter (m → yd)>". Returns null to go back a stage.</summary>
    static Exit? ValuesPrompt(IIo io, UnitConverter conv, Unit from, Unit to, out bool goBack)
    {
        goBack = false;
        string prompt = $"converter ({from.Symbol} → {to.Symbol})> ";
        io.Write("Type a value (for example 100). help, back, quit.\n");

        while (true)
        {
            string? raw = io.ReadLine(prompt);
            if (raw == null) return Exit.Eof;
            string line = raw.Trim();
            if (line.Length == 0) continue;

            string l = line.ToLowerInvariant();
            if (l is "help" or "?") { io.Write(ConverterHelp + "\n"); continue; }
            if (l == "back") { goBack = true; return null; }
            if (l == "quit") return Exit.Quit;

            try
            {
                string[] w = line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
                if (w.Length == 1 && l != "list")
                    io.Write($"{line} {from.Symbol} = {conv.ConvertValue(line, from.Symbol, to.Symbol)} {to.Symbol}\n");
                else
                    io.Write(conv.Execute(line) + "\n"); // full one-line forms also work here
            }
            catch (ArithmosError e) { io.Write(Report.Error(io, e.Code, e.Message)); }
            catch (Exception e) { io.Write(Report.Error(io, "INTERNAL", e.Message)); }
        }
    }
}