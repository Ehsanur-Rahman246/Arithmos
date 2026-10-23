<?php
declare(strict_types=1);

namespace Arithmos\Calculator;

/** The Standard Calculator's session state: just `ans`. */
final class StandardSession
{
    public float $ans = 0.0; // 0 before the first calculation
}

/**
 * Standard Calculator engine. Returns a float; the CLI formats it.
 * `ans` changes only after a fully successful evaluation (a throw skips it).
 */
final class Calculator
{
    public static function evaluate(string $line, StandardSession $session): float
    {
        $ast = Parser::parse(Tokenizer::tokenize($line));
        $value = Evaluator::evaluate($ast, $session->ans);
        $session->ans = $value;
        return $value;
    }
}