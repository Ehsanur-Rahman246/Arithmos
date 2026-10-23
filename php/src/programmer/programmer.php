<?php
declare(strict_types=1);

namespace Arithmos\Programmer;

use Arithmos\Shared\ArithmosError;

/** The Programmer Calculator's session state: the input base. */
final class ProgrammerSession
{
    public string $base = 'dec';
}

/**
 * Programmer Calculator engine (spec §4.5). One operation per line.
 *
 * execute() returns one of:
 *   ['kind' => 'value', 'value' => int]     show the value in all four bases
 *   ['kind' => 'text',  'text'  => string]  a bare converted number (convert)
 *   ['kind' => 'base',  'base'  => string]  the input base was changed
 */
final class Programmer
{
    public static function execute(string $line, ProgrammerSession $s): array
    {
        $line = trim($line);
        if ($line === '') {
            throw new ArithmosError(ArithmosError::UNKNOWN_COMMAND, 'Type a number or a command. Try help');
        }

        // Shifts first: spaces are optional around << >> >>> (R29). The lazy left
        // part plus the alternation order makes ">>>" win over ">>".
        if (preg_match('/^(.*?)(>>>|>>|<<)(.*)$/s', $line, $m) === 1) {
            return self::shift(trim($m[1]), $m[2], trim($m[3]), $s);
        }

        $w = preg_split('/\s+/', $line);
        $count = count($w);
        $first = strtolower($w[0]);

        if ($first === 'base') {
            if ($count !== 2) {
                throw new ArithmosError(ArithmosError::INVALID_BASE, 'Use: base bin | oct | dec | hex');
            }
            $name = strtolower($w[1]);
            if (!Bases::isBase($name)) {
                throw new ArithmosError(
                    ArithmosError::INVALID_BASE,
                    "'{$w[1]}' is not a base. Use bin, oct, dec or hex"
                );
            }
            $s->base = $name;
            return ['kind' => 'base', 'base' => $name];
        }
        if ($first === 'convert') {
            if ($count !== 4) {
                throw new ArithmosError(ArithmosError::UNKNOWN_COMMAND, 'Use: convert <value> <from> <to>');
            }
            return self::convert($w[1], $w[2], $w[3]);
        }
        if ($first === 'not') {
            if ($count !== 2) {
                throw new ArithmosError(ArithmosError::UNKNOWN_COMMAND, 'Use: NOT <value>');
            }
            return ['kind' => 'value', 'value' => ~Literal::parse($w[1], $s->base)];
        }
        if ($count === 1) {
            return ['kind' => 'value', 'value' => Literal::parse($w[0], $s->base)];
        }
        if ($count === 3) {
            // `255 dec hex`: the word `convert` is optional (R24)
            if (Bases::isBase($w[1]) && Bases::isBase($w[2])) {
                return self::convert($w[0], $w[1], $w[2]);
            }
            // The operator is ALWAYS the middle word, so in hex mode
            // `FACE XOR BEEF` and `A AND F` read their operands as numbers (R11).
            $op = strtolower($w[1]);
            if ($op === 'and' || $op === 'or' || $op === 'xor') {
                $a = Literal::parse($w[0], $s->base);
                $b = Literal::parse($w[2], $s->base);
                $v = $op === 'and' ? ($a & $b) : ($op === 'or' ? ($a | $b) : ($a ^ $b));
                return ['kind' => 'value', 'value' => $v];
            }
        }
        throw new ArithmosError(ArithmosError::UNKNOWN_COMMAND, 'Not a command. Try help');
    }

    private static function shift(string $left, string $op, string $right, ProgrammerSession $s): array
    {
        if ($left === '' || $right === '' || preg_match('/\s/', $left . $right) === 1) {
            throw new ArithmosError(ArithmosError::UNKNOWN_COMMAND, 'Not a command. Try help');
        }
        $a = Literal::parse($left, $s->base);
        $n = self::shiftCount($right);
        if ($op === '<<') {
            $v = Int64::shl($a, $n);
        } elseif ($op === '>>') {
            $v = Int64::shr($a, $n);
        } else {
            $v = Int64::ushr($a, $n);
        }
        return ['kind' => 'value', 'value' => $v];
    }

    /** The count is always a plain decimal integer 0..63 (`0x3`, `2.5`, `-1` are INVALID_SHIFT). */
    private static function shiftCount(string $text): int
    {
        $msg = 'A shift count must be a whole number from 0 to 63';
        if (preg_match('/^[0-9]+$/', $text) !== 1) {
            throw new ArithmosError(ArithmosError::INVALID_SHIFT, $msg);
        }
        $t = ltrim($text, '0');
        if (strlen($t) > 2 || ($t !== '' && (int) $t > 63)) {
            throw new ArithmosError(ArithmosError::INVALID_SHIFT, $msg);
        }
        return $t === '' ? 0 : (int) $t;
    }

    /** `convert <value> <from> <to>`: the explicit `from` base reads the value. */
    private static function convert(string $value, string $from, string $to): array
    {
        foreach ([$from, $to] as $name) {
            if (!Bases::isBase($name)) {
                throw new ArithmosError(
                    ArithmosError::INVALID_BASE,
                    "'{$name}' is not a base. Use bin, oct, dec or hex"
                );
            }
        }
        $v = Literal::parse($value, strtolower($from));
        return ['kind' => 'text', 'text' => Format::base($v, strtolower($to))];
    }
}