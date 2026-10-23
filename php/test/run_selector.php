<?php
declare(strict_types=1);

/**
 * Selector tests SL1-SL21 (docs/test-cases.md) plus X2 and X3.
 *   php test/run_selector.php
 * Behaviour only: a fake keyboard and a fake screen, never a real terminal.
 */
require_once __DIR__ . '/../src/autoload.php';

use Arithmos\Cli\Io;
use Arithmos\Cli\KeyboardInterface;
use Arithmos\Cli\Pick;
use Arithmos\Cli\ScreenInterface;
use Arithmos\Cli\Selector;
use Arithmos\Cli\Text;

final class FakeKeyboard implements KeyboardInterface
{
    public function __construct(private array $keys)
    {
    }

    public function readKey(): string
    {
        return array_shift($this->keys) ?? 'CTRL_D';
    }
}

final class FakeScreen implements ScreenInterface
{
    public string $out = '';

    public function __construct(private int $cols = 80, private int $rows = 24)
    {
    }

    public function write(string $text): void
    {
        $this->out .= $text;
    }

    public function size(): array
    {
        return [$this->cols, $this->rows];
    }
}

/** A scripted Io: queued selector results and typed lines, with a record of what happened. */
final class Rig
{
    public string $out = '';
    public int $selectCalls = 0;
    public int $readCalls = 0;

    public function __construct(private array $selects = [], private array $lines = [])
    {
    }

    public function io(bool $withSelector): Io
    {
        return new Io(
            function (string $t): void {
                $this->out .= $t;
            },
            function (string $p): ?string {
                $this->readCalls++;
                $this->out .= $p;
                return array_shift($this->lines);
            },
            $withSelector ? function (string $title, array $labels, array $offer): array {
                $this->selectCalls++;
                return array_shift($this->selects) ?? ['type' => 'abort'];
            } : null,
            false
        );
    }
}

$passed = 0;
$failed = 0;
$ids = [];
function t(string $id, callable $fn): void
{
    global $passed, $failed, $ids;
    $ids[] = $id;
    try {
        $fn();
        $passed++;
    } catch (\Throwable $e) {
        $failed++;
        echo "FAIL $id: " . $e->getMessage() . "\n";
    }
}
function eq(mixed $got, mixed $want, string $what = ''): void
{
    if ($got !== $want) {
        throw new \RuntimeException($what . ' expected ' . var_export($want, true) . ', got ' . var_export($got, true));
    }
}
function yes(bool $c, string $what = 'assertion failed'): void
{
    if (!$c) {
        throw new \RuntimeException($what);
    }
}
function offer(bool $back = false, bool $quit = false, bool $typing = false): array
{
    return ['back' => $back, 'quit' => $quit, 'typing' => $typing];
}
/** Press keys one after another on a fresh state; returns [state, last action]. */
function press(array $state, array $keys, array $offer): array
{
    $action = null;
    foreach ($keys as $k) {
        [$state, $action] = Selector::handleKey($state, $k, $offer);
    }
    return [$state, $action];
}

$opts = [
    ['key' => '1', 'label' => 'alpha', 'aliases' => []],
    ['key' => '2', 'label' => 'km — kilometre', 'aliases' => ['km', 'kilometre']],
    ['key' => '3', 'label' => 'gamma', 'aliases' => []],
];

// ---- key handling ---------------------------------------------------------------------
t('SL1', function () {
    $s = Selector::newState(3, 3);
    eq(press($s, ['UP'], offer())[0]['index'], 2, 'up wraps');
    eq(press($s, ['DOWN', 'DOWN', 'DOWN'], offer())[0]['index'], 0, 'down wraps');
    eq(press($s, ['END'], offer())[0]['index'], 2, 'end');
    eq(press($s, ['END', 'HOME'], offer())[0]['index'], 0, 'home');
});
t('SL2', function () {
    eq(Selector::windowSize(25, 40), 10, 'window of 10');
    [$s] = press(Selector::newState(25, 10), array_fill(0, 12, 'DOWN'), offer());
    eq($s['index'], 12);
    yes($s['index'] >= $s['top'] && $s['index'] < $s['top'] + 10, 'selected row stays visible');
    eq($s['top'], 3, 'scrolled');
});
t('SL3', function () {
    $s = Selector::newState(3, 3);
    eq(press($s, ['DOWN', 'ENTER'], offer())[1], ['type' => 'select', 'index' => 1]);
    eq(press($s, ['ESC'], offer())[1], null, 'Esc not offered');
    eq(press($s, ['ESC'], offer(true))[1], ['type' => 'back']);
    eq(press($s, ['b'], offer())[1], null, 'b not offered');
    eq(press($s, ['b'], offer(true))[1], ['type' => 'back']);
    eq(press($s, ['q'], offer())[1], null, 'q not offered');
    eq(press($s, ['q'], offer(false, true))[1], ['type' => 'quit']);
});
t('SL4', function () {
    $s = Selector::newState(3, 3);
    eq(press($s, ['CTRL_C'], offer())[1], ['type' => 'abort']);
    eq(press($s, ['CTRL_D'], offer())[1], ['type' => 'abort']);
    [$after, $action] = press($s, ['OTHER'], offer(true, true, true));
    eq($after, $s, 'other control keys change nothing');
    eq($action, null);
});
t('SL5', function () {
    eq(press(Selector::newState(3, 3), ['x'], offer(false, false, true))[1], ['type' => 'typed', 'char' => 'x']);
    eq(press(Selector::newState(3, 3), ['7'], offer(false, false, true))[1], ['type' => 'typed', 'char' => '7']);
});
t('SL6', function () {
    eq(press(Selector::newState(3, 3), ['x'], offer())[1], null);
});
t('SL7', function () {
    $o = offer(true, true, true);
    $s = Selector::newState(3, 3);
    eq(press($s, ['ESC'], $o)[1], ['type' => 'back']);
    eq(press($s, ['b'], $o)[1], ['type' => 'back']);
    eq(press($s, ['q'], $o)[1], ['type' => 'quit']);
    eq(press($s, ['DOWN'], $o)[0]['index'], 1);
    eq(press($s, ['ENTER'], $o)[1], ['type' => 'select', 'index' => 0]);
});
t('SL8', function () {
    $o = offer(true, true, true);
    $s = Selector::newState(3, 3);
    eq(press($s, [' '], $o)[1], null, 'space');
    eq(press($s, ['OTHER'], $o)[1], null, 'control key');
});

