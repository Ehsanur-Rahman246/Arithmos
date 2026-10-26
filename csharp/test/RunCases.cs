using System.Text.Json;
using Arithmos.Calculator;
using Arithmos.Converter;
using Arithmos.Programmer;
using Arithmos.Shared;

namespace Arithmos.Tests;

/// <summary>What one input produced: text, the four programmer fields, or an error code.</summary>
public sealed record Outcome(string? Text, Dictionary<string, string>? Fields, string? Code);

/// <summary>One session of one tool; engines keep their own state (ans, input base).</summary>
public sealed class Session
{
    readonly string tool;
    readonly StandardCalculator std = new();
    readonly ProgrammerCalculator prog = new();
    readonly UnitConverter conv = new();

    public Session(string tool) => this.tool = tool;

    public Outcome Run(string line)
    {
        try
        {
            switch (tool)
            {
                case "standard": return new Outcome(std.Evaluate(line), null, null);
                case "programmer":
                    switch (prog.Execute(line))
                    {
                        case ValueResult v:
                            var (hex, dec, oct, bin) = ProgrammerCalculator.Describe(v.Value);
                            return new Outcome(null, new Dictionary<string, string>
                                { ["HEX"] = hex, ["DEC"] = dec, ["OCT"] = oct, ["BIN"] = bin }, null);
                        case TextResult t: return new Outcome(t.Text, null, null);
                        case BaseResult b: return new Outcome("Input base: " + b.Name, null, null);
                        default: throw new InvalidOperationException("unknown result");
                    }
                default: return new Outcome(conv.Execute(line), null, null);
            }
        }
        catch (ArithmosError e)
        {
            return new Outcome(null, null, e.Code); // tests assert the code, never the message
        }
    }
}

/// <summary>Loads docs/release-1-cases.json and runs all 175 shared cases (format: docs/test-cases.md).</summary>
public static class RunCases
{
    public static void Run(string path)
    {
        using JsonDocument doc = JsonDocument.Parse(File.ReadAllText(path));
        int count = 0;
        foreach (JsonElement c in doc.RootElement.EnumerateArray())
        {
            count++;
            string id = c.GetProperty("id").GetString()!;
            try { RunCase(c, id); }
            catch (Exception e) { H.Ok(false, id, "crashed: " + e.Message); }
        }
        H.Ok(count == 175, "shared case count", count.ToString());
    }

    static void RunCase(JsonElement c, string id)
    {
        var session = new Session(c.GetProperty("tool").GetString()!);

        // "setup" lines run first in the same session (P19, P31, P32).
        if (c.TryGetProperty("setup", out JsonElement setup))
            foreach (JsonElement line in setup.EnumerateArray())
                session.Run(line.GetString()!);

        if (c.TryGetProperty("steps", out JsonElement steps))
        {
            int i = 0;
            foreach (JsonElement step in steps.EnumerateArray())
                Check(step, session.Run(step.GetProperty("input").GetString()!), $"{id}.{++i}");
            return;
        }
        Check(c, session.Run(c.GetProperty("input").GetString()!), id);
    }

    static void Check(JsonElement expect, Outcome got, string name)
    {
        // Exactly one of error / expectedContains / expected is present.
        if (expect.TryGetProperty("error", out JsonElement err))
        {
            H.Ok(got.Code == err.GetString(), name, $"wanted error {err.GetString()}, got {got.Code ?? got.Text}");
        }
        else if (expect.TryGetProperty("expectedContains", out JsonElement contains))
        {
            string[] lines = (got.Text ?? "").Split('\n');
            foreach (JsonElement want in contains.EnumerateArray())
                H.Ok(lines.Contains(want.GetString()), name, $"missing line '{want.GetString()}'");
        }
        else
        {
            JsonElement exp = expect.GetProperty("expected");
            if (exp.ValueKind == JsonValueKind.String)
                H.Ok(got.Text == exp.GetString(), name, $"wanted '{exp.GetString()}', got '{got.Text ?? got.Code}'");
            else
                foreach (JsonProperty p in exp.EnumerateObject())
                    H.Ok(got.Fields != null && got.Fields.TryGetValue(p.Name, out string? val) && val == p.Value.GetString(),
                         name, $"wanted {p.Name}={p.Value.GetString()}");
        }
    }
}