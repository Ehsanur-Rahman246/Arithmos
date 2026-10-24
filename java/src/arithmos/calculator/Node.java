package arithmos.calculator;

/** The AST. Percent is its own node (spec §3.4); Group marks parentheses so "200 + (10%)" is plain. */
sealed interface Node {
    record Num(double value) implements Node {}
    record Ans() implements Node {}
    record Unary(char op, Node operand) implements Node {}
    record Binary(char op, Node left, Node right) implements Node {} // op: + - * / ^ ("of" becomes *)
    record Percent(Node operand) implements Node {}
    record Group(Node inner) implements Node {}
    record Call(String fn, Node arg) implements Node {}
}