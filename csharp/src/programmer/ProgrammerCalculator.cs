using System.Globalization;
using System.Numerics;
using System.Text.RegularExpressions;
using Arithmos.Shared;

namespace Arithmos.Programmer;

// What one command produced. The CLI turns these into text.
public abstract record ProgResult;
/// <summary>A value to show in all four bases.</summary>
public sealed record ValueResult(long Value) : ProgResult;
/// <summary>Plain text (the result of a base conversion).</summary>
public sealed record TextResult(string Text) : ProgResult;
/// <summary>The input base was changed (canonical lower-case name, amendment R32).</summary>
public sealed record BaseResult(string Name) : ProgResult;

/// <summary>
/// Programmer Calculator: signed 64-bit two's complement, spec §4.
/// C# <c>long</c> already wraps like that; <c>&gt;&gt;</c> is arithmetic and <c>&gt;&gt;&gt;</c> logical.
/// Literals go through BigInteger so range checks are exact and nothing passes through double.
/// </summary>
public sealed class ProgrammerCalculator
{
    // "<left> <op> <count>", spaces optional (R29). ">>>" must come before ">>" in the alternation.
    static readonly Regex ShiftRx =
        new(@"^(.+?)\s*(>>>|>>|<<)\s*(.+)$", RegexOptions.CultureInvariant | RegexOptions.Singleline);

    int radix = 10; // current input base

    public string InputBase => NameOf(radix);

    static ArithmosError Err(string code, string msg) => new(code, msg);

    // ───────────── bases ─────────────
    static int? RadixOf(string name) => name.ToLowerInvariant() switch
    {
        "bin" => 2,
        "oct" => 8,
        "dec" => 10,
        "hex" => 16,
        _ => (int?)null
    };

    static string NameOf(int r) => r switch { 2 => "bin", 8 => "oct", 10 => "dec", _ => "hex" };

    static int BaseOrThrow(string name) =>
        RadixOf(name) ?? throw Err("INVALID_BASE", $"'{name}' is not a base. Use bin, oct, dec or hex");

