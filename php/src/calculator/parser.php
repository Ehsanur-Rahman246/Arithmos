<?php
declare(strict_types=1);

namespace Arithmos\Calculator;

use Arithmos\Shared\ArithmosError;

/**
 * Step 2: recursive descent, one function per precedence level (spec §3.3).
 *
 *   expr   := term (('+'|'-') term)*
 *   term   := unary (('*'|'/'|'of') unary)*
 *   unary  := ('+'|'-') unary | power
 *   power  := postfix ('^' unary)?          right-associative, so 2^3^2 = 2^(3^2)
 *   postfix:= primary '%'*
 *   primary:= number | ans | '(' expr ')' | ('sqrt'|'abs') '(' expr ')'
 *
 * Because unary sits BELOW power, -2^2 is -(2^2), and 2^-1 still works because
 * the right side of ^ is a unary.
 *
 * AST nodes (arrays): [num, float] [ans] [group, n] [pos, n] [neg, n]
 *                     [pct, n] [call, fn, n] [bin, op, l, r]
 * `group` keeps parentheses visible, so "200 + (10%)" is plain (amendment R1).
 * Implicit multiplication needs no code: two adjacent operands leave tokens
 * over, which is "Unexpected symbol".
 */
final class Parser
{
    private const MAX_DEPTH = 500;

    /** @var list<array{0:string,1:string}> */
    private array $t;
    private int $p = 0;
    private int $depth = 0;

    private function __construct(array $tokens)
    {
        $this->t = $tokens;
    }

    public static function parse(array $tokens): array
    {
        if ($tokens === []) {
            throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, 'Nothing to calculate');
        }
        $parser = new self($tokens);
        $node = $parser->expr();
        if ($parser->p < count($parser->t)) {
            throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, 'Unexpected symbol');
        }
        return $node;
    }

    private function peek(): ?array
    {
        return $this->t[$this->p] ?? null;
    }

    private function expr(): array
    {
        $left = $this->term();
        while (($tok = $this->peek()) !== null && $tok[0] === 'op' && ($tok[1] === '+' || $tok[1] === '-')) {
            $this->p++;
            $left = ['bin', $tok[1], $left, $this->term()];
        }
        return $left;
    }

    private function term(): array
    {
        $left = $this->unary();
        while (($tok = $this->peek()) !== null
            && ($tok[0] === 'of' || ($tok[0] === 'op' && ($tok[1] === '*' || $tok[1] === '/')))) {
            $this->p++;
            $op = $tok[0] === 'of' ? '*' : $tok[1]; // `of` is sugar for `*`
            $left = ['bin', $op, $left, $this->unary()];
        }
        return $left;
    }

    private function unary(): array
    {
        // Every nesting (parentheses, signs, ^) passes through here, so this one
        // guard keeps hostile input from exhausting the stack.
        if (++$this->depth > self::MAX_DEPTH) {
            throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, 'The expression is nested too deeply');
        }
        try {
            $tok = $this->peek();
            if ($tok !== null && $tok[0] === 'op' && ($tok[1] === '+' || $tok[1] === '-')) {
                $this->p++;
                return [$tok[1] === '-' ? 'neg' : 'pos', $this->unary()];
            }
            return $this->power();
        } finally {
            $this->depth--;
        }
    }

    private function power(): array
    {
        $base = $this->postfix();
        $tok = $this->peek();
        if ($tok !== null && $tok[0] === 'op' && $tok[1] === '^') {
            $this->p++;
            return ['bin', '^', $base, $this->unary()];
        }
        return $base;
    }

    private function postfix(): array
    {
        $node = $this->primary();
        while (($tok = $this->peek()) !== null && $tok[0] === 'pct') { // 50%% is allowed (R4)
            $this->p++;
            $node = ['pct', $node];
        }
        return $node;
    }

    private function primary(): array
    {
        $tok = $this->peek();
        if ($tok === null) {
            throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, 'The expression ends too early');
        }
        switch ($tok[0]) {
            case 'num':
                $this->p++;
                return ['num', (float) $tok[1]];
            case 'ans':
                $this->p++;
                return ['ans'];
            case 'sqrt':
            case 'abs':
                $this->p++;
                $next = $this->peek();
                if ($next === null || $next[0] !== 'lp') {
                    throw new ArithmosError(
                        ArithmosError::INVALID_EXPRESSION,
                        "{$tok[0]} needs parentheses, like {$tok[0]}(4)"
                    );
                }
                $this->p++;
                $inner = $this->expr();
                $this->expectClose();
                return ['call', $tok[0], $inner];
            case 'lp':
                $this->p++;
                $inner = $this->expr();
                $this->expectClose();
                return ['group', $inner];
            case 'of':
                throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, "Unexpected '{$tok[0]}'");
            default: // ')' '*' '%' ... cannot start an operand
                throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, 'Unexpected symbol');
        }
    }

    private function expectClose(): void
    {
        $tok = $this->peek();
        if ($tok === null) {
            throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, 'Missing closing parenthesis');
        }
        if ($tok[0] !== 'rp') {
            throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, 'Unexpected symbol');
        }
        $this->p++;
    }
}