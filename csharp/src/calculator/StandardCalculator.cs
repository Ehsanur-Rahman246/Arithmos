using System.Globalization;
using Arithmos.Shared;

namespace Arithmos.Calculator;

// ───────────────────────────── AST ─────────────────────────────
// Percent is its own node so that "+"/"-" can see a "%" right operand (spec §3.4).
// Parentheses are a Group node, so "200 + (10%)" is a plain 0.1 (amendment R1).
abstract record Node;
sealed record Num(double V) : Node;
sealed record AnsNode : Node;
sealed record Group(Node Inner) : Node;
sealed record Neg(Node Inner) : Node;
sealed record Pos(Node Inner) : Node;
sealed record Pct(Node Inner) : Node;
sealed record Bin(char Op, Node L, Node R) : Node;   // Op: + - * / ^ and 'o' for "of"
sealed record Call(string Fn, Node Arg) : Node;

// ──────────────────────────── Tokenizer ────────────────────────────
enum Tk { Num, Plus, Minus, Star, Slash, Caret, LParen, RParen, Percent, Of, Sqrt, Abs, Ans, End }

sealed record Tok(Tk Type, double Value = 0);

static class Lexer
{
    static ArithmosError Err(string m) => new("INVALID_EXPRESSION", m);

    static bool IsDigit(char c) => c >= '0' && c <= '9';

    public static List<Tok> Tokenize(string s)
    {
        var list = new List<Tok>();
        int i = 0;
        while (i < s.Length)
        {
            char c = s[i];
            if (char.IsWhiteSpace(c)) { i++; continue; }

            // Numbers: 12  12.5  .5  5.   ("1e5" is NOT a number in Release 1; "e" is an unknown word)
            if (IsDigit(c) || c == '.')
            {
                int j = i, dots = 0, digs = 0;
                while (j < s.Length && (IsDigit(s[j]) || s[j] == '.'))
                {
                    if (s[j] == '.') dots++; else digs++;
                    j++;
                }
                if (dots > 1 || digs == 0) throw Err("Unexpected symbol"); // "." or "5.5.5"
                double v = double.Parse(s.AsSpan(i, j - i), NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture);
                if (double.IsInfinity(v)) throw new ArithmosError("OVERFLOW", "The result is too large");
                list.Add(new Tok(Tk.Num, v));
                i = j;
                continue;
            }

            // Words: sqrt abs ans of (case-insensitive)
            if (char.IsLetter(c))
            {
                int j = i;
                while (j < s.Length && char.IsLetter(s[j])) j++;
                string word = s.Substring(i, j - i);
                Tk t = word.ToLowerInvariant() switch
                {
                    "sqrt" => Tk.Sqrt,
                    "abs" => Tk.Abs,
                    "ans" => Tk.Ans,
                    "of" => Tk.Of,
                    _ => Tk.End // sentinel: unknown
                };
                if (t == Tk.End) throw Err($"Unknown word '{word}'");
                list.Add(new Tok(t));
                i = j;
                continue;
            }

            Tk? sym = c switch
            {
                '+' => Tk.Plus, '-' => Tk.Minus, '*' => Tk.Star, '/' => Tk.Slash,
                '^' => Tk.Caret, '(' => Tk.LParen, ')' => Tk.RParen, '%' => Tk.Percent,
                _ => null
            };
            if (sym is null) throw Err($"Unexpected character '{c}'");
            list.Add(new Tok(sym.Value));
            i++;
        }
        list.Add(new Tok(Tk.End));
        return list;
    }
}

// ───────────────────────────── Parser ─────────────────────────────
// Precedence, low to high (spec §3.3):
//   + -   <   * / of   <   unary + -   <   ^ (right-assoc)   <   postfix %   <   ( ) and calls
// The exponent of ^ is a "unary", so "2^-1" works and "2^3^2" is right-associative.
sealed class Parser
{
    const int MaxDepth = 5000; // guards the recursion on hostile input
    readonly List<Tok> t;
    int p, depth;

    public Parser(List<Tok> tokens) => t = tokens;

    Tok Cur => t[p];
    static ArithmosError Err(string m) => new("INVALID_EXPRESSION", m);

    public Node ParseAll()
    {
        if (Cur.Type == Tk.End) throw Err("Nothing to calculate");
        Node n = Expr();
        if (Cur.Type != Tk.End) throw Err("Unexpected symbol"); // leftovers, e.g. "2(3)" or "2 3"
        return n;
    }

    Node Expr()
    {
        Node l = Term();
        while (Cur.Type is Tk.Plus or Tk.Minus)
        {
            char op = Cur.Type == Tk.Plus ? '+' : '-';
            p++;
            l = new Bin(op, l, Term());
        }
        return l;
    }

    Node Term()
    {
        Node l = Unary();
        while (Cur.Type is Tk.Star or Tk.Slash or Tk.Of)
        {
            char op = Cur.Type == Tk.Star ? '*' : Cur.Type == Tk.Slash ? '/' : 'o';
            p++;
            l = new Bin(op, l, Unary());
        }
        return l;
    }

    Node Unary()
    {
        if (++depth > MaxDepth) throw Err("The expression is nested too deeply");
        try
        {
            if (Cur.Type == Tk.Minus) { p++; return new Neg(Unary()); }
            if (Cur.Type == Tk.Plus) { p++; return new Pos(Unary()); }
            return Power();
        }
        finally { depth--; }
    }

    Node Power()
    {
        Node b = Postfix();
        if (Cur.Type == Tk.Caret)
        {
            p++;
            return new Bin('^', b, Unary()); // right-associative via Unary -> Power
        }
        return b;
    }

