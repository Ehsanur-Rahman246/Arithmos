namespace Arithmos.Cli;

/// <summary>Turns a .NET ConsoleKeyInfo into a Key (pure, so tests can cover it: X3).</summary>
public static class KeyParser
{
    public static Key FromConsole(ConsoleKeyInfo ki)
    {
        char ch = ki.KeyChar;
        bool ctrl = (ki.Modifiers & ConsoleModifiers.Control) != 0;

        if ((ctrl && ki.Key == ConsoleKey.C) || ch == '\u0003') return new Key(KeyKind.CtrlC);
        if ((ctrl && ki.Key == ConsoleKey.D) || ch == '\u0004') return new Key(KeyKind.CtrlD);

        switch (ki.Key)
        {
            case ConsoleKey.UpArrow: return new Key(KeyKind.Up);
            case ConsoleKey.DownArrow: return new Key(KeyKind.Down);
            case ConsoleKey.Home: return new Key(KeyKind.Home);
            case ConsoleKey.End: return new Key(KeyKind.End);
            case ConsoleKey.PageUp: return new Key(KeyKind.PageUp);
            case ConsoleKey.PageDown: return new Key(KeyKind.PageDown);
            case ConsoleKey.Enter: return new Key(KeyKind.Enter);
            case ConsoleKey.Escape: return new Key(KeyKind.Esc);
        }

        // Function keys, Tab, Backspace and other control keys carry no printable character.
        if (ch == '\0' || char.IsControl(ch)) return new Key(KeyKind.Other);
        return new Key(KeyKind.Char, ch); // includes non-ASCII printable characters
    }
}