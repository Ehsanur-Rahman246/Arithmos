using System.Text;

namespace Arithmos.Cli;

/// <summary>
/// What the CLI needs from the outside world. Tests replace it with a fake;
/// this is the only seam to stdin/stdout.
/// </summary>
public interface IIo
{
    bool Color { get; }
    void Write(string text);                                   // text as given (no newline added)
    string? ReadLine(string prompt);                           // null at end of input
    string? ReadLinePrefill(string prompt, string prefill);    // the key that opened a typed line + the rest
    bool HasSelector { get; }                                  // true only on a real terminal
    SelOutcome Select(string title, IReadOnlyList<string> labels, SelOptions opts);
}

/// <summary>The real console.</summary>
public sealed class ConsoleIo : IIo
{
    bool selector;

    public ConsoleIo()
    {
        Color = Terminal.UseColor();
        selector = Terminal.IsInteractive();
    }

    public bool Color { get; }
    public bool HasSelector => selector;

    public void Write(string text)
    {
        Console.Out.Write(text);
        Console.Out.Flush();
    }

    public string? ReadLine(string prompt)
    {
        Write(prompt);
        string? line = Console.ReadLine();
        if (line == null) Write("\n"); // tidy end-of-input
        return line;
    }

    public string? ReadLinePrefill(string prompt, string prefill)
    {
        // The key was read without echo, so show it, then read the rest of the line.
        Write(prompt + prefill);
        string? rest = Console.ReadLine();
        if (rest == null) { Write("\n"); return null; }
        return prefill + rest;
    }

    public SelOutcome Select(string title, IReadOnlyList<string> labels, SelOptions opts)
    {
        try
        {
            return Selector.Run(new ConsoleKeys(), new ConsoleScreen(Color), title, labels, opts);
        }
        catch (Exception e) when (e is InvalidOperationException or IOException)
        {
            selector = false; // raw keys unavailable: fall back to numbered lists
            return new SelOutcome(SelKind.Unavailable);
        }
    }
}

/// <summary>
/// Real keyboard. .NET does the raw-mode work itself (and restores it); the only thing
/// switched here is Ctrl-C, which must arrive as a key while a selector is on screen.
/// </summary>
sealed class ConsoleKeys : IKeys
{
    bool saved;

    public void Enter()
    {
        saved = Console.TreatControlCAsInput;
        Console.TreatControlCAsInput = true;
    }

    public void Leave() => Console.TreatControlCAsInput = saved;

    public Key Read() => KeyParser.FromConsole(Console.ReadKey(intercept: true));
}

/// <summary>Real screen: size measured on every redraw.</summary>
sealed class ConsoleScreen : IScreen
{
    public ConsoleScreen(bool color) => Color = color;

    public bool Color { get; }

    public void Write(string text)
    {
        Console.Out.Write(text);
        Console.Out.Flush();
    }

    public (int Width, int Height) Size()
    {
        try { return (Math.Max(20, Console.WindowWidth), Math.Max(4, Console.WindowHeight)); }
        catch { return (80, 24); }
    }
}