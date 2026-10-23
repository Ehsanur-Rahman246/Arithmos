<?php
declare(strict_types=1);

namespace Arithmos\Shared;

/**
 * Number display (spec §2.3), used by the Standard Calculator and the Converter.
 *
 * 12 significant digits, rounded half AWAY from zero, trailing zeros trimmed,
 * -0 -> 0, plain notation for 1e-6 <= |x| < 1e15, otherwise <mantissa>e<sign><exp>.
 *
 * PHP's own rounding of floats is not used. sprintf('%.34e') prints the exact
 * decimal expansion of the double (PHP uses zend_dtoa, which rounds correctly),
 * and the digit string is rounded by hand, like the C and C++ editions.
 * So 100000000000.5 gives 100000000001.
 */
final class FormatNumber
{
    public static function format(float $x): string
    {
        if (is_nan($x)) {
            throw new ArithmosError(ArithmosError::INVALID_EXPRESSION, 'Result is not a number');
        }
        if (is_infinite($x)) {
            throw new ArithmosError(ArithmosError::OVERFLOW, 'Result is too large to represent');
        }
        if ($x == 0.0) {
            return '0'; // also covers -0.0
        }

        $negative = $x < 0.0;
        $text = sprintf('%.34e', abs($x)); // d.dddd...e+N  (35 significant digits)
        if (preg_match('/^(\d)\.(\d+)e([+-]\d+)$/', $text, $m) !== 1) {
            throw new \RuntimeException('Unexpected sprintf output: ' . $text);
        }
        $digits = $m[1] . $m[2];
        $exp = (int) $m[3];

        // Round the digit string to 12 significant digits, half away from zero:
        // looking only at the 13th digit is enough because the string is the
        // exact expansion (a tie is exactly 5000...).
        $keep = substr($digits, 0, 12);
        if ($digits[12] >= '5') {
            $keep = self::increment($keep);
            if (strlen($keep) > 12) { // 999999999999 + 1 -> 1000000000000
                $keep = substr($keep, 0, 12);
                $exp++;
            }
        }
        $mant = rtrim($keep, '0');
        if ($mant === '') {
            $mant = '0';
        }

        if ($exp >= -6 && $exp < 15) {
            $out = self::plain($mant, $exp);
        } else {
            $out = $mant[0] . (strlen($mant) > 1 ? '.' . substr($mant, 1) : '')
                . 'e' . ($exp < 0 ? '-' : '+') . abs($exp);
        }
        return ($negative ? '-' : '') . $out;
    }

    /** Plain decimal notation from a trimmed mantissa and a decimal exponent. */
    private static function plain(string $mant, int $exp): string
    {
        if ($exp < 0) {
            return '0.' . str_repeat('0', -$exp - 1) . $mant;
        }
        $intLen = $exp + 1;
        if (strlen($mant) <= $intLen) {
            return str_pad($mant, $intLen, '0');
        }
        return substr($mant, 0, $intLen) . '.' . substr($mant, $intLen);
    }

    /** Add one to a string of decimal digits. May return one digit longer. */
    private static function increment(string $d): string
    {
        for ($i = strlen($d) - 1; $i >= 0; $i--) {
            if ($d[$i] === '9') {
                $d[$i] = '0';
            } else {
                $d[$i] = chr(ord($d[$i]) + 1);
                return $d;
            }
        }
        return '1' . $d;
    }
}