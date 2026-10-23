<?php
declare(strict_types=1);

/**
 * Runs the shared cases (docs/release-1-cases.json) and the PHP extras.
 *   php test/run_cases.php [path/to/cases.json]
 * Loader contract (docs/test-cases.md): branch on string/object `expected`, run
 * `setup` first or `steps` in order in ONE session, assert results and codes
 * (never prompt text), and never skip a case.
 */
require_once __DIR__ . '/../src/autoload.php';

use Arithmos\Calculator\Calculator;
use Arithmos\Calculator\StandardSession;
use Arithmos\Cli\Cli;
use Arithmos\Cli\Io;
use Arithmos\Cli\Render;
use Arithmos\Cli\Tools;
use Arithmos\Converter\Converter;
use Arithmos\Converter\Units;
use Arithmos\Programmer\Format;
use Arithmos\Programmer\Programmer;
use Arithmos\Programmer\ProgrammerSession;
use Arithmos\Shared\ArithmosError;
use Arithmos\Shared\FormatNumber;

/**
 * Run one line. Returns ['ok', string|array] or ['err', CODE].
 *
 * @param StandardSession|ProgrammerSession|null $session
 * @return array{0:string,1:mixed}
 */
function runLine(string $tool, string $line, $session): array
{
    try {
        if ($tool === 'standard') {
            return ['ok', FormatNumber::format(Calculator::evaluate($line, $session))];
        }
        if ($tool === 'programmer') {
            $r = Programmer::execute($line, $session);
            if ($r['kind'] === 'value') {
                return ['ok', Format::all($r['value'])];
            }
            return ['ok', $r['kind'] === 'text' ? $r['text'] : $r['base']];
        }
        return ['ok', Render::converter(Converter::run($line))];
    } catch (ArithmosError $e) {
        return ['err', $e->errorCode()];
    }
}

/** Compare one outcome with a case/step. Returns null when it matches. */
function judge(array $want, array $got): ?string
{
    if (isset($want['error'])) {
        return ($got[0] === 'err' && $got[1] === $want['error']) ? null
            : 'expected error ' . $want['error'] . ', got ' . json_encode($got);
    }
    if ($got[0] === 'err') {
        return 'unexpected error ' . $got[1];
    }
    if (isset($want['expectedContains'])) {
        $lines = explode("\n", (string) $got[1]);
        foreach ($want['expectedContains'] as $needle) {
            if (!in_array($needle, $lines, true)) {
                return "missing line '$needle'";
            }
        }
        return null;
    }
    $exp = $want['expected'];
    if (is_array($exp)) {
        if (!is_array($got[1])) {
            return 'expected an object of bases, got ' . json_encode($got[1]);
        }
        foreach ($exp as $k => $v) {
            if (($got[1][$k] ?? null) !== $v) {
                return "$k expected $v, got " . ($got[1][$k] ?? 'null');
            }
        }
        return null;
    }
    return $got[1] === $exp ? null : "expected '$exp', got " . json_encode($got[1]);
}

/** @return StandardSession|ProgrammerSession|null */
function newSession(string $tool)
{
    return $tool === 'standard' ? new StandardSession() : ($tool === 'programmer' ? new ProgrammerSession() : null);
}

$failed = 0;
$total = 0;
function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed, $total;
    $total++;
    if (!$ok) {
        $failed++;
        echo "FAIL $name $detail\n";
    }
}

// ---- shared cases -------------------------------------------------------------
$path = $argv[1] ?? __DIR__ . '/../../docs/release-1-cases.json';
$cases = json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
check('case file has 175 cases', count($cases) === 175, 'got ' . count($cases));
foreach ($cases as $case) {
    $session = newSession($case['tool']);
    foreach ($case['setup'] ?? [] as $setup) {
        runLine($case['tool'], $setup, $session);
    }
    $steps = $case['steps'] ?? [$case];
    foreach ($steps as $n => $step) {
        $why = judge($step, runLine($case['tool'], $step['input'], $session));
        check($case['id'] . (isset($case['steps']) ? '/' . ($n + 1) : ''), $why === null, (string) $why);
    }
}
$shared = $total;

