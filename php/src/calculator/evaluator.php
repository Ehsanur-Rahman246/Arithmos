<?php
declare(strict_types=1);

namespace Arithmos\Calculator;

use Arithmos\Shared\ArithmosError;

/**
 * Step 3: walk the AST with IEEE doubles. NaN and Infinity never leave this
 * class: they become OVERFLOW / DOMAIN_ERROR / UNDEFINED / DIV_BY_ZERO.
 */
final class Evaluator
{
    public static function evaluate(array $node, float $ans): float
    {
        return self::ev($node, $ans);
    }

    private static function ev(array $n, float $ans): float
    {
        switch ($n[0]) {
            case 'num':
                return self::check($n[1]); // a 400-digit literal is INF -> OVERFLOW
            case 'ans':
                return $ans;
            case 'group':
            case 'pos':
                return self::ev($n[1], $ans);
            case 'neg':
                return -self::ev($n[1], $ans);
            case 'pct': // standalone percent: value / 100
                return self::ev($n[1], $ans) / 100.0;
            case 'call':
                $v = self::ev($n[2], $ans);
                if ($n[1] === 'abs') {
                    return abs($v);
                }
                if ($v < 0.0) {
                    throw new ArithmosError(
                        ArithmosError::DOMAIN_ERROR,
                        'Cannot take the square root of a negative number'
                    );
                }
                return sqrt($v);
            case 'bin':
                return self::binary($n, $ans);
        }
        throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, 'Malformed expression');
    }

    private static function binary(array $n, float $ans): float
    {
        [, $op, $left, $right] = $n;
        $a = self::ev($left, $ans);
        if (($op === '+' || $op === '-') && $right[0] === 'pct') {
            // spec §3.4: a % that is the DIRECT right operand of + or - is
            // relative to the left operand. 200 + 10% -> 200 + 200 * 0.1.
            $b = $a * self::ev($right, $ans);
        } else {
            $b = self::ev($right, $ans);
        }
        switch ($op) {
            case '+':
                return self::check($a + $b);
            case '-':
                return self::check($a - $b);
            case '*':
                return self::check($a * $b);
            case '/':
                if ($b == 0.0) {
                    throw new ArithmosError(ArithmosError::DIV_BY_ZERO, 'Cannot divide by zero');
                }
                return self::check($a / $b);
            case '^':
                return self::check(self::power($a, $b));
        }
        throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, 'Malformed expression');
    }

    /** Spec §3.5. */
    private static function power(float $a, float $b): float
    {
        if ($a == 0.0 && $b == 0.0) {
            throw new ArithmosError(ArithmosError::UNDEFINED, '0^0 is undefined');
        }
        if ($a == 0.0 && $b < 0.0) {
            throw new ArithmosError(ArithmosError::DIV_BY_ZERO, 'Zero cannot be raised to a negative power');
        }
        if ($a < 0.0 && floor($b) != $b) {
            throw new ArithmosError(
                ArithmosError::DOMAIN_ERROR,
                'A negative number cannot have a fractional power'
            );
        }
        return pow($a, $b); // 10^-400 is 0, not an error (R9)
    }

    private static function check(float $v): float
    {
        if (is_nan($v)) {
            throw new ArithmosError(ArithmosError::DOMAIN_ERROR, 'The result is not a number');
        }
        if (is_infinite($v)) {
            throw new ArithmosError(ArithmosError::OVERFLOW, 'The result is too large');
        }
        return $v;
    }
}