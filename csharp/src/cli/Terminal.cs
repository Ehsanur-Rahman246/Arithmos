using System.Runtime.InteropServices;

namespace Arithmos.Cli;

/// <summary>Terminal detection and the Windows console switches.</summary>
public static class Terminal
{
    /// <summary>
    /// The arrow-key selector is used only on a real terminal: stdin and stdout are terminals,
    /// TERM is not "dumb" and ARITHMOS_PLAIN is not "1". Everywhere else: numbered lists.
    /// </summary>
    public static bool IsInteractive()
    {
        if (Environment.GetEnvironmentVariable("ARITHMOS_PLAIN") == "1") return false;
        if (Console.IsInputRedirected || Console.IsOutputRedirected) return false;
        string? term = Environment.GetEnvironmentVariable("TERM");
        return !string.Equals(term, "dumb", StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>NO_COLOR=1 (any non-empty value) switches colour off.</summary>
    public static bool UseColor() =>
        string.IsNullOrEmpty(Environment.GetEnvironmentVariable("NO_COLOR")) && !Console.IsOutputRedirected;

    // ───────────── Windows: ANSI escapes ─────────────
    const int StdOutputHandle = -11;
    const uint EnableVirtualTerminalProcessing = 0x0004;

    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int handle);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr handle, out uint mode);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr handle, uint mode);

    /// <summary>
    /// Switches ANSI escape processing on for the life of the program and restores the old
    /// console mode on exit. A no-op off Windows or if the calls fail.
    /// </summary>
    public static void EnableAnsiOnWindows()
    {
        if (!OperatingSystem.IsWindows()) return;
        try
        {
            IntPtr h = GetStdHandle(StdOutputHandle);
            if (!GetConsoleMode(h, out uint old)) return;
            if (!SetConsoleMode(h, old | EnableVirtualTerminalProcessing)) return;
            AppDomain.CurrentDomain.ProcessExit += (_, _) => SetConsoleMode(h, old);
        }
        catch { /* the numbered lists still work */ }
    }
}