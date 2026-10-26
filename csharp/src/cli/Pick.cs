namespace Arithmos.Cli;

/// <summary>One answer to a pick(): label shown, id returned, extra typed names, optional number.</summary>
public sealed record PickOption(string Label, string Id, string[]? Aliases = null, string? Number = null);

public enum PickKind { Chosen, Back, Quit, Eof }

public readonly record struct PickResult(PickKind Kind, string? Id = null);

/// <summary>
/// pick(): one question, many answers. On a real terminal it is the arrow-key selector;
/// everywhere else it is a numbered list answered by typing a number, a name or a symbol.
/// </summary>
public static class Pick
{
    public static PickResult Ask(IIo io, string title, IReadOnlyList<PickOption> options,
                                 bool back, bool quit, string help, Func<string, bool>? tryCommand = null)
    {
        var labels = options.Select(o => o.Label).ToList();
        bool plain = !io.HasSelector;
        bool redraw = true;

        while (true)
        {
            string? line;

            if (!plain)
            {
                SelOutcome o = io.Select(title, labels, new SelOptions(back, quit, true));
                switch (o.Kind)
                {
                    // Enter / Esc / b / q act at once, with no prompt line.
                    case SelKind.Chosen: return new PickResult(PickKind.Chosen, options[o.Index].Id);
                    case SelKind.Back: return new PickResult(PickKind.Back);
                    case SelKind.Quit: return new PickResult(PickKind.Quit);
                    case SelKind.Abort: return new PickResult(PickKind.Eof);
                    case SelKind.Unavailable: plain = true; continue; // raw keys failed: use the list
                    default:
                        // A printable key: the prompt shows it and the rest of the line is read.
                        line = io.ReadLinePrefill("> ", o.Ch.ToString());
                        break;
                }
                if (line == null) return new PickResult(PickKind.Eof);
            }
            else
            {
                if (redraw) io.Write(PlainList(title, options));
                redraw = false;
                line = io.ReadLine("> ");
                if (line == null) return new PickResult(PickKind.Eof);
            }

            string t = line.Trim();
            if (t.Length == 0) continue; // blank input is ignored
            string l = t.ToLowerInvariant();

            if (l is "help" or "?") { io.Write(help + "\n"); redraw = true; continue; }
            if (back && l == "back") return new PickResult(PickKind.Back);
            if (quit && l == "quit") return new PickResult(PickKind.Quit);

            int idx = Find(options, t);
            if (idx >= 0) return new PickResult(PickKind.Chosen, options[idx].Id);

            // A one-line command (converter: "100 cm in", "list") runs and the list comes back.
            if (tryCommand != null && tryCommand(t)) { redraw = true; continue; }

            io.Write(Report.Error(io, "UNKNOWN_COMMAND", "Pick one from the list"));
            redraw = true;
        }
    }

    static string NumberOf(IReadOnlyList<PickOption> options, int i) =>
        options[i].Number ?? (i + 1).ToString();

    /// <summary>"  1) label" rows: two spaces, the number, ")", a space, the label (R28).</summary>
    public static string PlainList(string title, IReadOnlyList<PickOption> options)
    {
        var sb = new System.Text.StringBuilder();
        sb.Append(title).Append('\n');
        for (int i = 0; i < options.Count; i++)
            sb.Append("  ").Append(NumberOf(options, i)).Append(") ").Append(options[i].Label).Append('\n');
        return sb.ToString();
    }

    static int Find(IReadOnlyList<PickOption> options, string typed)
    {
        for (int i = 0; i < options.Count; i++)               // numbers first
            if (NumberOf(options, i) == typed) return i;
        for (int i = 0; i < options.Count; i++)               // then names and symbols
        {
            if (options[i].Label.Equals(typed, StringComparison.OrdinalIgnoreCase)) return i;
            if (options[i].Aliases != null &&
                options[i].Aliases!.Any(a => a.Equals(typed, StringComparison.OrdinalIgnoreCase))) return i;
        }
        return -1;
    }
}