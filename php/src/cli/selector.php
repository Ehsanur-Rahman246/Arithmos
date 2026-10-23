<?php
declare(strict_types=1);

namespace Arithmos\Cli;

/** Injectable keyboard: returns one key per call (see Selector for the key names). */
interface KeyboardInterface
{
    public function readKey(): string;
}

/** Injectable screen. size() returns [columns, rows], measured on every call. */
interface ScreenInterface
{
    public function write(string $text): void;

    /** @return array{0:int,1:int} */
    public function size(): array;
}

/**
 * Optional: a keyboard that must be put into raw mode ONCE for a whole
 * selector run (not once per key), so the terminal does not flicker or echo
 * escape codes between key presses. Fakes in tests do not implement this.
 */
interface RawModeInterface
{
    public function begin(): void; // enter raw mode
    public function end(): void;   // restore the terminal (always called, in a finally)
}

/**
 * The arrow-key selector, in the same four layers as every edition:
 *   1. key handling (pure)           handleKey(), parseBytes()
 *   2. drawing (pure)                render(), hint()
 *   3. draw/read loop                run() over an injectable keyboard and screen
 *   4. pick() over an injectable Io  see pick.php
 *
 * Keys are strings: UP DOWN HOME END PGUP PGDN ENTER ESC CTRL_C CTRL_D OTHER
 * (an ignored control key), or the printable character itself (one code point).
 *
 * State: ['index', 'top', 'count', 'window'].
 * Offer: ['back' => bool, 'quit' => bool, 'typing' => bool].
 * Action (or null): select(index) | back | quit | abort | typed(char).
 */
final class Selector
{
    public const MAX_WINDOW = 10; // SL2

    public static function newState(int $count, int $window): array
    {
        return ['index' => 0, 'top' => 0, 'count' => $count, 'window' => max(1, $window)];
    }

    /** Rows shown: at most 10, and the whole block (rows + title + hint) must fit with one spare line. */
    public static function windowSize(int $count, int $rows): int
    {
        return max(1, min($count, self::MAX_WINDOW, $rows - 3));
    }

    /** Keep the selected row inside the visible window. */
    public static function scroll(array $s): array
    {
        if ($s['index'] < $s['top']) {
            $s['top'] = $s['index'];
        }
        if ($s['index'] >= $s['top'] + $s['window']) {
            $s['top'] = $s['index'] - $s['window'] + 1;
        }
        $s['top'] = max(0, min($s['top'], $s['count'] - $s['window']));
        return $s;
    }

    /**
     * Layer 1. Returns [new state, action|null].
     * `b` and `q` act at once, but only when offered; otherwise they are ordinary
     * printable keys (which open a typed line when typing is on).
     */
    public static function handleKey(array $s, string $key, array $offer): array
    {
        $n = $s['count'];
        if ($key === 'UP') {
            $s['index'] = ($s['index'] - 1 + $n) % $n;
        } elseif ($key === 'DOWN') {
            $s['index'] = ($s['index'] + 1) % $n;
        } elseif ($key === 'HOME') {
            $s['index'] = 0;
        } elseif ($key === 'END') {
            $s['index'] = $n - 1;
        } elseif ($key === 'PGUP') {
            $s['index'] = max(0, $s['index'] - $s['window']);
        } elseif ($key === 'PGDN') {
            $s['index'] = min($n - 1, $s['index'] + $s['window']);
        } elseif ($key === 'ENTER') {
            return [$s, ['type' => 'select', 'index' => $s['index']]];
        } elseif ($key === 'ESC') {
            return [$s, !empty($offer['back']) ? ['type' => 'back'] : null];
        } elseif ($key === 'CTRL_C' || $key === 'CTRL_D') {
            return [$s, ['type' => 'abort']];
        } elseif ($key === 'OTHER') {
            return [$s, null];
        } else {
            if ($key === 'b' && !empty($offer['back'])) {
                return [$s, ['type' => 'back']];
            }
            if ($key === 'q' && !empty($offer['quit'])) {
                return [$s, ['type' => 'quit']];
            }
            // space and control keys never start a typed line (SL8)
            if (!empty($offer['typing']) && $key !== ' ' && preg_match('/^\P{C}$/u', $key) === 1) {
                return [$s, ['type' => 'typed', 'char' => $key]];
            }
            return [$s, null];
        }
        return [self::scroll($s), null];
    }

    /**
     * Raw bytes of one terminal read -> keys. One read is one key press (or a
     * paste), so a lone ESC byte really is the Esc key.
     *
     * @return list<string>
     */
    public static function parseBytes(string $bytes): array
    {
        $keys = [];
        $i = 0;
        $n = strlen($bytes);
        while ($i < $n) {
            $c = $bytes[$i];
            if ($c === "\e") {
                $next = $i + 1 < $n ? $bytes[$i + 1] : '';
                if ($next === '[' || $next === 'O') {
                    $j = $i + 2;
                    while ($j < $n && ord($bytes[$j]) < 0x40) { // parameter / intermediate bytes
                        $j++;
                    }
                    if ($j >= $n) {
                        $keys[] = 'OTHER';
                        break;
                    }
                    $keys[] = self::csiKey(substr($bytes, $i + 2, $j - $i - 2), $bytes[$j]);
                    $i = $j + 1;
                    continue;
                }
                $keys[] = 'ESC';
                $i++;
                continue;
            }
            if ($c === "\r" || $c === "\n") {
                $keys[] = 'ENTER';
                $i++;
            } elseif ($c === "\x03") {
                $keys[] = 'CTRL_C';
                $i++;
            } elseif ($c === "\x04") {
                $keys[] = 'CTRL_D';
                $i++;
            } elseif (ord($c) < 32 || ord($c) === 127) {
                $keys[] = 'OTHER';
                $i++;
            } elseif (preg_match('/\G./su', $bytes, $m, 0, $i) === 1) {
                $keys[] = $m[0];
                $i += strlen($m[0]);
            } else {
                $keys[] = 'OTHER'; // invalid UTF-8
                $i++;
            }
        }
        return $keys;
    }