// ---- drawing ---------------------------------------------------------------------------
t('SL9', function () {
    $s = Selector::newState(3, 3);
    $s['index'] = 1;
    $lines = Selector::render('T', ['one', 'two', 'three'], $s, offer(), true, 40);
    yes(str_contains($lines[2], "\e[7m") && str_contains($lines[2], '❯'), 'selected row is a reverse-video bar');
    yes(!str_contains($lines[1], "\e[7m") && !str_contains($lines[3], "\e[7m"), 'only one bar');
});
t('SL10', function () {
    $s = Selector::newState(3, 3);
    $lines = Selector::render('T', ['one', 'two', 'three'], $s, offer(), false, 40);
    yes(str_starts_with($lines[1], '❯ one'), 'pointer marks the row');
    yes(!str_contains(implode('', $lines), "\e["), 'no escape codes without colour');
});
t('SL11', function () {
    $h = Selector::hint(offer(), Selector::newState(3, 3));
    yes(str_contains($h, 'Enter') && !str_contains($h, 'back') && !str_contains($h, 'quit') && !str_contains($h, 'type'), $h);
});
t('SL12', function () {
    $h = Selector::hint(offer(true, true, true), Selector::newState(3, 3));
    yes(str_contains($h, 'Esc/b back') && str_contains($h, 'q quit') && str_contains($h, 'or type'), $h);
});

// ---- draw/read loop ----------------------------------------------------------------------
t('SL13', function () {
    $scr = new FakeScreen();
    $r = Selector::run(new FakeKeyboard(['DOWN', 'ENTER']), $scr, false, 'Pick', ['a', 'b', 'c'], offer());
    eq($r, ['type' => 'select', 'index' => 1]);
    yes(str_contains($scr->out, "✔ Pick: b\n"), 'summary left behind');
    yes(str_ends_with($scr->out, "\e[?25h"), 'cursor restored');
    yes(str_starts_with($scr->out, "\e[?25l"), 'cursor hidden while drawing');
});
t('SL14', function () {
    eq(Selector::run(new FakeKeyboard(['OTHER', 'ESC']), new FakeScreen(), false, 'P', ['a', 'b'], offer(true)), ['type' => 'back']);
    $scr = new FakeScreen();
    eq(Selector::run(new FakeKeyboard(['CTRL_C']), $scr, false, 'P', ['a', 'b'], offer()), ['type' => 'abort']);
    yes(str_ends_with($scr->out, "\e[?25h"));
});
t('SL15', function () {
    $scr = new FakeScreen();
    eq(Selector::run(new FakeKeyboard(['x']), $scr, false, 'P', ['a', 'b'], offer(false, false, true)), ['type' => 'typed', 'char' => 'x']);
    yes(str_ends_with($scr->out, "\e[?25h"), 'cursor restored');
});

