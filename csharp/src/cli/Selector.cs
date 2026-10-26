using Arithmos.Shared;

namespace Arithmos.Cli;

// ─────────────────────────── types ───────────────────────────
public enum KeyKind { Up, Down, Home, End, PageUp, PageDown, Enter, Esc, CtrlC, CtrlD, Char, Other }

/// <summary>One key press. <c>Ch</c> is set for <c>KeyKind.Char</c> only.</summary>
public readonly record struct Key(KeyKind Kind, char Ch = '\0');

/// <summary>Which keys the selector honours (spec: "hint lists only the keys on offer").</summary>
public sealed record SelOptions(bool Back, bool Quit, bool Typing);

public enum SelKind { Chosen, Back, Quit, Abort, Typed, Unavailable }

/// <summary>How a selector run ended.</summary>
public readonly record struct SelOutcome(SelKind Kind, int Index = -1, char Ch = '\0');

/// <summary>Keyboard, injectable so tests can script it.</summary>
public interface IKeys
{
    void Enter();   // raw mode on (Ctrl-C readable as a key)
    void Leave();   // always restored
    Key Read();
}

/// <summary>Screen, injectable so tests can capture it.</summary>
public interface IScreen
{
    bool Color { get; }
    void Write(string text);
    (int Width, int Height) Size();
}

/// <summary>Selector cursor and scroll window.</summary>
public sealed class SelState
{
    public int N;
    public int Index;
    public int Top;
    public int Window = 10;

    public SelState(int n) => N = n;

    /// <summary>Keeps the selected row inside the visible window.</summary>
    public void Scroll()
    {
        if (Window > N) Window = N;
        if (Window < 1) { Top = 0; return; }
        if (Index < Top) Top = Index;
        else if (Index >= Top + Window) Top = Index - Window + 1;
        Top = Math.Max(0, Math.Min(Top, N - Window));
    }
}

/// <summary>
/// The four selector layers in one place: pure key handling (Handle), pure drawing (Render),
/// and the draw/read loop over an injectable keyboard and screen (Run). pick() is in Pick.cs.
/// </summary>
public static class Selector
{
    public const string HideCursor = "\u001b[?25l";
    public const string ShowCursor = "\u001b[?25h";

    /// <summary>Moves the cursor up over the block just drawn and clears it.</summary>
    public static string Erase(int lines) => $"\u001b[{lines}A\r\u001b[J";

    // ───────────── layer 1: key handling (pure) ─────────────
    /// <summary>Returns null while the selector stays open, otherwise how it ended.</summary>
    public static SelOutcome? Handle(SelState s, Key k, SelOptions o)
    {
        switch (k.Kind)
        {
            case KeyKind.Up: Go(s, (s.Index - 1 + s.N) % Math.Max(1, s.N)); return null;      // wraps
            case KeyKind.Down: Go(s, (s.Index + 1) % Math.Max(1, s.N)); return null;           // wraps
            case KeyKind.Home: Go(s, 0); return null;
            case KeyKind.End: Go(s, s.N - 1); return null;
            case KeyKind.PageUp: Go(s, Math.Max(0, s.Index - s.Window)); return null;
            case KeyKind.PageDown: Go(s, Math.Min(s.N - 1, s.Index + s.Window)); return null;
            case KeyKind.Enter: return new SelOutcome(SelKind.Chosen, s.Index);
            case KeyKind.Esc: return o.Back ? new SelOutcome(SelKind.Back) : null;
            case KeyKind.CtrlC:
            case KeyKind.CtrlD: return new SelOutcome(SelKind.Abort);
            case KeyKind.Char:
            {
                char c = k.Ch;
                char lc = char.ToLowerInvariant(c);
                // b and q act at once, and only when offered.
                if (lc == 'b' && o.Back) return new SelOutcome(SelKind.Back);
                if (lc == 'q' && o.Quit) return new SelOutcome(SelKind.Quit);
                // Any other printable key opens a typed line (never space or control keys).
                if (o.Typing && !char.IsWhiteSpace(c) && !char.IsControl(c))
                    return new SelOutcome(SelKind.Typed, -1, c);
                return null;
            }
            default: return null; // other control keys are ignored
        }
    }

