package arithmos.calculator;

import arithmos.calculator.Tokenizer.Token;
import arithmos.calculator.Tokenizer.Type;
import arithmos.shared.ArithmosError;
import arithmos.shared.ArithmosError.Code;
import java.util.List;

/**
 * Recursive-descent parser. Precedence, high to low (spec §3.3):
 * parentheses/calls, postfix %, ^ (right-assoc), unary + -, * / of, + -.
 * Two adjacent operands never fit the grammar, so "2(3)" is rejected without special code.
 */
final class Parser {
    private final List<Token> toks;
    private int pos = 0;

    private Parser(List<Token> toks) {
        this.toks = toks;
    }

    static Node parse(List<Token> tokens) {
        if (tokens.size() == 1) { // only END
            throw new ArithmosError(Code.INVALID_EXPRESSION, "Nothing to calculate");
        }
        Parser p = new Parser(tokens);
        Node tree = p.expr();
        if (p.peek().type() != Type.END) { // leftovers such as "2 3" or "2(3)"
            throw new ArithmosError(Code.INVALID_EXPRESSION, "Unexpected symbol");
        }
        return tree;
    }

    private Token peek() {
        return toks.get(pos);
    }

    private Token next() {
        Token t = toks.get(pos);
        if (t.type() != Type.END) pos++; // never step past END
        return t;
    }

    private boolean match(Type t) {
        if (peek().type() == t) {
            next();
            return true;
        }
        return false;
    }

    /** expr := term (('+' | '-') term)* */
    private Node expr() {
        Node left = term();
        while (peek().type() == Type.PLUS || peek().type() == Type.MINUS) {
            char op = next().type() == Type.PLUS ? '+' : '-';
            left = new Node.Binary(op, left, term());
        }
        return left;
    }

    /** term := unary (('*' | '/' | 'of') unary)* */
    private Node term() {
        Node left = unary();
        while (peek().type() == Type.STAR || peek().type() == Type.SLASH || peek().type() == Type.OF) {
            char op = next().type() == Type.SLASH ? '/' : '*';
            left = new Node.Binary(op, left, unary());
        }
        return left;
    }

    /** unary := ('+' | '-') unary | power   (so -2^2 = -(2^2)) */
    private Node unary() {
        if (match(Type.MINUS)) return new Node.Unary('-', unary());
        if (match(Type.PLUS)) return new Node.Unary('+', unary());
        return power();
    }

    /** power := postfix ('^' exponent)?   right-associative: 2^3^2 = 2^(3^2) */
    private Node power() {
        Node base = postfix();
        if (match(Type.CARET)) {
            return new Node.Binary('^', base, exponent());
        }
        return base;
    }

    /** The exponent may carry a sign: 2^-1. */
    private Node exponent() {
        if (match(Type.MINUS)) return new Node.Unary('-', exponent());
        if (match(Type.PLUS)) return new Node.Unary('+', exponent());
        return power();
    }

    /** postfix := primary '%'*   ("50%%" is allowed) */
    private Node postfix() {
        Node n = primary();
        while (match(Type.PERCENT)) {
            n = new Node.Percent(n);
        }
        return n;
    }

    private Node primary() {
        Token t = next();
        switch (t.type()) {
            case NUM:
                return new Node.Num(t.value());
            case ANS:
                return new Node.Ans();
            case LPAREN: {
                Node inner = expr();
                closeParen();
                return new Node.Group(inner);
            }
            case FUNC: {
                String fn = t.text();
                if (peek().type() != Type.LPAREN) {
                    throw new ArithmosError(Code.INVALID_EXPRESSION,
                            fn + " needs parentheses, like " + fn + "(4)");
                }
                next();
                Node arg = expr();
                closeParen();
                return new Node.Call(fn, arg);
            }
            case END:
                throw new ArithmosError(Code.INVALID_EXPRESSION, "The expression ends too early");
            case OF:
                throw new ArithmosError(Code.INVALID_EXPRESSION, "Unexpected 'of'");
            default:
                throw new ArithmosError(Code.INVALID_EXPRESSION, "Unexpected symbol");
        }
    }

    private void closeParen() {
        if (match(Type.RPAREN)) return;
        throw new ArithmosError(Code.INVALID_EXPRESSION,
                peek().type() == Type.END ? "Missing closing parenthesis" : "Unexpected symbol");
    }
}