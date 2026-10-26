using System.Globalization;
using System.Text.RegularExpressions;
using Arithmos.Shared;

namespace Arithmos.Converter;

/// <summary>
/// Unit Converter engine (spec §5). Pure logic: no I/O. Throws ArithmosError.
/// Conversion is value × from.factor ÷ to.factor; temperature goes through °C.
/// </summary>
public sealed class UnitConverter
{
    // A plain decimal: 12  -3.5  .5  5.   (no exponent, no separators; R16)
    static readonly Regex NumberRx = new(@"^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)$", RegexOptions.CultureInvariant);

    public IReadOnlyList<Category> Categories => Units.All;

    static ArithmosError Err(string code, string msg) => new(code, msg);

    /// <summary>One line: "convert 100 cm in", "100 cm in", "list", "list length".</summary>
    public string Execute(string raw)
    {
        string[] w = raw.Trim().Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (w.Length == 0) throw Err("UNKNOWN_COMMAND", "Type a value, e.g. 100");
        string w0 = w[0].ToLowerInvariant();

        if (w0 == "list")
        {
            if (w.Length == 1) return string.Join(", ", Units.All.Select(c => c.Name));
            if (w.Length > 2) throw Err("UNKNOWN_COMMAND", "Use: list  or  list <category>");
            Category? cat = Units.All.FirstOrDefault(c => c.Name.Equals(w[1], StringComparison.OrdinalIgnoreCase));
            if (cat == null) throw Err("UNKNOWN_COMMAND", $"'{w[1]}' is not a category. Try: list");
            return string.Join(", ", cat.Units.Select(u => u.Symbol));
        }

        if (w0 == "convert")
        {
            if (w.Length != 4) throw Err("UNKNOWN_COMMAND", "Use: convert <value> <from> <to>");
            return ConvertValue(w[1], w[2], w[3]);
        }

        if (w.Length == 3) return ConvertValue(w[0], w[1], w[2]); // "convert" is optional

        throw Err("UNKNOWN_COMMAND", "Not a command. Try: convert 100 cm in");
    }

    /// <summary>
    /// Converts a typed value. <paramref name="to"/> may be "all": one "symbol: value" line per unit
    /// of the source's category, in table order. Any overflow fails the whole command (R18).
    /// </summary>
    public string ConvertValue(string valueText, string from, string to)
    {
        var src = Units.Find(from) ?? throw Err("UNKNOWN_UNIT", $"'{from}' is not a known unit. Try: list");
        bool all = to.Equals("all", StringComparison.OrdinalIgnoreCase);

        Category targetCat = src.Cat;
        Unit? target = null;
        if (!all)
        {
            var dst = Units.Find(to) ?? throw Err("UNKNOWN_UNIT", $"'{to}' is not a known unit. Try: list");
            if (dst.Cat.Name != src.Cat.Name)
                throw Err("INCOMPATIBLE_UNITS", $"Cannot convert {src.Cat.Name} to {dst.Cat.Name}");
            targetCat = dst.Cat;
            target = dst.Unit;
        }

        double v = ParseValue(valueText);
        bool temperature = src.Cat.Name == "temperature";
        if (temperature) CheckAbsoluteZero(src.Unit.Symbol, v);

        if (!all) return FormatNumber.Format(Calc(v, src.Unit, target!, temperature));

        // Compute every line first so an overflow fails before anything is returned.
        string[] lines = targetCat.Units
            .Select(u => $"{u.Symbol}: {FormatNumber.Format(Calc(v, src.Unit, u, temperature))}")
            .ToArray();
        return string.Join("\n", lines);
    }

    static double ParseValue(string text)
    {
        if (!NumberRx.IsMatch(text)) throw Err("INVALID_NUMBER", $"'{text}' is not a number");
        double v = double.Parse(text, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint,
                                CultureInfo.InvariantCulture);
        if (double.IsInfinity(v)) throw Err("OVERFLOW", "That number is too large");
        return v;
    }

    static double Calc(double v, Unit from, Unit to, bool temperature)
    {
        double result = temperature
            ? FromCelsius(to.Symbol, ToCelsius(from.Symbol, v))
            : v * from.Factor / to.Factor;
        if (double.IsInfinity(result) || double.IsNaN(result))
            throw Err("OVERFLOW", "Result is too large to represent");
        return result;
    }

    // Exactly at the limit (0 K, -273.15 C, -459.67 F) is allowed (R20).
    static void CheckAbsoluteZero(string symbol, double v)
    {
        bool below = symbol.ToLowerInvariant() switch
        {
            "c" => v < -273.15,
            "f" => v < -459.67,
            _ => v < 0 // k
        };
        if (below) throw Err("BELOW_ABSOLUTE_ZERO", "That is below absolute zero");
    }

    static double ToCelsius(string symbol, double v) => symbol.ToLowerInvariant() switch
    {
        "f" => (v - 32) * 5 / 9,
        "k" => v - 273.15,
        _ => v
    };

    static double FromCelsius(string symbol, double c) => symbol.ToLowerInvariant() switch
    {
        "f" => c * 9 / 5 + 32,
        "k" => c + 273.15,
        _ => c
    };
}