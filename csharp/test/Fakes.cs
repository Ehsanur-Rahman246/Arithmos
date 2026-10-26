using System.Text;
using Arithmos.Cli;

namespace Arithmos.Tests;

/// <summary>Scripted keyboard for the selector loop.</summary>
public sealed class FakeKeys : IKeys
{
    readonly Queue<Key> q;
    public int Entered, Left;

    public FakeKeys(params Key[] keys) => q = new Queue<Key>(keys);

    public void Enter() => Entered++;
    public void Leave() => Left++;
    public Key Read() => q.Dequeue();
}

/// <summary>Captures everything drawn.</summary>
public sealed class FakeScreen : IScreen
{
    public readonly StringBuilder Out = new();
    readonly int w, h;

    public FakeScreen(int width = 80, int height = 24, bool color = false)
    {
        w = width; h = height; Color = color;
    }

    public bool Color { get; }
    public void Write(string text) => Out.Append(text);
    public (int Width, int Height) Size() => (w, h);
}

/// <summary>Scripted io for pick(), the tool loops and whole sessions.</summary>
public sealed class FakeIo : IIo
{
    public readonly Queue<string?> Lines = new();
    public readonly Queue<SelOutcome> Sel = new();
    public readonly StringBuilder Out = new();
    public int ReadCalls;
    public string? LastPrefill;

    public bool Color => false;
    public bool HasSelector { get; set; }

    public void Write(string text) => Out.Append(text);

    public string? ReadLine(string prompt)
    {
        ReadCalls++;
        Out.Append(prompt);
        return Lines.Count > 0 ? Lines.Dequeue() : null; // null = end of input
    }

    public string? ReadLinePrefill(string prompt, string prefill)
    {
        ReadCalls++;
        LastPrefill = prefill;
        Out.Append(prompt).Append(prefill);
        return Lines.Count > 0 ? Lines.Dequeue() : null;
    }

    public SelOutcome Select(string title, IReadOnlyList<string> labels, SelOptions opts) => Sel.Dequeue();
}