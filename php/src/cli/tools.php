<?php
declare(strict_types=1);

namespace Arithmos\Cli;

use Arithmos\Calculator\Calculator;
use Arithmos\Calculator\StandardSession;
use Arithmos\Converter\Converter;
use Arithmos\Converter\Units;
use Arithmos\Programmer\Programmer;
use Arithmos\Programmer\ProgrammerSession;
use Arithmos\Shared\ArithmosError;
use Arithmos\Shared\FormatNumber;

/**
 * The prompt loop shared by the three tools: `help`/`?`, `back`, `quit`,
 * blank lines ignored, EOF exits cleanly, every error printed as
 * `Error [CODE]: message`. Unexpected exceptions never crash the loop.
 */
final class Repl
{
    /** @return string 'back' | 'quit' | 'eof' */
    public static function run(Io $io, string $prompt, callable $handler, string $help): string
    {
        while (true) {
            $line = $io->readLine($prompt);
            if ($line === null) {
                $io->write("\n");
                return 'eof';
            }
            $line = trim($line);
            if ($line === '') {
                continue;
            }
            $low = strtolower($line);
            if ($low === 'help' || $low === '?') {
                $io->write($help . "\n");
                continue;
            }
            if ($low === 'back') {
                return 'back';
            }
            if ($low === 'quit') {
                return 'quit';
            }
            $io->write(self::dispatch(static fn() => $handler($line)) . "\n");
        }
    }

    /** Run an engine call and turn its result or error into the text to print. */
    public static function dispatch(callable $fn): string
    {
        try {
            return $fn();
        } catch (ArithmosError $e) {
            return $e->render();
        } catch (\Throwable $e) {
            return 'Error [INTERNAL]: ' . $e->getMessage(); // not a spec code; the loop keeps running
        }
    }
}

/** Tool bindings: wire each engine to its prompt loop. */
final class Tools
{
    public static function standard(Io $io): string
    {
        $session = new StandardSession();
        $io->write("Standard Calculator: type an expression. help for commands, back to return.\n");
        $help = "Operators: + - * / ^   Also: ( ) % of sqrt() abs() ans\n"
            . "Examples: 2 + 3 * 4, 20% of 150, 200 + 10%, sqrt(16), ans * 2\n"
            . 'Commands: help (or ?), back, quit';
        return Repl::run(
            $io,
            'standard> ',
            static fn(string $line): string => FormatNumber::format(Calculator::evaluate($line, $session)),
            $help
        );
    }

    public static function programmer(Io $io): string
    {
        $session = new ProgrammerSession();
        $io->write("Programmer Calculator: 64-bit signed. help for commands, back to return.\n");
        $help = "<value>                     show in HEX, DEC, OCT, BIN (prefixes 0b 0o 0d 0x)\n"
            . "base <bin|oct|dec|hex>      set the input base\n"
            . "[convert] <value> <from> <to>   e.g. 255 dec hex\n"
            . "<a> AND|OR|XOR <b>, NOT <a>\n"
            . "<a> << <n>, <a> >> <n> (arithmetic), <a> >>> <n> (logical); n is decimal 0-63\n"
            . 'Commands: help (or ?), back, quit';
        return Repl::run(
            $io,
            'programmer> ',
            static fn(string $line): string => Render::programmer(Programmer::execute($line, $session)),
            $help
        );
    }

    /** The guided converter: category -> from -> to -> values (spec §5.1). `back` steps back one stage. */
    public static function converter(Io $io): string
    {
        $cats = Units::categories();

        // One-line commands are accepted at every stage.
        $command = static function (string $line) use ($io): bool {
            $w = preg_split('/\s+/', trim($line));
            if (!in_array(strtolower($w[0]), ['convert', 'list'], true) && count($w) !== 3) {
                return false;
            }
            $io->write(Repl::dispatch(static fn() => Render::converter(Converter::run($line))) . "\n");
            return true;
        };

        $stage = 0;
        $c = 0;
        $from = null;
        $to = null;
        while (true) {
            if ($stage === 0) {
                $opts = [];
                foreach ($cats as $i => $cat) {
                    $opts[] = ['key' => (string) ($i + 1), 'label' => $cat['name'], 'aliases' => []];
                }
                $r = Pick::pick($io, 'Unit Converter — choose a category', $opts, true, true, $command);
                if ($r['type'] === 'back') {
                    return 'back';
                }
                if ($r['type'] !== 'choice') {
                    return $r['type'];
                }
                $c = $r['index'];
                $stage = 1;
                continue;
            }

            $cat = $cats[$c];
            $name = ucfirst($cat['name']);
            if ($stage === 1 || $stage === 2) {
                $opts = [];
                foreach ($cat['units'] as $i => $u) {
                    $opts[] = ['key' => (string) ($i + 1), 'label' => $u[0] . ' — ' . $u[1], 'aliases' => [$u[0], $u[1]]];
                }
                $title = $stage === 1 ? $name . ' — convert from' : $name . ' — convert from ' . $from[0] . ' to';
                $r = Pick::pick($io, $title, $opts, true, true, $command);
                if ($r['type'] === 'back') {
                    $stage--;
                    continue;
                }
                if ($r['type'] !== 'choice') {
                    return $r['type'];
                }
                if ($stage === 1) {
                    $from = $cat['units'][$r['index']];
                } else {
                    $to = $cat['units'][$r['index']];
                }
                $stage++;
                continue;
            }

            // stage 3: the values prompt shows the units: converter (m → yd)>
            $fromSymbol = $from[0];
            $toSymbol = $to[0];
            $help = "Type a value to convert {$fromSymbol} to {$toSymbol}, or a one-line form:\n"
                . "  100 cm in   convert 100 cm in   convert 1 km all   list   list <category>\n"
                . 'Commands: help (or ?), back (pick other units), quit';
            $res = Repl::run($io, "converter ({$fromSymbol} → {$toSymbol})> ", static function (string $line) use ($fromSymbol, $toSymbol): string {
                $w = preg_split('/\s+/', trim($line));
                if (count($w) === 1 && !in_array(strtolower($w[0]), ['list', 'convert'], true)) {
                    $value = Converter::parseValue($w[0]);
                    $result = Converter::convertValue($w[0], $fromSymbol, $toSymbol);
                    return FormatNumber::format($value) . ' ' . $fromSymbol . ' = '
                        . FormatNumber::format($result) . ' ' . $toSymbol;
                }
                return Render::converter(Converter::run($line));
            }, $help);
            if ($res === 'back') {
                $stage = 2;
                continue;
            }
            return $res;
        }
    }
}