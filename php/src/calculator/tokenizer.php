<?php
declare(strict_types=1);

namespace Arithmos\Calculator;

use Arithmos\Shared\ArithmosError;

/**
 * Step 1 of tokenize -> parse -> evaluate.
 * Token = [type, text]. Types: num, op, lp, rp, pct, sqrt, abs, ans, of.
 * Words are matched case-insensitively. `1e5` is not a number: "1" then the
 * unknown word "e5" (amendment R7).
 */
final class Tokenizer
{
    /** @return list<array{0:string,1:string}> */
    public static function tokenize(string $src): array
    {
        $tokens = [];
        $i = 0;
        $n = strlen($src);
        while ($i < $n) {
            $c = $src[$i];
            if (strpos(" \t\r\n\v\f", $c) !== false) {
                $i++;
                continue;
            }
            // 12, 12.5, .5, 5.   ("5.5.5" becomes two numbers, rejected by the parser)
            if (preg_match('/\G(?:\d+\.?\d*|\.\d+)/', $src, $m, 0, $i) === 1) {
                $tokens[] = ['num', $m[0]];
                $i += strlen($m[0]);
                continue;
            }
            if (preg_match('/\G[A-Za-z][A-Za-z0-9_]*/', $src, $m, 0, $i) === 1) {
                $low = strtolower($m[0]);
                if (!in_array($low, ['sqrt', 'abs', 'ans', 'of'], true)) {
                    throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, "Unknown word '{$m[0]}'");
                }
                $tokens[] = [$low, $low];
                $i += strlen($m[0]);
                continue;
            }
            if (strpos('+-*/^', $c) !== false) {
                $tokens[] = ['op', $c];
            } elseif ($c === '(') {
                $tokens[] = ['lp', $c];
            } elseif ($c === ')') {
                $tokens[] = ['rp', $c];
            } elseif ($c === '%') {
                $tokens[] = ['pct', $c];
            } else {
                // show the whole UTF-8 character, not one byte of it
                $ch = preg_match('/\G./su', $src, $m, 0, $i) === 1 ? $m[0] : $c;
                throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, "Unexpected character '{$ch}'");
            }
            $i++;
        }
        return $tokens;
    }
}