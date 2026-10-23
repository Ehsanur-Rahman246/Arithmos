<?php
declare(strict_types=1);

namespace Arithmos\Programmer;

/** The four bases of spec §4.2. */
final class Bases
{
    public const RADIX = ['bin' => 2, 'oct' => 8, 'dec' => 10, 'hex' => 16];

    public static function isBase(string $word): bool
    {
        return isset(self::RADIX[strtolower($word)]);
    }
}

/**
 * 64-bit signed two's-complement operations on PHP's native int.
 *
 * A 64-bit PHP build is required. Native ints already wrap for bitwise work,
 * but arithmetic would silently turn into float, so this class only offers
 * bitwise operations and shifts. The shift count is always 0..63 here
 * (the engine validates it first).
 */
final class Int64
{
    /** `<<`: bits shifted past bit 63 are discarded, no error. */
    public static function shl(int $v, int $n): int
    {
        return $v << $n;
    }

    /** `>>`: arithmetic, sign-extending (PHP's native behaviour). */
    public static function shr(int $v, int $n): int
    {
        return $v >> $n;
    }

    /**
     * `>>>`: logical, zero-filling. PHP has no such operator, so clear the
     * sign-extended top n bits: PHP_INT_MAX >> (n-1) is 64-n one bits.
     */
    public static function ushr(int $v, int $n): int
    {
        return $n === 0 ? $v : ($v >> $n) & (PHP_INT_MAX >> ($n - 1));
    }
}

/** Output of a value in one or all bases (spec §4.4). */
final class Format
{
    /**
     * dechex/decoct/decbin treat the int as UNSIGNED, which is exactly the
     * "full 64-bit pattern, no minus sign" rule for negative values.
     */
    public static function base(int $v, string $base): string
    {
        switch ($base) {
            case 'bin':
                return decbin($v);
            case 'oct':
                return decoct($v);
            case 'hex':
                return strtoupper(dechex($v));
            default:
                return (string) $v; // dec is the signed value
        }
    }

    /** @return array{HEX:string,DEC:string,OCT:string,BIN:string} in display order */
    public static function all(int $v): array
    {
        return [
            'HEX' => self::base($v, 'hex'),
            'DEC' => self::base($v, 'dec'),
            'OCT' => self::base($v, 'oct'),
            'BIN' => self::base($v, 'bin'),
        ];
    }
}