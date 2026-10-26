using Arithmos.Cli;
using Arithmos.Converter;
using Arithmos.Programmer;
using Arithmos.Shared;

namespace Arithmos.Tests;

/// <summary>C# extras: formatting boundaries, settled amendments, garbage input, sessions, exit codes.</summary>
public static class Extras
{
    /// <summary>
    /// expect: "!CODE" = error code; "FIELD=value" = programmer field (HEX/DEC/OCT/BIN); anything else = exact text.
    /// </summary>
    static void X(string tool, string input, string expect, params string[] setup)
    {
        var s = new Session(tool);
        foreach (string line in setup) s.Run(line);
        Outcome o;
        try { o = s.Run(input); }
        catch (Exception e) { H.Ok(false, $"{tool}: {input}", "crashed: " + e.Message); return; }

        bool ok;
        if (expect.StartsWith('!')) ok = o.Code == expect[1..];
        else if (tool == "programmer" && expect.Contains('=') && o.Fields != null)
        {
            int i = expect.IndexOf('=');
            ok = o.Fields.TryGetValue(expect[..i], out string? v) && v == expect[(i + 1)..];
        }
        else ok = o.Text == expect;
        H.Ok(ok, $"{tool}: {input}", $"wanted {expect}, got {o.Text ?? o.Code ?? string.Join(",", o.Fields?.Values.ToArray() ?? Array.Empty<string>())}");
    }

    public static void Run()
    {
        // ── formatting boundaries (spec §2.3) ──
        X("standard", "100000000000.5", "100000000001");        // R10: half away from zero
        X("standard", "999999999999.5", "1000000000000");       // carry into a new digit
        X("standard", "123456789012345", "123456789012000");    // 15 digits, plain
        X("standard", "0.000001", "0.000001");                  // 1e-6 is plain
        X("standard", "0.0000001", "1e-7");                     // below 1e-6 is scientific
        X("standard", "-0", "0");                               // negative zero
        X("standard", "2/3*-1", "-0.666666666667");

        // ── settled amendments (R1–R9) ──
        X("standard", "200 + (10%)", "200.1");                  // R1
        X("standard", "200 + 5 * 10%", "200.5");                // R2
        X("standard", "2^50%", "1.41421356237");                // R3
        X("standard", "50%%", "0.005");                         // R4
        X("standard", "5 of 10", "50");                         // R5
        X("standard", "ANS", "0");                              // R6
        X("standard", "1e5", "!INVALID_EXPRESSION");            // R7
        X("standard", ".", "!INVALID_EXPRESSION");              // R8
        X("standard", "5.5.5", "!INVALID_EXPRESSION");
        X("standard", "10^-400", "0");                          // R9

        // ── malformed standard input ──
        foreach (string bad in new[] { "2 $ 3", "2 3", "sqrt 4", "of 5", "()", "sqrt(", ")", "*", "%", "2 +* 3" })
            X("standard", bad, "!INVALID_EXPRESSION");
        X("standard", "1 / (2 - 2)", "!DIV_BY_ZERO");
        X("standard", "(-8)^(1/3)", "!DOMAIN_ERROR");
        X("standard", new string('(', 100000), "!INVALID_EXPRESSION");   // too long, never a crash
        X("standard", new string('(', 3000) + "1" + new string(')', 3000), "1"); // deep nesting is fine

        // ── programmer: amendments R11–R15, R29, R30, R32 ──
        X("programmer", "A AND F", "DEC=10", "base hex");       // R11
        X("programmer", "DEC", "DEC=3564", "base hex");
        X("programmer", "NOT 0xFF", "DEC=-256");                // R12
        X("programmer", "NOT -1", "DEC=0");
        X("programmer", "1 << 0x3", "!INVALID_SHIFT");          // R13
        X("programmer", "1 << 2.5", "!INVALID_SHIFT");
        X("programmer", "-0x80", "DEC=-128");                   // R14
        X("programmer", "convert FFFFFFFFFFFFFFFF hex dec", "-1"); // R15
        X("programmer", "1<<3", "DEC=8");                       // R29
        X("programmer", "-8>>>1", "DEC=9223372036854775804");
        X("programmer", "0x", "!INVALID_DIGIT");                // R30: bare prefix in dec mode
        X("programmer", "0B", "DEC=11", "base hex");            // R30: 0B in hex mode is the number 11
        X("programmer", "base HEX", "Input base: hex");         // R32
        X("programmer", "-9223372036854775808", "DEC=-9223372036854775808");
        X("programmer", "-9223372036854775809", "!OUT_OF_RANGE");
        X("programmer", "0b102", "!INVALID_DIGIT");
        X("programmer", "1.5", "!INVALID_NUMBER");
        X("programmer", "-", "!INVALID_NUMBER");
        X("programmer", "base", "!INVALID_BASE");
        X("programmer", "convert 1 dec", "!UNKNOWN_COMMAND");
        X("programmer", "5 AND", "!UNKNOWN_COMMAND");
        X("programmer", "NOT", "!UNKNOWN_COMMAND");
        X("programmer", "1 foo 2", "!UNKNOWN_COMMAND");
        X("programmer", new string('F', 5000), "!OUT_OF_RANGE", "base hex");

        // ── converter: amendments R16–R20 ──
        X("converter", "convert 1e3 m cm", "!INVALID_NUMBER");  // R16
        X("converter", "convert " + new string('9', 400) + " m cm", "!OVERFLOW"); // R17
        X("converter", "list foo", "!UNKNOWN_COMMAND");         // R19
        X("converter", "convert -273.16 c all", "!BELOW_ABSOLUTE_ZERO"); // R20
        X("converter", "convert -273.15 c k", "0");             // exactly at the limit is allowed
        X("converter", "convert 1 m", "!UNKNOWN_COMMAND");
        X("converter", "list", "length, mass, area, volume, time, speed, digital, energy, power, pressure, angle, temperature");
        X("converter", "list temperature", "c, f, k");

        // ── unit-table sanity ──
        H.Ok(Units.All.Length == 12, "twelve categories");
        var symbols = Units.All.SelectMany(c => c.Units).Select(u => u.Symbol).ToList();
        H.Ok(symbols.Distinct(StringComparer.OrdinalIgnoreCase).Count() == symbols.Count, "symbols unique");
        H.Ok(Units.All.All(c => c.Name == "temperature" || c.Units.Any(u => u.Factor == 1)), "every category has a base unit");

        Garbage();
        Sessions();
        OneShotCodes();
    }

