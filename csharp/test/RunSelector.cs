using Arithmos.Cli;

namespace Arithmos.Tests;

/// <summary>
/// Selector tests SL1–SL21 (same numbers as every edition), plus X2 (drawing limits) and
/// X3 (ConsoleKeyInfo becomes keys). See docs/test-cases.md.
/// </summary>
public static class RunSelector
{
    static readonly HashSet<int> Seen = new();

    static void Sl(int n, bool ok, string detail = "")
    {
        Seen.Add(n);
        H.Ok(ok, $"SL{n}", detail);
    }

    static Key K(KeyKind k) => new(k);
    static Key C(char c) => new(KeyKind.Char, c);

    static readonly SelOptions AllKeys = new(true, true, true);
    static readonly SelOptions NoKeys = new(false, false, false);

    static string[] Labels(int n) => Enumerable.Range(0, n).Select(i => $"item{i:00}").ToArray();

    static int Count(string hay, string needle)
    {
        int c = 0, i = 0;
        while ((i = hay.IndexOf(needle, i, StringComparison.Ordinal)) >= 0) { c++; i += needle.Length; }
        return c;
    }

    static readonly PickOption[] Opts =
    {
        new("Alpha", "a", new[] { "al" }),
        new("Beta", "b"),
        new("Gamma", "g"),
    };

