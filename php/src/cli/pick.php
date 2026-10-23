<?php
declare(strict_types=1);

namespace Arithmos\Cli;

use Arithmos\Shared\ArithmosError;

/**
 * pick(): one question, many answers (layer 4). Used by the main menu and the
 * converter's guided pickers.
 *
 * Options: list of ['key' => '1', 'label' => 'length', 'aliases' => ['len']].
 * On a real terminal (Io has a selector) it is an arrow-key list; everywhere
 * else it is a numbered list answered by typing a number, a name or a symbol.
 * $command(line) runs a typed one-line command and returns true, or returns
 * false when the line is not command-shaped.
 *
 * Returns ['type' => 'choice', 'index' => i] | ['type' => 'back'|'quit'|'eof'].
 */
final class Pick
{
    public static function pick(
        Io $io,
        string $title,
        array $options,
        bool $back,
        bool $quit = true,
        ?callable $command = null
    ): array {
        if ($io->canSelect()) {
            $labels = array_map(static fn(array $o): string => $o['label'], $options);
            while (true) {
                $r = $io->select($title, $labels, ['back' => $back, 'quit' => $quit, 'typing' => true]);
                switch ($r['type']) {
                    case 'select':
                        return ['type' => 'choice', 'index' => $r['index']];
                    case 'back': // Esc and b act at once, with no prompt line (SL20)
                        return ['type' => 'back'];
                    case 'quit':
                        return ['type' => 'quit'];
                    case 'abort':
                        return ['type' => 'eof'];
                    case 'typed':
                        // the prompt shows the key; the rest of the line is read
                        $rest = $io->readLine('> ' . $r['char']);
                        if ($rest === null) {
                            $io->write("\n");
                            return ['type' => 'eof'];
                        }
                        $result = self::interpret($io, $r['char'] . $rest, $options, $back, $quit, $command);
                        if ($result !== null) {
                            return $result;
                        }
                        break; // after an error or a command the list is shown again
                }
            }
        }

        // Numbered list: the baseline for pipes, files, tests and ARITHMOS_PLAIN=1
        $io->write($title . "\n");
        foreach ($options as $o) {
            $io->write('  ' . $o['key'] . ') ' . $o['label'] . "\n");
        }
        while (true) {
            $line = $io->readLine('> ');
            if ($line === null) {
                $io->write("\n");
                return ['type' => 'eof'];
            }
            $result = self::interpret($io, $line, $options, $back, $quit, $command);
            if ($result !== null) {
                return $result;
            }
        }
    }

    /** One typed answer. Returns a result, or null when the question must be asked again. */
    private static function interpret(Io $io, string $line, array $options, bool $back, bool $quit, ?callable $command): ?array
    {
        $line = trim($line);
        if ($line === '') {
            return null; // blank lines are ignored
        }
        $low = strtolower($line);
        if ($low === 'help' || $low === '?') {
            $io->write('Type a number, a name or a symbol' . ($back ? '; back goes back' : '') . "; quit exits.\n");
            return null;
        }
        if ($low === 'back' && $back) {
            return ['type' => 'back'];
        }
        if ($low === 'quit' && $quit) {
            return ['type' => 'quit'];
        }
        foreach ($options as $i => $o) {
            if ($low === strtolower($o['key']) || $low === strtolower($o['label'])) {
                return ['type' => 'choice', 'index' => $i];
            }
            foreach ($o['aliases'] as $alias) {
                if ($low === strtolower($alias)) {
                    return ['type' => 'choice', 'index' => $i];
                }
            }
        }
        if ($command !== null && $command($line)) {
            return null;
        }
        $io->write((new ArithmosError(ArithmosError::UNKNOWN_COMMAND, 'Pick one from the list'))->render() . "\n");
        return null;
    }
}