// ---- extras: number formatting boundaries ------------------------------------------------
foreach ([
    [100000000000.5, '100000000001'], [-100000000000.5, '-100000000001'], [0.1 + 0.2, '0.3'],
    [123456789012345.0, '123456789012000'], [1e15, '1e+15'], [999999999999999.0, '1e+15'],
    [0.000001, '0.000001'], [0.0000001, '1e-7'], [-0.0, '0'], [1.5e20, '1.5e+20'], [2e-7, '2e-7'],
    [9.9999999999995e-7, '0.000001'], [1 / 3, '0.333333333333'], [1.0, '1'], [-2.5, '-2.5'],
] as [$x, $want]) {
    check("format($want)", FormatNumber::format($x) === $want, FormatNumber::format($x));
}
foreach ([NAN, INF, -INF] as $bad) {
    try {
        FormatNumber::format($bad);
        check('format rejects NaN/Inf', false);
    } catch (ArithmosError $e) {
        check('format rejects NaN/Inf', true);
    }
}

// ---- extras: settled amendments (R1-R10, R12-R15, R29, R30) -----------------------------
$std = fn(string $l): array => runLine('standard', $l, new StandardSession());
foreach ([
    ['200 + (10%)', '200.1'], ['200 + 5 * 10%', '200.5'], ['2^50%', '1.41421356237'], ['50%%', '0.005'],
    ['5 of 10', '50'], ['ANS', '0'], ['10^-400', '0'], ['SQRT(16)', '4'], ['  2 +  3  ', '5'], ['.5 + 5.', '5.5'],
    ['--5', '5'], ['2^-2', '0.25'], ['(-8)^3', '-512'], ['200 / 10%', '2000'], ['100000000000.5', '100000000001'],
] as [$in, $want]) {
    check("std $in", $std($in) === ['ok', $want], json_encode($std($in)));
}
foreach (['1e5', '5.5.5', '.', '2 $ 3', 'sqrt 4', 'of 5', '()', '', '2 3', '(-8)^(1/3)', str_repeat('(', 5000) . '1'] as $in) {
    $r = $std($in);
    check("std rejects '" . substr($in, 0, 12) . "'", $r[0] === 'err', json_encode($r));
}

$prog = function (string $l, string $base = 'dec'): array {
    $s = new ProgrammerSession();
    $s->base = $base;
    return runLine('programmer', $l, $s);
};
check('prog 1<<3', ($prog('1<<3')[1]['DEC'] ?? '') === '8');
check('prog -8>>>1', ($prog('-8>>>1')[1]['DEC'] ?? '') === '9223372036854775804');
check('prog NOT 0xFF', ($prog('NOT 0xFF')[1]['DEC'] ?? '') === '-256');
check('prog -0x80', ($prog('-0x80')[1]['DEC'] ?? '') === '-128');
check('prog -2^63 magnitude', ($prog('-9223372036854775808')[1]['DEC'] ?? '') === '-9223372036854775808');
check('prog -9223372036854775809', $prog('-9223372036854775809') === ['err', 'OUT_OF_RANGE']);
check('prog convert FFFFFFFFFFFFFFFF', $prog('convert FFFFFFFFFFFFFFFF hex dec') === ['ok', '-1']);
check('prog 0B in hex mode is 11', ($prog('0B', 'hex')[1]['DEC'] ?? '') === '11');
check('prog 0x in dec mode', $prog('0x') === ['err', 'INVALID_DIGIT']);
check('prog A AND F in hex', ($prog('A AND F', 'hex')[1]['DEC'] ?? '') === '10');
check('prog DEC in hex', ($prog('DEC', 'hex')[1]['DEC'] ?? '') === '3564');
check('prog 1 << 0x3', $prog('1 << 0x3') === ['err', 'INVALID_SHIFT']);
check('prog 1 << 2.5', $prog('1 << 2.5') === ['err', 'INVALID_SHIFT']);
check('prog 1.5', $prog('1.5') === ['err', 'INVALID_NUMBER']);
check('prog 5 AND', $prog('5 AND') === ['err', 'UNKNOWN_COMMAND']);
check('prog convert 1 dec', $prog('convert 1 dec') === ['err', 'UNKNOWN_COMMAND']);
check('prog base (no name)', $prog('base') === ['err', 'INVALID_BASE']);
check('prog base HEX prints lower-case', Render::programmer(Programmer::execute('base HEX', new ProgrammerSession())) === 'Input base: hex');
check('prog 0 | 1<<63 grid', ($prog('0x8000000000000000')[1]['BIN'] ?? '') === '1' . str_repeat('0', 63));
check('prog empty', $prog('') === ['err', 'UNKNOWN_COMMAND']);

