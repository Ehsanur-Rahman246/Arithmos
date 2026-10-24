package arithmos.calculator;

import arithmos.shared.ArithmosError;
import arithmos.shared.ArithmosError.Code;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/** Step 1 of the pipeline (tokenize → parse → evaluate → format): text into tokens. */
final class Tokenizer {
    enum Type { NUM, PLUS, MINUS, STAR, SLASH, CARET, LPAREN, RPAREN, PERCENT, OF, ANS, FUNC, END }

    /** {@code value} is only meaningful for NUM tokens; {@code text} for FUNC is lower-cased. */
    record Token(Type type, String text, double value) {}

    private Tokenizer() {}

    static List<Token> tokenize(String src) {
        List<Token> out = new ArrayList<>();
        int i = 0;
        int n = src.length();
        while (i < n) {
            char c = src.charAt(i);
            if (Character.isWhitespace(c)) {
                i++;
            } else if (isDigit(c) || c == '.') {
                // Numbers: 12  12.5  .5  5.   ("1e5" is not supported: the "e" becomes a word)
                int j = i;
                int dots = 0;
                int digits = 0;
                while (j < n && (isDigit(src.charAt(j)) || src.charAt(j) == '.')) {
                    if (src.charAt(j) == '.') dots++; else digits++;
                    j++;
                }
                if (dots > 1 || digits == 0) { // "5.5.5" and a lone "."
                    throw new ArithmosError(Code.INVALID_EXPRESSION, "Unexpected character '.'");
                }
                String text = src.substring(i, j);
                double v = Double.parseDouble(text);
                if (Double.isInfinite(v)) {
                    throw new ArithmosError(Code.OVERFLOW, "That number is too large");
                }
                out.add(new Token(Type.NUM, text, v));
                i = j;
            } else if (Character.isLetter(c)) {
                int j = i;
                while (j < n && Character.isLetter(src.charAt(j))) j++;
                String word = src.substring(i, j);
                String lower = word.toLowerCase(Locale.ROOT);
                out.add(switch (lower) {
                    case "sqrt", "abs" -> new Token(Type.FUNC, lower, 0);
                    case "ans" -> new Token(Type.ANS, lower, 0);
                    case "of" -> new Token(Type.OF, lower, 0);
                    default -> throw new ArithmosError(Code.INVALID_EXPRESSION, "Unknown word '" + word + "'");
                });
                i = j;
            } else {
                Type t = switch (c) {
                    case '+' -> Type.PLUS;
                    case '-' -> Type.MINUS;
                    case '*' -> Type.STAR;
                    case '/' -> Type.SLASH;
                    case '^' -> Type.CARET;
                    case '(' -> Type.LPAREN;
                    case ')' -> Type.RPAREN;
                    case '%' -> Type.PERCENT;
                    default -> null;
                };
                if (t == null) {
                    throw new ArithmosError(Code.INVALID_EXPRESSION, "Unexpected character '" + c + "'");
                }
                out.add(new Token(t, String.valueOf(c), 0));
                i++;
            }
        }
        out.add(new Token(Type.END, "", 0));
        return out;
    }

    private static boolean isDigit(char c) {
        return c >= '0' && c <= '9';
    }
}