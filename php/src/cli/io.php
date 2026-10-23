<?php
declare(strict_types=1);

namespace Arithmos\Cli;

/**
 * The one small object the CLI talks to the terminal through (ARCHITECTURE.md).
 * Everything is a closure, so tests can inject a fake keyboard and screen.
 *
 *   write(text)
 *   readLine(prompt)  -> the line without its newline, or null at end of input
 *   select(...)       -> only on a real terminal (null elsewhere); see Selector
 *   color             -> false for pipes, tests and NO_COLOR
 */
final class Io
{
    /** @var callable */
    private $writeFn;
    /** @var callable */
    private $readLineFn;
    /** @var callable|null */
    private $selectFn;
    public bool $color;

    public function __construct(callable $write, callable $readLine, ?callable $select = null, bool $color = false)
    {
        $this->writeFn = $write;
        $this->readLineFn = $readLine;
        $this->selectFn = $select;
        $this->color = $color;
    }

    public function write(string $text): void
    {
        ($this->writeFn)($text);
    }

    public function readLine(string $prompt): ?string
    {
        return ($this->readLineFn)($prompt);
    }

    public function canSelect(): bool
    {
        return $this->selectFn !== null;
    }

    /**
     * @param list<string> $labels
     * @param array{back:bool,quit:bool,typing:bool} $offer
     * @return array{type:string,index?:int,char?:string}
     */
    public function select(string $title, array $labels, array $offer): array
    {
        return ($this->selectFn)($title, $labels, $offer);
    }
}

/** UTF-8 helpers without the mbstring extension (standard library only). */
final class Text
{
    public static function len(string $s): int
    {
        $n = preg_match_all('/./su', $s);
        return $n === false ? strlen($s) : $n;
    }

    /** Shorten to at most $max columns; longer text ends with "…". */
    public static function cut(string $s, int $max): string
    {
        if (self::len($s) <= $max) {
            return $s;
        }
        $chars = preg_split('//u', $s, -1, PREG_SPLIT_NO_EMPTY);
        if ($chars === false) {
            return substr($s, 0, max(0, $max - 1)) . '…';
        }
        return implode('', array_slice($chars, 0, max(0, $max - 1))) . '…';
    }

    /** Code point to a UTF-8 string. */
    public static function chr(int $cp): string
    {
        if ($cp < 0x80) {
            return chr($cp);
        }
        if ($cp < 0x800) {
            return chr(0xC0 | ($cp >> 6)) . chr(0x80 | ($cp & 0x3F));
        }
        if ($cp < 0x10000) {
            return chr(0xE0 | ($cp >> 12)) . chr(0x80 | (($cp >> 6) & 0x3F)) . chr(0x80 | ($cp & 0x3F));
        }
        return chr(0xF0 | ($cp >> 18)) . chr(0x80 | (($cp >> 12) & 0x3F))
            . chr(0x80 | (($cp >> 6) & 0x3F)) . chr(0x80 | ($cp & 0x3F));
    }
}