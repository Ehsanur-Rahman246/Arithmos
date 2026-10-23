<?php
declare(strict_types=1);

namespace Arithmos\Programmer;

use Arithmos\Shared\ArithmosError;

/**
 * Literal parsing (spec §4.3). Order of checks, as in ARCHITECTURE.md:
 *   prefix (0b 0o 0d 0x) overrides the input base
 *   -> characters / digit validation (INVALID_NUMBER, INVALID_DIGIT)
 *   -> range (OUT_OF_RANGE).
 * A prefix counts only when digits follow it (R30): "0B" in hex mode is the
 * number 11, but "0B1" is binary 1 (P32).
 * No float is ever involved, so no precision is lost near 2^63.
 */
final class Literal
{
    private const PREFIX = ['b' => 'bin', 'o' => 'oct', 'd' => 'dec', 'x' => 'hex'];
    private const BITS = [2 => 1, 8 => 3, 16 => 4];

    public static function parse(string $text, string $base): int
    {
        $negative = false;
        $body = $text;
        if ($body !== '' && $body[0] === '-') {
            $negative = true;
            $body = substr($body, 1);
        }
        if (strlen($body) > 2 && $body[0] === '0' && isset(self::PREFIX[strtolower($body[1])])) {
            $base = self::PREFIX[strtolower($body[1])];
            $body = substr($body, 2);
        }
        if ($body === '' || preg_match('/^[A-Za-z0-9]+$/', $body) !== 1) {
            throw new ArithmosError(ArithmosError::INVALID_NUMBER, "'{$text}' is not a number");
        }
        $radix = Bases::RADIX[$base];
        $body = strtoupper($body);
        foreach (str_split($body) as $ch) {
            if (self::digit($ch) >= $radix) {
                throw new ArithmosError(ArithmosError::INVALID_DIGIT, "'{$ch}' is not a {$base} digit");
            }
        }
        return $radix === 10 ? self::decimal($body, $negative) : self::bits($body, $radix, $negative);
    }

    /** Value of one already-validated alphanumeric character (0-9, A-Z). */
    private static function digit(string $ch): int
    {
        $o = ord($ch);
        return $o <= 57 ? $o - 48 : $o - 55;
    }

    /** Decimal: compared as a string against the limits, then cast. */
    private static function decimal(string $body, bool $negative): int
    {
        $mag = ltrim($body, '0');
        if ($mag === '') {
            $mag = '0';
        }
        $limit = $negative ? '9223372036854775808' : '9223372036854775807';
        if (strlen($mag) > 19 || (strlen($mag) === 19 && strcmp($mag, $limit) > 0)) {
            throw new ArithmosError(ArithmosError::OUT_OF_RANGE, 'That number does not fit in 64 bits');
        }
        if ($mag === '9223372036854775808') { // only reachable with a minus sign
            return PHP_INT_MIN;
        }
        return $negative ? -((int) $mag) : (int) $mag;
    }

    /**
     * bin/oct/hex: accumulate the raw bit pattern (at most 64 bits) and read it
     * as signed. Before each shift, the top `bits` bits must be clear, or the
     * pattern would grow past 64 bits.
     */
    private static function bits(string $body, int $radix, bool $negative): int
    {
        $bits = self::BITS[$radix];
        $mask = (1 << $bits) - 1;
        $v = 0;
        foreach (str_split(ltrim($body, '0')) as $ch) {
            if ($ch === '') {
                continue;
            }
            if ((($v >> (64 - $bits)) & $mask) !== 0) {
                throw new ArithmosError(
                    ArithmosError::OUT_OF_RANGE,
                    $negative ? 'That number does not fit in 64 bits' : 'That number needs more than 64 bits'
                );
            }
            $v = ($v << $bits) | self::digit($ch);
        }
        if (!$negative) {
            return $v; // raw pattern: 0xFFFFFFFFFFFFFFFF is -1
        }
        // a leading minus negates the magnitude, which must not exceed 2^63
        if ($v >= 0) {
            return -$v;
        }
        if ($v === PHP_INT_MIN) {
            return PHP_INT_MIN;
        }
        throw new ArithmosError(ArithmosError::OUT_OF_RANGE, 'That number does not fit in 64 bits');
    }
}