$conv = fn(string $l): array => runLine('converter', $l, null);
check('conv list', $conv('list') === ['ok', 'length, mass, area, volume, time, speed, digital, energy, power, pressure, angle, temperature']);
check('conv list length', str_starts_with($conv('list length')[1], 'pm, ang, nm, um, mm, cm, m, km, in, ft, yd, mi, nmi, au, ly'));
check('conv list foo', $conv('list foo') === ['err', 'UNKNOWN_COMMAND']);
check('conv list a b', $conv('list a b') === ['err', 'UNKNOWN_COMMAND']);
check('conv 1e3', $conv('convert 1e3 m cm') === ['err', 'INVALID_NUMBER']);
check('conv huge value', $conv('convert ' . str_repeat('9', 400) . ' m cm') === ['err', 'OVERFLOW']);
check('conv huge result', $conv('convert 1' . str_repeat('0', 300) . ' ly pm') === ['err', 'OVERFLOW']);
check('conv shorthand', $conv('100 cm in') === ['ok', '39.3700787402']);
check('conv -273.15 c all', $conv('convert -273.15 c all')[0] === 'ok');
check('conv 0 k all', $conv('convert 0 k all')[0] === 'ok');
check('conv -459.67 f c', $conv('convert -459.67 f c')[0] === 'ok');
check('conv below 0 f', $conv('convert -460 f c') === ['err', 'BELOW_ABSOLUTE_ZERO']);
// table order (pm, ang, nm, ...), source unit included; 1e12 < 1e15 so it prints in plain notation
check('conv all is table order', str_starts_with($conv('convert 1 m all')[1], "pm: 1000000000000\nang: 10000000000\nnm: 1000000000\n"));
check('conv empty', $conv('') === ['err', 'UNKNOWN_COMMAND']);
$seen = [];
$dupes = 0;
foreach (Units::categories() as $cat) {
    foreach ($cat['units'] as $u) {
        $dupes += isset($seen[$u[0]]) ? 1 : 0;
        $seen[$u[0]] = true;
    }
}
check('unit symbols unique and lower-case', $dupes === 0 && count(array_filter(array_keys($seen), fn($s) => $s !== strtolower((string) $s))) === 0);
check('twelve categories', count(Units::categories()) === 12);

// ---- extras: garbage input never crashes ------------------------------------------------
mt_srand(7);
$alphabet = str_split("0123456789abcxyzABCXYZ +-*/^%().<>=!?:;,'\"_\t é€");
$crashes = 0;
for ($i = 0; $i < 600; $i++) {
    $line = '';
    for ($j = mt_rand(0, 14); $j > 0; $j--) {
        $line .= $alphabet[mt_rand(0, count($alphabet) - 1)];
    }
    foreach (['standard', 'programmer', 'converter'] as $tool) {
        try {
            runLine($tool, $line, newSession($tool));
        } catch (\Throwable $e) {
            $crashes++;
            echo "CRASH [$tool] " . json_encode($line) . ': ' . $e->getMessage() . "\n";
        }
    }
}
check('garbage input: no crash', $crashes === 0);