    // ───────────── literals (spec §4.3) ─────────────
    static bool IsAsciiAlnum(char c) =>
        (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');

    static int DigitValue(char c) =>
        c <= '9' ? c - '0' : char.ToUpperInvariant(c) - 'A' + 10;

    /// <summary>Order: prefix overrides the base -> digit validation -> range.</summary>
    public static long ParseLiteral(string input, int radix)
    {
        string s = input.Trim();
        bool neg = s.StartsWith('-');
        string body = neg ? s[1..] : s;
        if (body.Length == 0) throw Err("INVALID_NUMBER", $"'{input}' is not a number");

        // A prefix counts only when digits follow it (R30): "0B" in hex mode is the number 11.
        if (body.Length > 2 && body[0] == '0')
        {
            int? pr = char.ToLowerInvariant(body[1]) switch
            {
                'b' => 2, 'o' => 8, 'd' => 10, 'x' => 16, _ => (int?)null
            };
            if (pr != null) { radix = pr.Value; body = body[2..]; }
        }

        // Garbage (".", "!", unicode ...) is INVALID_NUMBER; wrong digits are INVALID_DIGIT.
        foreach (char c in body)
            if (!IsAsciiAlnum(c)) throw Err("INVALID_NUMBER", $"'{input}' is not a number");
        foreach (char c in body)
            if (DigitValue(c) >= radix)
                throw Err("INVALID_DIGIT", $"'{char.ToUpperInvariant(c)}' is not a {NameOf(radix)} digit");

        string digits = body.TrimStart('0');
        if (digits.Length == 0) return 0;

        bool signedRule = neg || radix == 10; // decimal and negated literals must fit the signed range
        string tooBig = signedRule ? "That number does not fit in 64 bits" : "That number needs more than 64 bits";
        if (digits.Length > 70) throw Err("OUT_OF_RANGE", tooBig); // cannot fit in 64 bits in any base

        BigInteger mag = BigInteger.Zero;
        foreach (char c in digits) mag = mag * radix + DigitValue(c);

        BigInteger two63 = BigInteger.One << 63;
        BigInteger two64 = BigInteger.One << 64;

        if (signedRule)
        {
            BigInteger limit = neg ? two63 : two63 - 1;
            if (mag > limit) throw Err("OUT_OF_RANGE", tooBig);
            return (long)(neg ? -mag : mag);
        }

        // Bin/oct/hex without a minus: a raw 64-bit pattern reinterpreted as signed.
        if (mag >= two64) throw Err("OUT_OF_RANGE", tooBig);
        return unchecked((long)(ulong)mag);
    }

    // ───────────── output (spec §4.4) ─────────────
    /// <summary>Convert.ToString on a negative long prints the full 64-bit pattern, which is the spec's rule.</summary>
    public static string ToBase(long v, int radix) =>
        radix == 10
            ? v.ToString(CultureInfo.InvariantCulture)
            : System.Convert.ToString(v, radix).ToUpperInvariant();

    /// <summary>The four lines shown for a value, in display order.</summary>
    public static (string Hex, string Dec, string Oct, string Bin) Describe(long v) =>
        (ToBase(v, 16), ToBase(v, 10), ToBase(v, 8), ToBase(v, 2));

    // ───────────── commands (spec §4.5) ─────────────
    public ProgResult Execute(string raw)
    {
        string line = raw.Trim();
        if (line.Length == 0) throw Err("UNKNOWN_COMMAND", "Type a number or a command. Try help");

        // Shifts first: "1<<3" has no spaces to split on (R29). The count is always decimal.
        Match m = ShiftRx.Match(line);
        if (m.Success) return Shift(m.Groups[1].Value.Trim(), m.Groups[2].Value, m.Groups[3].Value.Trim());

        string[] w = line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        string w0 = w[0].ToLowerInvariant();

        if (w0 == "base")
        {
            if (w.Length != 2) throw Err("INVALID_BASE", "Use: base bin | oct | dec | hex");
            radix = BaseOrThrow(w[1]);
            return new BaseResult(NameOf(radix));
        }

        if (w0 == "convert")
        {
            if (w.Length != 4) throw Err("UNKNOWN_COMMAND", "Use: convert <value> <from> <to>");
            return DoConvert(w[1], w[2], w[3]);
        }

        if (w0 == "not")
        {
            if (w.Length != 2) throw Err("UNKNOWN_COMMAND", "Use: NOT <value>");
            return new ValueResult(~ParseLiteral(w[1], radix));
        }

        if (w.Length == 3)
        {
            // The operator is always the MIDDLE word, so hex digits like "AND"'s "A" never clash (R11).
            string op = w[1].ToLowerInvariant();
            if (op is "and" or "or" or "xor")
            {
                long a = ParseLiteral(w[0], radix);
                long b = ParseLiteral(w[2], radix);
                return new ValueResult(op switch { "and" => a & b, "or" => a | b, _ => a ^ b });
            }
            // "255 dec hex": the word "convert" is optional (R24).
            if (RadixOf(w[1]) != null && RadixOf(w[2]) != null) return DoConvert(w[0], w[1], w[2]);
        }

        if (w.Length == 1) return new ValueResult(ParseLiteral(w[0], radix));

        throw Err("UNKNOWN_COMMAND", "Not a command. Try help");
    }

    ProgResult DoConvert(string value, string from, string to)
    {
        int fr = BaseOrThrow(from);
        int tr = BaseOrThrow(to);
        // The explicit "from" base reads the value, independent of the current input base.
        return new TextResult(ToBase(ParseLiteral(value, fr), tr));
    }

    ProgResult Shift(string left, string op, string countText)
    {
        long a = ParseLiteral(left, radix);

        // Count: plain decimal 0..63. "-1", "2.5", "0x3", "64" are all INVALID_SHIFT (R13).
        if (!int.TryParse(countText, NumberStyles.None, CultureInfo.InvariantCulture, out int n) || n < 0 || n > 63)
            throw Err("INVALID_SHIFT", "A shift count must be a whole number from 0 to 63");

        long result = op switch
        {
            "<<" => a << n,   // bits past bit 63 are discarded, no error
            ">>" => a >> n,   // arithmetic: sign-extending
            _ => a >>> n      // logical: zero-filling (C# 11)
        };
        return new ValueResult(result);
    }
}