    Node Postfix()
    {
        Node n = Primary();
        int pct = 0;
        while (Cur.Type == Tk.Percent)
        {
            if (++pct > MaxDepth) throw Err("The expression is nested too deeply");
            p++;
            n = new Pct(n); // "50%%" is allowed (R4)
        }
        return n;
    }

    Node Primary()
    {
        Tok tk = Cur;
        switch (tk.Type)
        {
            case Tk.Num: p++; return new Num(tk.Value);
            case Tk.Ans: p++; return new AnsNode();
            case Tk.LParen:
            {
                p++;
                Node inner = Expr();
                Close();
                return new Group(inner);
            }
            case Tk.Sqrt:
            case Tk.Abs:
            {
                string fn = tk.Type == Tk.Sqrt ? "sqrt" : "abs";
                p++;
                if (Cur.Type != Tk.LParen) throw Err($"{fn} needs parentheses, like {fn}(4)");
                p++;
                Node arg = Expr();
                Close();
                return new Call(fn, arg);
            }
            case Tk.End: throw Err("The expression ends too early");
            case Tk.Of: throw Err("Unexpected 'of'");
            default: throw Err("Unexpected symbol");
        }
    }

    void Close()
    {
        if (Cur.Type == Tk.RParen) { p++; return; }
        if (Cur.Type == Tk.End) throw Err("Missing closing parenthesis");
        throw Err("Unexpected symbol");
    }
}

// ──────────────────────────── Evaluator ────────────────────────────
sealed class Evaluator
{
    readonly double ans;
    public Evaluator(double ans) => this.ans = ans;

    static ArithmosError Fail(string code, string msg) => new(code, msg);

    public double Eval(Node n)
    {
        switch (n)
        {
            case Num x: return x.V;
            case AnsNode: return ans;
            case Group g: return Eval(g.Inner);
            case Neg g: return -Eval(g.Inner);
            case Pos g: return Eval(g.Inner);
            case Pct g: return Eval(g.Inner) / 100.0;   // standalone percent (spec §3.4)
            case Call c: return CallFn(c);
            case Bin b: return BinOp(b);
            default: throw Fail("INVALID_EXPRESSION", "Malformed expression");
        }
    }

    double CallFn(Call c)
    {
        double a = Eval(c.Arg);
        if (c.Fn == "sqrt")
        {
            if (a < 0) throw Fail("DOMAIN_ERROR", "Cannot take the square root of a negative number");
            return Math.Sqrt(a);
        }
        return Math.Abs(a); // abs
    }

    double BinOp(Bin b)
    {
        double l = Eval(b.L);
        double r;
        // A "%" that is the DIRECT right operand of + or - is relative to the left operand.
        if ((b.Op == '+' || b.Op == '-') && b.R is Pct pr)
            r = l * (Eval(pr.Inner) / 100.0);
        else
            r = Eval(b.R);

        double v;
        switch (b.Op)
        {
            case '+': v = l + r; break;
            case '-': v = l - r; break;
            case '*': v = l * r; break;
            case 'o': v = l * r; break; // "of" is sugar for "*"
            case '/':
                if (r == 0) throw Fail("DIV_BY_ZERO", "Cannot divide by zero");
                v = l / r;
                break;
            case '^': v = Pow(l, r); break;
            default: throw Fail("INVALID_EXPRESSION", "Malformed expression");
        }
        return Check(v);
    }

    static double Pow(double l, double r)
    {
        if (l == 0 && r == 0) throw Fail("UNDEFINED", "0^0 is undefined");
        if (l == 0 && r < 0) throw Fail("DIV_BY_ZERO", "Zero cannot be raised to a negative power");
        if (l < 0 && r != Math.Floor(r)) throw Fail("DOMAIN_ERROR", "A negative number cannot have a fractional power");
        return Math.Pow(l, r); // 10^-400 underflows to 0 without an error (R9)
    }

    // NaN and Infinity are never shown (spec §2.3 rule 5).
    static double Check(double v)
    {
        if (double.IsInfinity(v)) throw Fail("OVERFLOW", "The result is too large");
        if (double.IsNaN(v)) throw Fail("DOMAIN_ERROR", "The result is not a number");
        return v;
    }
}

// ───────────────────────────── Session ─────────────────────────────
/// <summary>
/// Standard Calculator session. Holds <c>ans</c>, which changes only after a
/// fully successful evaluation (spec §3.1, case S33).
/// </summary>
public sealed class StandardCalculator
{
    // Runtime limits: hostile input must never crash the process.
    const int MaxLength = 20_000;
    const int StackBytes = 64 * 1024 * 1024; // evaluation runs on a big-stack thread

    double ans;

    public string Evaluate(string expression)
    {
        if (expression.Length > MaxLength)
            throw new ArithmosError("INVALID_EXPRESSION", "The expression is too long");

        double value = 0;
        string text = "";
        Exception? failure = null;

        // Deeply nested input recurses deeply; a 64 MB stack makes that safe.
        var worker = new Thread(() =>
        {
            try
            {
                Node tree = new Parser(Lexer.Tokenize(expression)).ParseAll();
                value = new Evaluator(ans).Eval(tree);
                text = FormatNumber.Format(value); // may throw OVERFLOW, so format BEFORE touching ans
            }
            catch (Exception e) { failure = e; }
        }, StackBytes);
        worker.Start();
        worker.Join();

        if (failure != null) throw failure;
        ans = value;
        return text;
    }
}