// ---- pick() over an injectable Io --------------------------------------------------------
t('SL16', function () use ($opts) {
    $rig = new Rig([['type' => 'select', 'index' => 1]]);
    eq(Pick::pick($rig->io(true), 'T', $opts, true), ['type' => 'choice', 'index' => 1]);
});
t('SL17', function () use ($opts) {
    $rig = new Rig([['type' => 'typed', 'char' => '2']], ['']);
    eq(Pick::pick($rig->io(true), 'T', $opts, true), ['type' => 'choice', 'index' => 1], 'number');
    $rig = new Rig([['type' => 'typed', 'char' => 'k']], ['m']);
    eq(Pick::pick($rig->io(true), 'T', $opts, true), ['type' => 'choice', 'index' => 1], 'symbol');
    $rig = new Rig([['type' => 'typed', 'char' => 'g']], ['amma']);
    eq(Pick::pick($rig->io(true), 'T', $opts, true), ['type' => 'choice', 'index' => 2], 'name');
});
t('SL18', function () use ($opts) {
    $rig = new Rig([['type' => 'typed', 'char' => 'l'], ['type' => 'select', 'index' => 0]], ['ist']);
    $ran = [];
    $cmd = function (string $line) use (&$ran): bool {
        $ran[] = $line;
        return true;
    };
    eq(Pick::pick($rig->io(true), 'T', $opts, true, true, $cmd), ['type' => 'choice', 'index' => 0]);
    eq($ran, ['list'], 'command ran');
    eq($rig->selectCalls, 2, 'the list came back');
});
t('SL19', function () use ($opts) {
    $rig = new Rig([['type' => 'typed', 'char' => 'z'], ['type' => 'select', 'index' => 0]], ['zz']);
    eq(Pick::pick($rig->io(true), 'T', $opts, true), ['type' => 'choice', 'index' => 0]);
    yes(str_contains($rig->out, 'Error [UNKNOWN_COMMAND]: Pick one from the list'), 'error shown');
    eq($rig->selectCalls, 2, 'the list came back');
});
t('SL20', function () use ($opts) {
    foreach ([['back', 'back'], ['quit', 'quit']] as [$type, $want]) {
        $rig = new Rig([['type' => $type]]);
        eq(Pick::pick($rig->io(true), 'T', $opts, true), ['type' => $want]);
        eq($rig->readCalls, 0, 'no prompt line for ' . $type);
    }
});
t('SL21', function () use ($opts) {
    $rig = new Rig([], ['x', '2']);
    eq(Pick::pick($rig->io(false), 'Title', $opts, true), ['type' => 'choice', 'index' => 1]);
    yes(str_contains($rig->out, "Title\n  1) alpha\n  2) km — kilometre\n  3) gamma\n"), 'numbered rows');
    yes(str_contains($rig->out, 'Error [UNKNOWN_COMMAND]'), 'bad answer is an error');
    $rig = new Rig([], ['GAMMA']);
    eq(Pick::pick($rig->io(false), 'T', $opts, true), ['type' => 'choice', 'index' => 2], 'name, any case');
    $rig = new Rig([], ['back']);
    eq(Pick::pick($rig->io(false), 'T', $opts, true), ['type' => 'back']);
    $rig = new Rig([], ['back', 'quit']);
    eq(Pick::pick($rig->io(false), 'T', $opts, false), ['type' => 'quit'], 'back is an error where it is not offered');
    $rig = new Rig([], []);
    eq(Pick::pick($rig->io(false), 'T', $opts, true), ['type' => 'eof'], 'end of input');
});

// ---- PHP-edition extras --------------------------------------------------------------------
t('X2', function () { // lines never wider than the terminal; the window shrinks; erase moves up by the drawn count
    $labels = array_fill(0, 30, str_repeat('x', 200));
    eq(Selector::windowSize(30, 8), 5, 'short terminal');
    $state = Selector::newState(30, 5);
    $lines = Selector::render('A very long title ' . str_repeat('t', 100), $labels, $state, offer(true, true, true), false, 40);
    eq(count($lines), 7, 'window + title + hint');
    foreach ($lines as $line) {
        yes(Text::len($line) <= 39, 'line too wide: ' . Text::len($line));
    }
    $scr = new FakeScreen(40, 8);
    Selector::run(new FakeKeyboard(['ESC']), $scr, false, 'T', $labels, offer(true));
    yes(str_contains($scr->out, "\e[7A\e[J"), 'erase moves up 7 lines');
});
t('X3', function () { // raw terminal bytes -> keys
    eq(Selector::parseBytes("\e[A\e[B\e\r"), ['UP', 'DOWN', 'ESC', 'ENTER']);
    eq(Selector::parseBytes("\e[5~\e[6~\e[H\e[F\eOA"), ['PGUP', 'PGDN', 'HOME', 'END', 'UP']);
    eq(Selector::parseBytes("q"), ['q']);
    eq(Selector::parseBytes("\x03\x04\x7f\x01"), ['CTRL_C', 'CTRL_D', 'OTHER', 'OTHER']);
    eq(Selector::parseBytes('é'), ['é'], 'UTF-8 character');
});

$sl = count(array_filter($ids, fn($i) => str_starts_with($i, 'SL')));
if ($sl !== 21) {
    echo "FAIL: expected 21 SL tests, found $sl\n";
    $failed++;
}
echo "selector tests: $passed passed, $failed failed (SL1-SL21 = $sl, plus X2, X3)\n";
exit($failed === 0 ? 0 : 1);