    public static void Run()
    {
        // SL1: up/down move, wrap around, home/end
        {
            var s = new SelState(5) { Window = 10 };
            Selector.Handle(s, K(KeyKind.Up), AllKeys);
            bool wrapUp = s.Index == 4;
            Selector.Handle(s, K(KeyKind.Down), AllKeys);
            bool wrapDown = s.Index == 0;
            Selector.Handle(s, K(KeyKind.End), AllKeys);
            bool end = s.Index == 4;
            Selector.Handle(s, K(KeyKind.Home), AllKeys);
            Sl(1, wrapUp && wrapDown && end && s.Index == 0);
        }

        // SL2: long lists scroll in a window of 10
        {
            var s = new SelState(25) { Window = 10 };
            for (int i = 0; i < 12; i++) Selector.Handle(s, K(KeyKind.Down), AllKeys);
            var lines = Selector.Render("T", Labels(25), s, AllKeys, 60, false);
            string text = string.Join("\n", lines);
            var short5 = Selector.Render("T", Labels(5), new SelState(5) { Window = 10 }, AllKeys, 60, false);
            Sl(2, s.Index == 12 && lines.Count == 12 && text.Contains("item12") && !text.Contains("item02") && short5.Count == 7);
        }

        // SL3: Enter selects; Esc / b / q only work when offered
        {
            var s = new SelState(3) { Window = 10 };
            Selector.Handle(s, K(KeyKind.Down), NoKeys);
            var enter = Selector.Handle(s, K(KeyKind.Enter), NoKeys);
            bool ok = enter is { Kind: SelKind.Chosen, Index: 1 }
                   && Selector.Handle(s, K(KeyKind.Esc), NoKeys) == null
                   && Selector.Handle(s, C('b'), NoKeys) == null
                   && Selector.Handle(s, C('q'), NoKeys) == null
                   && Selector.Handle(s, K(KeyKind.Esc), new SelOptions(true, false, false)) is { Kind: SelKind.Back }
                   && Selector.Handle(s, C('q'), new SelOptions(false, true, false)) is { Kind: SelKind.Quit };
            Sl(3, ok);
        }

        // SL4: Ctrl-C / Ctrl-D abort; other control keys are ignored
        {
            var s = new SelState(3) { Window = 10 };
            Sl(4, Selector.Handle(s, K(KeyKind.CtrlC), NoKeys) is { Kind: SelKind.Abort }
               && Selector.Handle(s, K(KeyKind.CtrlD), NoKeys) is { Kind: SelKind.Abort }
               && Selector.Handle(s, K(KeyKind.Other), AllKeys) == null);
        }

        // SL5: typing on: a printable key ends the selector and carries the character
        Sl(5, Selector.Handle(new SelState(3), C('x'), AllKeys) is { Kind: SelKind.Typed, Ch: 'x' });

        // SL6: typing off: printable keys are ignored
        Sl(6, Selector.Handle(new SelState(3), C('x'), NoKeys) == null);

        // SL7: typing on: Esc, b, q, arrows and Enter keep their meaning
        {
            var s = new SelState(3) { Window = 10 };
            bool ok = Selector.Handle(s, K(KeyKind.Esc), AllKeys) is { Kind: SelKind.Back }
                   && Selector.Handle(s, C('b'), AllKeys) is { Kind: SelKind.Back }
                   && Selector.Handle(s, C('q'), AllKeys) is { Kind: SelKind.Quit }
                   && Selector.Handle(s, K(KeyKind.Down), AllKeys) == null && s.Index == 1
                   && Selector.Handle(s, K(KeyKind.Enter), AllKeys) is { Kind: SelKind.Chosen, Index: 1 };
            Sl(7, ok);
        }

        // SL8: typing on: space and control keys do not start a typed line
        Sl(8, Selector.Handle(new SelState(3), C(' '), AllKeys) == null
           && Selector.Handle(new SelState(3), K(KeyKind.Other), AllKeys) == null);

        // SL9: the selected row is highlighted as a full bar
        {
            var lines = Selector.Render("T", Labels(3), new SelState(3) { Window = 10 }, NoKeys, 40, true);
            string row = lines[1];
            Sl(9, row.StartsWith("\u001b[7m") && row.EndsWith("\u001b[0m") && row.Length - 8 == 39);
        }

        // SL10: plain mode still marks the selected row with the pointer
        {
            var lines = Selector.Render("T", Labels(3), new SelState(3) { Window = 10 }, NoKeys, 40, false);
            Sl(10, lines[1].StartsWith("❯ ") && !lines[1].Contains('\u001b') && lines[2].StartsWith("  "));
        }

        // SL11: hint line lists only the keys on offer
        {
            string hint = Selector.Hint(NoKeys);
            Sl(11, hint.Contains("Enter") && !hint.Contains("Esc") && !hint.Contains("quit") && !hint.Contains("type"));
        }

        // SL12: hint shows Esc/b back and "or type" when typing is on
        {
            string hint = Selector.Hint(new SelOptions(true, false, true));
            Sl(12, hint.Contains("Esc/b back") && hint.Contains("or type") && !hint.Contains("quit")
               && Selector.Hint(AllKeys).Contains("q quit"));
        }

        // SL13: loop: keys in, index out, summary left behind, cursor restored
        {
            var keys = new FakeKeys(K(KeyKind.Down), K(KeyKind.Down), K(KeyKind.Enter));
            var scr = new FakeScreen();
            var r = Selector.Run(keys, scr, "T", new[] { "a", "b", "c" }, NoKeys);
            string o = scr.Out.ToString();
            Sl(13, r is { Kind: SelKind.Chosen, Index: 2 } && o.Contains("✔ T: c")
               && o.EndsWith(Selector.ShowCursor) && keys.Entered == 1 && keys.Left == 1);
        }

        // SL14: loop: Esc, ignored keys, Ctrl-C
        {
            var k1 = new FakeKeys(K(KeyKind.Other), K(KeyKind.Esc));
            var s1 = new FakeScreen();
            var r1 = Selector.Run(k1, s1, "T", new[] { "a", "b" }, new SelOptions(true, false, false));
            var k2 = new FakeKeys(K(KeyKind.CtrlC));
            var s2 = new FakeScreen();
            var r2 = Selector.Run(k2, s2, "T", new[] { "a", "b" }, NoKeys);
            Sl(14, r1.Kind == SelKind.Back && !s1.Out.ToString().Contains("✔") && k1.Left == 1
               && r2.Kind == SelKind.Abort && s2.Out.ToString().EndsWith(Selector.ShowCursor) && k2.Left == 1);
        }

        // SL15: loop: a typed key returns its character and restores the cursor
        {
            var keys = new FakeKeys(C('x'));
            var scr = new FakeScreen();
            var r = Selector.Run(keys, scr, "T", new[] { "a", "b" }, AllKeys);
            Sl(15, r is { Kind: SelKind.Typed, Ch: 'x' } && scr.Out.ToString().EndsWith(Selector.ShowCursor)
               && keys.Left == 1);
        }

        // SL16: pick() uses the selector when present and maps its results
        {
            PickResult Pk(SelOutcome o)
            {
                var io = new FakeIo { HasSelector = true };
                io.Sel.Enqueue(o);
                return Pick.Ask(io, "Menu", Opts, true, true, "help");
            }
            var chosen = Pk(new SelOutcome(SelKind.Chosen, 1));
            Sl(16, chosen is { Kind: PickKind.Chosen, Id: "b" }
               && Pk(new SelOutcome(SelKind.Back)).Kind == PickKind.Back
               && Pk(new SelOutcome(SelKind.Quit)).Kind == PickKind.Quit
               && Pk(new SelOutcome(SelKind.Abort)).Kind == PickKind.Eof);
        }

        // SL17: pick(): a typed name or number selects it
        {
            PickResult Pk(string typed)
            {
                var io = new FakeIo { HasSelector = false };
                io.Lines.Enqueue(typed);
                return Pick.Ask(io, "Menu", Opts, true, true, "help");
            }
            Sl(17, Pk("al").Id == "a" && Pk("2").Id == "b" && Pk("GAMMA").Id == "g");
        }

        // SL18: pick(): a typed one-line command runs and the list comes back
        {
            var io = new FakeIo { HasSelector = false };
            io.Lines.Enqueue("cmd x"); io.Lines.Enqueue("3");
            string? seen = null;
            bool Try(string l) { if (l == "cmd x") { seen = l; return true; } return false; }
            var r = Pick.Ask(io, "Menu", Opts, true, true, "help", Try);
            Sl(18, seen == "cmd x" && r.Id == "g" && Count(io.Out.ToString(), "  1) Alpha") == 2);
        }

        // SL19: pick(): an unknown typed word is an error and the list comes back
        {
            var io = new FakeIo { HasSelector = false };
            io.Lines.Enqueue("zzz"); io.Lines.Enqueue("1");
            var r = Pick.Ask(io, "Menu", Opts, true, true, "help");
            string o = io.Out.ToString();
            Sl(19, r.Id == "a" && o.Contains("Error [UNKNOWN_COMMAND]: Pick one from the list") && Count(o, "  1) Alpha") == 2);
        }

        // SL20: pick(): b, q and Esc act at once, with no prompt line
        {
            var io = new FakeIo { HasSelector = true };
            io.Sel.Enqueue(new SelOutcome(SelKind.Back));
            io.Sel.Enqueue(new SelOutcome(SelKind.Quit));
            var back = Pick.Ask(io, "Menu", Opts, true, true, "help");
            var quit = Pick.Ask(io, "Menu", Opts, true, true, "help");

            // A typed key opens a prompt that already shows the key.
            var typed = new FakeIo { HasSelector = true };
            typed.Sel.Enqueue(new SelOutcome(SelKind.Typed, -1, 'a'));
            typed.Lines.Enqueue("al");
            var t = Pick.Ask(typed, "Menu", Opts, true, true, "help");

            Sl(20, back.Kind == PickKind.Back && quit.Kind == PickKind.Quit && io.ReadCalls == 0
               && t.Id == "a" && typed.LastPrefill == "a");
        }

        // SL21: pick(): without a selector (pipes) the numbered list works as before
        {
            var io = new FakeIo { HasSelector = false };
            io.Lines.Enqueue("1");
            var r = Pick.Ask(io, "Menu", Opts, false, true, "help");
            string o = io.Out.ToString();
            Sl(21, r.Id == "a" && o.Contains("Menu\n  1) Alpha\n  2) Beta\n  3) Gamma\n"));
        }

        // X2: lines never wider than the terminal; the window shrinks on a short terminal;
        //     erase moves up by the drawn line count
        {
            var longLabels = new[] { new string('x', 50), "short" };
            var lines = Selector.Render("T", longLabels, new SelState(2) { Window = 10 }, NoKeys, 20, false);
            bool narrow = lines.All(l => l.Length <= 19) && lines[1].EndsWith("…");

            var keys = new FakeKeys(K(KeyKind.Esc));
            var scr = new FakeScreen(30, 8);
            Selector.Run(keys, scr, "T", Labels(20), new SelOptions(true, false, false));
            // window = min(10, 20, 8 - 3) = 5, so 7 lines are drawn and erased
            bool shrunk = scr.Out.ToString().Contains(Selector.Erase(7));

            H.Ok(narrow && shrunk && Selector.Erase(7) == "\u001b[7A\r\u001b[J", "X2");
        }

        // X3: ConsoleKeyInfo becomes keys (arrows, Esc, Home/End, PgUp/PgDn, Ctrl-C/D, printable, ignored)
        {
            static ConsoleKeyInfo I(char ch, ConsoleKey k, bool ctrl = false) => new(ch, k, false, false, ctrl);
            bool ok =
                KeyParser.FromConsole(I('\0', ConsoleKey.UpArrow)).Kind == KeyKind.Up
                && KeyParser.FromConsole(I('\0', ConsoleKey.DownArrow)).Kind == KeyKind.Down
                && KeyParser.FromConsole(I('\0', ConsoleKey.Home)).Kind == KeyKind.Home
                && KeyParser.FromConsole(I('\0', ConsoleKey.End)).Kind == KeyKind.End
                && KeyParser.FromConsole(I('\0', ConsoleKey.PageUp)).Kind == KeyKind.PageUp
                && KeyParser.FromConsole(I('\0', ConsoleKey.PageDown)).Kind == KeyKind.PageDown
                && KeyParser.FromConsole(I('\r', ConsoleKey.Enter)).Kind == KeyKind.Enter
                && KeyParser.FromConsole(I('\u001b', ConsoleKey.Escape)).Kind == KeyKind.Esc
                && KeyParser.FromConsole(I('\u0003', ConsoleKey.C, true)).Kind == KeyKind.CtrlC
                && KeyParser.FromConsole(I('\u0004', ConsoleKey.D, true)).Kind == KeyKind.CtrlD
                && KeyParser.FromConsole(I('x', ConsoleKey.X)) == new Key(KeyKind.Char, 'x')
                && KeyParser.FromConsole(I('é', ConsoleKey.E)) == new Key(KeyKind.Char, 'é')
                && KeyParser.FromConsole(I('\t', ConsoleKey.Tab)).Kind == KeyKind.Other
                && KeyParser.FromConsole(I('\0', ConsoleKey.F1)).Kind == KeyKind.Other;
            H.Ok(ok, "X3");
        }

        // Every edition must run all 21 numbered tests.
        H.Ok(Enumerable.Range(1, 21).All(Seen.Contains), "SL1–SL21 all ran");
    }
}