<?php
declare(strict_types=1);

namespace Arithmos\Cli;

use Arithmos\Calculator\Calculator;
use Arithmos\Calculator\StandardSession;
use Arithmos\Converter\Converter;
use Arithmos\Programmer\Programmer;
use Arithmos\Programmer\ProgrammerSession;
use Arithmos\Shared\ArithmosError;
use Arithmos\Shared\FormatNumber;

/** Main menu and one-shot mode. */
final class Cli
{
    public const USAGE = "Usage:\n"
        . "  arithmos                              interactive menu\n"
        . "  arithmos std <expression>             e.g. arithmos std \"20% of 150\"\n"
        . "  arithmos prog <command>               e.g. arithmos prog 0xFF AND 0x0F\n"
        . "  arithmos convert <value> <from> <to>  e.g. arithmos convert 100 cm in\n"
        . "  arithmos list [category]\n";

    public static function main(array $argv): int
    {
        $args = array_slice($argv, 1);
        if ($args !== []) {
            return self::oneShot($args, STDOUT, STDERR);
        }
        return self::interactive(Terminal::createIo());
    }

    /** The main menu (spec §2.1). Returns the exit status. */
    public static function interactive(Io $io): int
    {
        $options = [
            ['key' => '1', 'label' => 'Standard Calculator', 'aliases' => ['std', 'standard']],
            ['key' => '2', 'label' => 'Programmer Calculator', 'aliases' => ['prog', 'programmer']],
            ['key' => '3', 'label' => 'Unit Converter', 'aliases' => ['converter', 'convert']],
            ['key' => '0', 'label' => 'Exit', 'aliases' => ['exit']],
        ];
        while (true) {
            $r = Pick::pick($io, 'Arithmos 1.0 — Core CLI', $options, false, true);
            if ($r['type'] !== 'choice') {
                return 0; // quit or end of input: exit cleanly
            }
            switch ($r['index']) {
                case 0:
                    $res = Tools::standard($io);
                    break;
                case 1:
                    $res = Tools::programmer($io);
                    break;
                case 2:
                    $res = Tools::converter($io);
                    break;
                default:
                    return 0;
            }
            if ($res === 'quit' || $res === 'eof') {
                return 0;
            }
        }
    }

    /**
     * One-shot mode (R31): results and --help to $out, Error lines and bad-usage
     * text to $err. Exit status 0 success, 1 an Error [CODE] result, 2 bad usage.
     * The command word is case-insensitive.
     *
     * @param resource $out
     * @param resource $err
     */
    public static function oneShot(array $args, $out, $err): int
    {
        $cmd = strtolower((string) $args[0]);
        $line = implode(' ', array_slice($args, 1));
        if (in_array($cmd, ['--help', '-h', 'help'], true)) {
            fwrite($out, self::USAGE);
            return 0;
        }
        try {
            switch ($cmd) {
                case 'std':
                case 'standard':
                    if ($line === '') {
                        return self::usage($err);
                    }
                    $text = FormatNumber::format(Calculator::evaluate($line, new StandardSession()));
                    break;
                case 'prog':
                case 'programmer':
                    if ($line === '') {
                        return self::usage($err);
                    }
                    $text = Render::programmer(Programmer::execute($line, new ProgrammerSession()));
                    break;
                case 'convert':
                    if ($line === '') {
                        return self::usage($err);
                    }
                    $text = Render::converter(Converter::run('convert ' . $line));
                    break;
                case 'list':
                    $text = Render::converter(Converter::run(trim('list ' . $line)));
                    break;
                default:
                    return self::usage($err);
            }
        } catch (ArithmosError $e) {
            fwrite($err, $e->render() . "\n");
            return 1;
        } catch (\Throwable $e) {
            fwrite($err, 'Error [INTERNAL]: ' . $e->getMessage() . "\n");
            return 1;
        }
        fwrite($out, $text . "\n");
        return 0;
    }

    /**
     * @param resource $err
     */
    private static function usage($err): int
    {
        fwrite($err, self::USAGE);
        return 2;
    }
}