    // Random junk must only ever produce an ArithmosError, never another exception.
    static void Garbage()
    {
        var rnd = new Random(12345);
        const string chars = "0123456789abcdefxXgG .,+-*/^()%<>&|~!_$'\"\\\t\u00e9\u20ac";
        string[] words = { "AND", "OR", "XOR", "NOT", "base", "hex", "dec", "bin", "oct", "convert", "list",
                           "sqrt(", "abs(", "ans", "of", "kg", "m", "all", "0x", "0b", ">>>", "<<" };

        for (int i = 0; i < 3000; i++)
        {
            var sb = new System.Text.StringBuilder();
            int parts = rnd.Next(0, 8);
            for (int p = 0; p < parts; p++)
            {
                if (rnd.Next(3) == 0) sb.Append(words[rnd.Next(words.Length)]);
                else for (int c = rnd.Next(1, 5); c > 0; c--) sb.Append(chars[rnd.Next(chars.Length)]);
                if (rnd.Next(2) == 0) sb.Append(' ');
            }
            string input = sb.ToString();
            foreach (string tool in new[] { "standard", "programmer", "converter" })
            {
                try { new Session(tool).Run(input); }
                catch (Exception e) { H.Ok(false, $"garbage {tool}: '{input}'", e.GetType().Name + ": " + e.Message); return; }
            }
        }
        H.Ok(true, "garbage input never crashes");
    }

    // Whole sessions through the numbered-list menu.
    static void Sessions()
    {
        var io = new FakeIo { HasSelector = false };
        foreach (string l in new[] { "1", "2 + 3", "10 / 0", "ans", "back", "2", "5 AND 3", "convert 255 dec hex", "back", "quit" })
            io.Lines.Enqueue(l);
        int code = App.RunInteractive(io);
        string o = io.Out.ToString();
        H.Ok(code == 0, "session exit code");
        H.Ok(o.Contains("  1) Standard Calculator") && o.Contains("  0) Exit"), "menu is a numbered list");
        H.Ok(o.Contains("standard> 5\n"), "session: 2 + 3");
        H.Ok(o.Contains("Error [DIV_BY_ZERO]"), "session: error line");
        H.Ok(o.Contains("standard> 5\nstandard> Error [DIV_BY_ZERO]") && o.Contains("standard> Error [DIV_BY_ZERO]: Cannot divide by zero\nstandard> 5\n"),
             "session: ans survives an error");
        H.Ok(o.Contains("DEC: 1") && o.Contains("programmer> FF\n"), "session: programmer");

        // Guided converter: category -> from -> to -> value, then back out.
        var g = new FakeIo { HasSelector = false };
        foreach (string l in new[] { "3", "length", "m", "yd", "100", "back", "back", "back", "back", "quit" })
            g.Lines.Enqueue(l);
        App.RunInteractive(g);
        string go = g.Out.ToString();
        H.Ok(go.Contains("converter (m → yd)> 100 m = 109.361329834 yd"), "guided converter");
        H.Ok(go.Contains("Length — convert from m to"), "guided converter titles");

        // End of input exits cleanly.
        var eof = new FakeIo { HasSelector = false };
        H.Ok(App.RunInteractive(eof) == 0, "EOF exits cleanly");
    }

    // One-shot mode: results to stdout, errors to stderr, status 0 / 1 / 2 (R31).
    static void OneShotCodes()
    {
        (int code, string o, string e) Shot(params string[] args)
        {
            var so = new StringWriter(); var se = new StringWriter();
            int c = App.OneShot(args, so, se);
            return (c, so.ToString().Trim(), se.ToString());
        }

        var a = Shot("std", "2 + 3 * 4");
        H.Ok(a.code == 0 && a.o == "14", "one-shot std");
        var b = Shot("STANDARD", "10 / 0");
        H.Ok(b.code == 1 && b.o == "" && b.e.StartsWith("Error [DIV_BY_ZERO]"), "one-shot error goes to stderr, status 1");
        var c2 = Shot("prog", "0xFF", "AND", "0x0F");
        H.Ok(c2.code == 0 && c2.o.Contains("DEC: 15"), "one-shot prog, joined args");
        var d = Shot("convert", "100", "cm", "in");
        H.Ok(d.code == 0 && d.o == "39.3700787402", "one-shot convert");
        var f = Shot("list", "length");
        H.Ok(f.code == 0 && f.o.StartsWith("pm, ang, nm"), "one-shot list");
        var g = Shot("bogus");
        H.Ok(g.code == 2 && g.e.Contains("Usage"), "bad usage is status 2");
        var h = Shot("std");
        H.Ok(h.code == 2, "missing expression is status 2");
        var i = Shot("--help");
        H.Ok(i.code == 0 && i.o.Contains("Usage"), "--help to stdout");
    }
}