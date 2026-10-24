package arithmos.calculator;

import arithmos.shared.ArithmosError;
import arithmos.shared.ArithmosError.Code;

/** Step 3: walk the AST with IEEE doubles. Every operation result is checked for Infinity/NaN. */
final class Evaluator {
    private final double ans;

    Evaluator(double ans) {
        this.ans = ans;
    }

    double eval(Node node) {
        return switch (node) {
            case Node.Num n -> n.value();
            case Node.Ans _ -> ans;
            case Node.Group g -> eval(g.inner());
            case Node.Percent p -> eval(p.operand()) / 100.0; // standalone percent (spec §3.4)
            case Node.Unary u -> u.op() == '-' ? -eval(u.operand()) : eval(u.operand());
            case Node.Call c -> call(c);
            case Node.Binary b -> binary(b);
        };
    }

    private double binary(Node.Binary b) {
        double l = eval(b.left());
        double r;
        if ((b.op() == '+' || b.op() == '-') && b.right() instanceof Node.Percent p) {
            // A % that is the DIRECT right operand of + or - is relative to the left side.
            // Parentheses (Group), negation and every other operator break that, so
            // "200 + (10%)" is plain: 200.1.
            r = l * (eval(p.operand()) / 100.0);
        } else {
            r = eval(b.right());
        }
        double result = switch (b.op()) {
            case '+' -> l + r;
            case '-' -> l - r;
            case '*' -> l * r;
            case '/' -> {
                if (r == 0.0) throw new ArithmosError(Code.DIV_BY_ZERO, "Cannot divide by zero");
                yield l / r;
            }
            case '^' -> power(l, r);
            default -> throw new ArithmosError(Code.INVALID_EXPRESSION, "Unknown operator " + b.op());
        };
        return check(result);
    }

    /** Spec §3.5 power rules. 10^-400 quietly becomes 0 (amendment R9). */
    private static double power(double base, double exp) {
        if (base == 0.0 && exp == 0.0) {
            throw new ArithmosError(Code.UNDEFINED, "0^0 is undefined");
        }
        if (base == 0.0 && exp < 0.0) {
            throw new ArithmosError(Code.DIV_BY_ZERO, "Zero cannot be raised to a negative power");
        }
        if (base < 0.0 && exp != Math.rint(exp)) {
            throw new ArithmosError(Code.DOMAIN_ERROR, "A negative number cannot have a fractional power");
        }
        return Math.pow(base, exp);
    }

    private double call(Node.Call c) {
        double x = eval(c.arg());
        return check(switch (c.fn()) {
            case "sqrt" -> {
                if (x < 0.0) {
                    throw new ArithmosError(Code.DOMAIN_ERROR, "Cannot take the square root of a negative number");
                }
                yield Math.sqrt(x);
            }
            case "abs" -> Math.abs(x);
            default -> throw new ArithmosError(Code.INVALID_EXPRESSION, "Unknown word '" + c.fn() + "'");
        });
    }

    /** NaN and Infinity never reach the user. */
    private static double check(double v) {
        if (Double.isInfinite(v)) throw new ArithmosError(Code.OVERFLOW, "The result is too large");
        if (Double.isNaN(v)) throw new ArithmosError(Code.DOMAIN_ERROR, "The result is not a number");
        return v;
    }
}