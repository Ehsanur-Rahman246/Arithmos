package arithmos.calculator;

import arithmos.shared.ArithmosError;
import arithmos.shared.ArithmosError.Code;

/**
 * Standard Calculator session. Returns values (the CLI formats them) and holds {@code ans},
 * which changes only after a fully successful evaluation.
 */
public final class Calculator {
    private double ans = 0.0; // "0 before the first calculation" (spec §3.2)

    public double evaluate(String line) {
        if (line == null || line.isBlank()) {
            throw new ArithmosError(Code.INVALID_EXPRESSION, "Nothing to calculate");
        }
        try {
            Node tree = Parser.parse(Tokenizer.tokenize(line));
            double value = new Evaluator(ans).eval(tree);
            ans = value; // only reached when nothing threw
            return value;
        } catch (StackOverflowError e) { // absurdly deep nesting must not crash the program
            throw new ArithmosError(Code.INVALID_EXPRESSION, "The expression is nested too deeply");
        }
    }

    public double ans() {
        return ans;
    }
}