<?php
declare(strict_types=1);

namespace Arithmos\Cli;

use Arithmos\Programmer\Format;
use Arithmos\Shared\FormatNumber;

/** Engine results -> text. Shared by the prompt loops, one-shot mode and the tests. */
final class Render
{
    public static function programmer(array $r): string
    {
        switch ($r['kind']) {
            case 'value':
                $lines = [];
                foreach (Format::all($r['value']) as $name => $text) {
                    $lines[] = $name . ': ' . $text;
                }
                return implode("\n", $lines);
            case 'base':
                return 'Input base: ' . $r['base']; // lower-case canonical name (R32)
            default:
                return $r['text'];
        }
    }

    public static function converter(array $r): string
    {
        switch ($r['kind']) {
            case 'number':
                return FormatNumber::format($r['value']);
            case 'all': // `symbol: value`, table order, source unit included (R18)
                $lines = [];
                foreach ($r['rows'] as [$symbol, $value]) {
                    $lines[] = $symbol . ': ' . FormatNumber::format($value);
                }
                return implode("\n", $lines);
            default:
                return implode(', ', $r['items']);
        }
    }
}