// ---- extras: scripted CLI sessions (fake Io, numbered-list mode) -------------------------
function session(array $lines, callable $tool): string
{
    $out = '';
    $io = new Io(
        function (string $t) use (&$out): void { $out .= $t; },
        function (string $p) use (&$out, &$lines): ?string { $out .= $p; return array_shift($lines); }
    );
    $tool($io);
    return $out;
}
$out = session(['25 + 17', 'ans * 2', '10 / 0', '', '?', 'back'], fn($io) => Tools::standard($io));
check('session standard', str_contains($out, "42\n") && str_contains($out, "84\n")
    && str_contains($out, 'Error [DIV_BY_ZERO]: Cannot divide by zero') && str_contains($out, 'Commands: help'));
$out = session(['0xFF', 'base hex', 'FF AND 0F', 'quit'], fn($io) => Tools::programmer($io));
check('session programmer', str_contains($out, "HEX: FF\nDEC: 255\nOCT: 377\n") && str_contains($out, 'Input base: hex')
    && str_contains($out, "DEC: 15\n"));
$out = session(['1', '1', '2', '100', 'quit'], fn($io) => Tools::converter($io));
check('session converter guided', str_contains($out, 'Unit Converter — choose a category')
    && str_contains($out, 'Length — convert from') && str_contains($out, 'converter (pm → ang)> ')
    && str_contains($out, ' = '));
$out = session(['1', '2', '3', '100', 'quit'], fn($io) => Tools::converter($io)); // length, pm?, ang?...
check('session converter values prompt', str_contains($out, 'converter (') && str_contains($out, ' = '));
$out = session(['nonsense', 'back'], fn($io) => Tools::converter($io));
check('session converter bad pick', str_contains($out, 'Error [UNKNOWN_COMMAND]: Pick one from the list'));

// ---- extras: one-shot mode and exit codes ------------------------------------------------
function oneShot(array $args): array
{
    $o = fopen('php://memory', 'w+');
    $e = fopen('php://memory', 'w+');
    $code = Cli::oneShot($args, $o, $e);
    rewind($o);
    rewind($e);
    return [$code, stream_get_contents($o), stream_get_contents($e)];
}
check('one-shot std', oneShot(['std', '20% of 150']) === [0, "30\n", '']);
check('one-shot STANDARD (case-insensitive)', oneShot(['STANDARD', '2+3'])[0] === 0);
check('one-shot prog', oneShot(['prog', '0xFF', 'AND', '0x0F'])[1] === "HEX: F\nDEC: 15\nOCT: 17\nBIN: 1111\n");
check('one-shot convert', oneShot(['convert', '100', 'cm', 'in']) === [0, "39.3700787402\n", '']);
check('one-shot list', oneShot(['list', 'length'])[0] === 0);
$r = oneShot(['std', '10 / 0']);
check('one-shot error -> stderr, exit 1', $r[0] === 1 && $r[1] === '' && str_starts_with($r[2], 'Error [DIV_BY_ZERO]'));
$r = oneShot(['bogus']);
check('one-shot bad usage -> exit 2', $r[0] === 2 && $r[1] === '' && str_starts_with($r[2], 'Usage:'));
check('one-shot std without args -> exit 2', oneShot(['std'])[0] === 2);
check('one-shot --help -> stdout, exit 0', oneShot(['--help'])[0] === 0 && str_starts_with(oneShot(['--help'])[1], 'Usage:'));

echo "\nshared cases: $shared run\n";
echo 'total checks: ' . $total . ', failed: ' . $failed . "\n";
exit($failed === 0 ? 0 : 1);