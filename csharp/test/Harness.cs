namespace Arithmos.Tests;

/// <summary>A tiny assertion counter, so the test project needs no packages.</summary>
public static class H
{
    public static int Pass, Fail;

    public static void Ok(bool condition, string name, string detail = "")
    {
        if (condition) { Pass++; return; }
        Fail++;
        Console.WriteLine($"FAIL {name} {detail}");
    }
}