    static void Go(SelState s, int index)
    {
        if (s.N == 0) return;
        s.Index = Math.Max(0, Math.Min(s.N - 1, index));
        s.Scroll();
    }

    // ───────────── layer 2: drawing (pure) ─────────────
    /// <summary>Cuts a line to <paramref name="max"/> columns, ending with "…" when shortened.</summary>
    public static string Fit(string s, int max)
    {
        if (max < 1) return "";
        if (s.Length <= max) return s;
        return max == 1 ? "…" : s.Substring(0, max - 1) + "…";
    }

    public static string Hint(SelOptions o)
    {
        var parts = new List<string> { "↑↓ move", "Enter select" };
        if (o.Back) parts.Add("Esc/b back");
        if (o.Quit) parts.Add("q quit");
        if (o.Typing) parts.Add("or type");
        return string.Join(" · ", parts);
    }

    /// <summary>
    /// The block to draw: title, the visible rows, hint. Every line is at most width-1 columns,
    /// so one logical line is one screen line (spec rule 6). The selected row is a full
    /// reverse-video bar with "❯"; without colour the "❯" pointer alone marks it.
    /// </summary>
    public static List<string> Render(string title, IReadOnlyList<string> labels, SelState s,
                                      SelOptions o, int width, bool color)
    {
        int w = Math.Max(1, width - 1);
        var lines = new List<string> { Fit(title, w) };

        int end = Math.Min(labels.Count, s.Top + s.Window);
        for (int i = s.Top; i < end; i++)
        {
            bool sel = i == s.Index;
            string text = Fit((sel ? "❯ " : "  ") + labels[i], w);
            lines.Add(sel && color ? "\u001b[7m" + text.PadRight(w) + "\u001b[0m" : text);
        }

        string hint = Fit(Hint(o), w);
        lines.Add(color ? "\u001b[2m" + hint + "\u001b[0m" : hint);
        return lines;
    }

    // ───────────── layer 3: the draw/read loop ─────────────
    /// <summary>
    /// Draws the list, reads keys until one ends it, erases the block, leaves "✔ title: label"
    /// behind on a choice and ALWAYS restores the cursor and the keyboard.
    /// </summary>
    public static SelOutcome Run(IKeys keys, IScreen scr, string title, IReadOnlyList<string> labels, SelOptions o)
    {
        if (labels.Count == 0) return new SelOutcome(SelKind.Back);

        var st = new SelState(labels.Count);
        int drawn = 0;
        int width = 80;

        keys.Enter();
        scr.Write(HideCursor);
        try
        {
            while (true)
            {
                // Measured on every redraw, so resizing works. The block must fit the height:
                // title + window + hint + one spare line.
                var (w, h) = scr.Size();
                width = w;
                st.Window = Math.Max(1, Math.Min(Math.Min(10, labels.Count), h - 3));
                st.Scroll();

                List<string> lines = Render(title, labels, st, o, w, scr.Color);
                if (drawn > 0) scr.Write(Erase(drawn));
                scr.Write(string.Concat(lines.Select(l => l + "\n")));
                drawn = lines.Count;

                SelOutcome? res = Handle(st, keys.Read(), o);
                if (res is SelOutcome r)
                {
                    scr.Write(Erase(drawn));
                    if (r.Kind == SelKind.Chosen)
                        scr.Write(Fit($"✔ {title}: {labels[r.Index]}", Math.Max(1, width - 1)) + "\n");
                    return r;
                }
            }
        }
        finally
        {
            scr.Write(ShowCursor);
            keys.Leave();
        }
    }
}