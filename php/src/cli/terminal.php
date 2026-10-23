<?php
declare(strict_types=1);

namespace Arithmos\Cli;

/**
 * Real keyboard on Linux/macOS. Raw mode (via stty) is switched on once by
 * begin() and restored once by end(), so no stty process runs between key
 * presses and the terminal never echoes escape codes. If readKey() is used
 * without begin(), it falls back to raw-per-key.
 */
final class PosixKeyboard implements KeyboardInterface, RawModeInterface
{
    /** @var list<string> */
    private array $queue = [];
    private ?string $saved = null; // saved stty settings while raw

    public function begin(): void
    {
        if ($this->saved !== null) {
            return;
        }
        $this->saved = trim((string) shell_exec('stty -g 2>/dev/null'));
        // -isig: Ctrl-C arrives as a byte instead of killing PHP while raw
        shell_exec('stty -icanon -echo -isig min 1 time 0 2>/dev/null');
    }

    public function end(): void
    {
        if ($this->saved === null) {
            return;
        }
        shell_exec($this->saved !== '' ? 'stty ' . escapeshellarg($this->saved) . ' 2>/dev/null' : 'stty sane 2>/dev/null');
        $this->saved = null;
        $this->queue = [];
    }

    public function readKey(): string
    {
        while ($this->queue === []) {
            $bytes = $this->readChunk();
            if ($bytes === '') {
                return 'CTRL_D'; // end of input
            }
            $this->queue = Selector::parseBytes($bytes);
        }
        return array_shift($this->queue);
    }

    private function readChunk(): string
    {
        if ($this->saved !== null) { // already raw: just read
            $bytes = fread(STDIN, 32); // one read = one key press
            return $bytes === false ? '' : $bytes;
        }
        // fallback when begin() was not called: raw for this one read only
        $this->begin();
        try {
            $bytes = fread(STDIN, 32);
        } finally {
            $this->end();
        }
        return $bytes === false ? '' : $bytes;
    }
}

/**
 * Real keyboard on Windows: PHP has no raw console read, so each key is read by
 * a short PowerShell call. It works in cmd, PowerShell and Windows Terminal, but
 * every key press costs a moment; typing a number is quicker there.
 */
final class WindowsKeyboard implements KeyboardInterface
{
    public function readKey(): string
    {
        $ps = "[Console]::TreatControlCAsInput=\$true; \$k=[Console]::ReadKey(\$true); "
            . "('{0}|{1}' -f \$k.Key,[int]\$k.KeyChar)";
        $out = trim((string) shell_exec('powershell -NoProfile -NonInteractive -Command "' . $ps . '"'));
        if ($out === '' || strpos($out, '|') === false) {
            return 'CTRL_C';
        }
        [$name, $code] = explode('|', $out, 2);
        $code = (int) $code;
        $named = [
            'UpArrow' => 'UP', 'DownArrow' => 'DOWN', 'Home' => 'HOME', 'End' => 'END',
            'PageUp' => 'PGUP', 'PageDown' => 'PGDN', 'Enter' => 'ENTER', 'Escape' => 'ESC',
        ];
        if (isset($named[$name])) {
            return $named[$name];
        }
        if ($code === 3) {
            return 'CTRL_C';
        }
        if ($code === 4) {
            return 'CTRL_D';
        }
        return $code >= 32 ? Text::chr($code) : 'OTHER';
    }
}

final class StdScreen implements ScreenInterface
{
    public function write(string $text): void
    {
        fwrite(STDOUT, $text);
    }

    public function size(): array
    {
        return Terminal::size();
    }
}

/** Terminal detection and the real Io. */
final class Terminal
{
    /** A real terminal: stdin and stdout are terminals, TERM is not dumb, ARITHMOS_PLAIN is not 1. */
    public static function isInteractive(): bool
    {
        if (getenv('ARITHMOS_PLAIN') === '1' || getenv('TERM') === 'dumb') {
            return false;
        }
        return function_exists('stream_isatty') && stream_isatty(STDIN) && stream_isatty(STDOUT);
    }

    /** @return array{0:int,1:int} [columns, rows] */
    public static function size(): array
    {
        if (PHP_OS_FAMILY === 'Windows') {
            $o = (string) shell_exec('mode con 2>nul');
            if (preg_match('/Columns:\s*(\d+)/i', $o, $c) === 1 && preg_match('/Lines:\s*(\d+)/i', $o, $l) === 1) {
                return [(int) $c[1], (int) $l[1]];
            }
        } else {
            $o = trim((string) shell_exec('stty size 2>/dev/null')); // "rows cols"
            if (preg_match('/^(\d+)\s+(\d+)$/', $o, $m) === 1 && (int) $m[2] > 0) {
                return [(int) $m[2], (int) $m[1]];
            }
        }
        return [(int) (getenv('COLUMNS') ?: 80), (int) (getenv('LINES') ?: 24)];
    }

    public static function createIo(): Io
    {
        $out = function_exists('stream_isatty') && stream_isatty(STDOUT);
        if ($out) {
            self::prepareConsole();
        }
        $noColor = getenv('NO_COLOR');
        $color = $out && ($noColor === false || $noColor === '');

        $write = static function (string $text): void {
            fwrite(STDOUT, $text);
        };
        $readLine = static function (string $prompt) use ($write): ?string {
            $write($prompt);
            $line = fgets(STDIN);
            return $line === false ? null : rtrim($line, "\r\n");
        };

        $select = null;
        if (self::isInteractive()) {
            $kb = PHP_OS_FAMILY === 'Windows' ? new WindowsKeyboard() : new PosixKeyboard();
            $screen = new StdScreen();
            $select = static function (string $title, array $labels, array $offer) use ($kb, $screen, $color): array {
                return Selector::run($kb, $screen, $color, $title, $labels, $offer);
            };
        }
        return new Io($write, $readLine, $select, $color);
    }

    /** Windows: ANSI escapes and UTF-8 while the program runs; the old code page is restored on exit. */
    private static function prepareConsole(): void
    {
        if (PHP_OS_FAMILY !== 'Windows') {
            return;
        }
        if (function_exists('sapi_windows_vt100_support')) {
            @sapi_windows_vt100_support(STDOUT, true);
        }
        $current = trim((string) shell_exec('chcp'));
        if (preg_match('/(\d+)\s*$/', $current, $m) === 1 && $m[1] !== '65001') {
            shell_exec('chcp 65001 >nul');
            $old = $m[1];
            register_shutdown_function(static function () use ($old): void {
                shell_exec('chcp ' . $old . ' >nul');
            });
        }
    }
}