<?php
declare(strict_types=1);

namespace Arithmos\Converter;

use Arithmos\Shared\ArithmosError;

/**
 * Unit Converter engine (spec §5). Pure logic: returns values, raises ArithmosError.
 *
 * run() returns one of:
 *   ['kind' => 'number', 'value' => float]
 *   ['kind' => 'all',    'rows'  => list<[symbol, float]>]
 *   ['kind' => 'list',   'items' => list<string>]
 */
final class Converter
{
    /** Inputs below these are BELOW_ABSOLUTE_ZERO. Exactly at the limit is allowed (R20). */
    private const ABSOLUTE_ZERO = ['c' => -273.15, 'f' => -459.67, 'k' => 0.0];

    /** One-line forms: `convert V from to`, `V from to`, `list`, `list <category>`. */
    public static function run(string $line): array
    {
        $line = trim($line);
        if ($line === '') {
            throw new ArithmosError(ArithmosError::UNKNOWN_COMMAND, 'Type a value, e.g. 100');
        }
        $w = preg_split('/\s+/', $line);
        $first = strtolower($w[0]);

        if ($first === 'list') {
            if (count($w) > 2) {
                throw new ArithmosError(ArithmosError::UNKNOWN_COMMAND, 'Use: list  or  list <category>');
            }
            $cats = Units::categories();
            if (count($w) === 1) {
                return ['kind' => 'list', 'items' => array_map(static fn(array $c): string => $c['name'], $cats)];
            }
            foreach ($cats as $cat) {
                if ($cat['name'] === strtolower($w[1])) {
                    return ['kind' => 'list', 'items' => array_map(static fn(array $u): string => $u[0], $cat['units'])];
                }
            }
            throw new ArithmosError(ArithmosError::UNKNOWN_COMMAND, "'{$w[1]}' is not a category. Try: list");
        }
        if ($first === 'convert') {
            if (count($w) !== 4) {
                throw new ArithmosError(ArithmosError::UNKNOWN_COMMAND, 'Use: convert <value> <from> <to>');
            }
            return self::convertWords($w[1], $w[2], $w[3]);
        }
        if (count($w) === 3) { // the word `convert` is optional
            return self::convertWords($w[0], $w[1], $w[2]);
        }
        throw new ArithmosError(ArithmosError::UNKNOWN_COMMAND, 'Not a command. Try: convert 100 cm in');
    }

    /** Used by the guided flow's values prompt: a bare value with units already chosen. */
    public static function convertValue(string $valueText, string $fromSymbol, string $toSymbol): float
    {
        $result = self::convertWords($valueText, $fromSymbol, $toSymbol);
        return $result['value'];
    }

    /** A plain decimal: optional sign, digits, optional point. `1e3` and `1,000` are INVALID_NUMBER. */
    public static function parseValue(string $text): float
    {
        if (preg_match('/^[+-]?(?:\d+\.?\d*|\.\d+)$/', $text) !== 1) {
            throw new ArithmosError(ArithmosError::INVALID_NUMBER, "'{$text}' is not a number");
        }
        $v = (float) $text;
        if (is_infinite($v)) {
            throw new ArithmosError(ArithmosError::OVERFLOW, 'That number is too large');
        }
        return $v;
    }

    private static function convertWords(string $valueText, string $fromSymbol, string $toSymbol): array
    {
        $value = self::parseValue($valueText);
        $cats = Units::categories();
        $from = Units::find($fromSymbol);
        if ($from === null) {
            throw new ArithmosError(ArithmosError::UNKNOWN_UNIT, "'{$fromSymbol}' is not a known unit. Try: list");
        }
        $fromCat = $cats[$from[0]];
        $fromUnit = $fromCat['units'][$from[1]];

        if (strtolower($toSymbol) === 'all') { // every unit of the source's category, in table order
            $rows = [];
            foreach ($fromCat['units'] as $unit) {
                $rows[] = [$unit[0], self::number($value, $fromCat['name'], $fromUnit, $unit)];
            }
            return ['kind' => 'all', 'rows' => $rows];
        }
        $to = Units::find($toSymbol);
        if ($to === null) {
            throw new ArithmosError(ArithmosError::UNKNOWN_UNIT, "'{$toSymbol}' is not a known unit. Try: list");
        }
        if ($to[0] !== $from[0]) {
            throw new ArithmosError(
                ArithmosError::INCOMPATIBLE_UNITS,
                "Cannot convert {$fromCat['name']} to {$cats[$to[0]]['name']}"
            );
        }
        $toUnit = $fromCat['units'][$to[1]];
        return ['kind' => 'number', 'value' => self::number($value, $fromCat['name'], $fromUnit, $toUnit)];
    }

    /** value x from.factor / to.factor, or the temperature formulas via Celsius. */
    private static function number(float $v, string $category, array $from, array $to): float
    {
        if ($category === 'temperature') {
            if ($v < self::ABSOLUTE_ZERO[$from[0]]) {
                throw new ArithmosError(ArithmosError::BELOW_ABSOLUTE_ZERO, 'That is below absolute zero');
            }
            $celsius = $from[0] === 'c' ? $v : ($from[0] === 'f' ? ($v - 32.0) * 5.0 / 9.0 : $v - 273.15);
            $r = $to[0] === 'c' ? $celsius : ($to[0] === 'f' ? $celsius * 9.0 / 5.0 + 32.0 : $celsius + 273.15);
        } else {
            $r = $v * $from[2] / $to[2];
        }
        if (is_nan($r) || is_infinite($r)) {
            throw new ArithmosError(ArithmosError::OVERFLOW, 'Result is too large to represent');
        }
        return $r;
    }
}