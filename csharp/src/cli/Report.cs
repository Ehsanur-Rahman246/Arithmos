namespace Arithmos.Cli;

/// <summary>The one place an error becomes text: "Error [CODE]: message".</summary>
public static class Report
{
    public static string Error(IIo io, string code, string message)
    {
        string text = $"Error [{code}]: {message}";
        return (io.Color ? "\u001b[31m" + text + "\u001b[0m" : text) + "\n";
    }
}