    private static function csiKey(string $params, string $final): string
    {
        if ($final === 'A') {
            return 'UP';
        }
        if ($final === 'B') {
            return 'DOWN';
        }
        if ($final === 'H') {
            return 'HOME';
        }
        if ($final === 'F') {
            return 'END';
        }
        if ($final === '~') {
            $map = ['1' => 'HOME', '7' => 'HOME', '4' => 'END', '8' => 'END', '5' => 'PGUP', '6' => 'PGDN'];
            return $map[$params] ?? 'OTHER';
        }
        return 'OTHER';
    }

    /** The key hint lists only the keys on offer (SL11, SL12). */
    public static function hint(array $offer, array $state): string
    {
        $parts = [];
        if ($state['count'] > $state['window']) {
            $parts[] = ($state['index'] + 1) . '/' . $state['count'];
        }
        $parts[] = '↑↓ move';
        $parts[] = 'Enter select';
        if (!empty($offer['back'])) {
            $parts[] = 'Esc/b back';
        }
        if (!empty($offer['quit'])) {
            $parts[] = 'q quit';
        }
        if (!empty($offer['typing'])) {
            $parts[] = 'or type a number or name';
        }
        return implode(' · ', $parts);
    }

    /**
     * Layer 2: the block as a list of lines (no newlines). One logical line is
     * one screen line, so every line is at most (cols - 1) columns and longer
     * ones end with "…" (rule 6). The selected row is a full reverse-video bar
     * with a ❯ pointer; without colour the pointer alone marks it (SL9, SL10).
     *
     * @param list<string> $labels
     * @return list<string>
     */
    public static function render(string $title, array $labels, array $state, array $offer, bool $color, int $cols): array
    {
        $max = max(1, $cols - 1);
        $lines = [];
        $t = Text::cut($title, $max);
        $lines[] = $color ? "\e[1m" . $t . "\e[0m" : $t;

        $rows = [];
        $end = min($state['count'], $state['top'] + $state['window']);
        for ($i = $state['top']; $i < $end; $i++) {
            $rows[$i] = Text::cut(($i === $state['index'] ? '❯ ' : '  ') . $labels[$i], $max);
        }
        $bar = 0;
        foreach ($rows as $row) {
            $bar = max($bar, Text::len($row));
        }
        foreach ($rows as $i => $row) {
            if ($color && $i === $state['index']) {
                $row = "\e[7m" . $row . str_repeat(' ', $bar - Text::len($row)) . "\e[0m";
            }
            $lines[] = $row;
        }
        $h = Text::cut(self::hint($offer, $state), $max);
        $lines[] = $color ? "\e[2m" . $h . "\e[0m" : $h;
        return $lines;
    }

        /**
     * Layer 3: draw, read a key, redraw IN PLACE. Size is measured on every
     * redraw, so resizing works. Returns an action array (never null):
     * select | back | quit | abort | typed.
     *
     * Flicker-free: each frame is ONE write that moves up over the previous
     * frame and overwrites every line (clearing each line first with \e[2K).
     * The block is never blanked in between. It is erased only once, when
     * the selector finishes.
     *
     * @param list<string> $labels
     */
    public static function run(
        KeyboardInterface $kb,
        ScreenInterface $screen,
        bool $color,
        string $title,
        array $labels,
        array $offer
    ): array {
        $count = count($labels);
        $state = self::newState($count, 1);
        $prev = 0; // number of lines the previous frame drew
        $raw = $kb instanceof RawModeInterface ? $kb : null;

        $screen->write("\e[?25l"); // hide the cursor
        try {
            if ($raw !== null) {
                $raw->begin(); // raw mode for the whole run, not per key
            }
            while (true) {
                [$cols, $rows] = $screen->size();
                $state['window'] = self::windowSize($count, $rows);
                $state = self::scroll($state);
                $lines = self::render($title, $labels, $state, $offer, $color, $cols);

                // one single write: up over the old frame, overwrite each line
                $frame = $prev > 0 ? "\e[" . $prev . 'A' : '';
                foreach ($lines as $line) {
                    $frame .= "\r\e[2K" . $line . "\n";
                }
                if (count($lines) < $prev) {
                    $frame .= "\e[J"; // the block got shorter: clear what is left below
                }
                $screen->write($frame);
                $prev = count($lines);

                [$state, $action] = self::handleKey($state, $kb->readKey(), $offer);

                if ($action !== null) {
                    // erase the block once, then leave a one-line summary behind
                    $out = "\e[" . $prev . "A\e[J";
                    if ($action['type'] === 'select') {
                        $tick = $color ? "\e[32m✔\e[0m" : '✔';
                        $out .= $tick . ' ' . $title . ': ' . $labels[$action['index']] . "\n";
                    }
                    $screen->write($out);
                    return $action;
                }
            }
        } finally {
            if ($raw !== null) {
                $raw->end(); // never leave the terminal raw
            }
            $screen->write("\e[?25h"); // always restore the cursor
        }
    }
}