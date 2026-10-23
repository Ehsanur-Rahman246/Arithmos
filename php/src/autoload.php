<?php
declare(strict_types=1);

// Plain require list: no Composer, no dependencies (standard library only).
// Order matters only in that a file may use classes from files above it.
foreach ([
    'shared/errors.php',
    'shared/format_number.php',
    'calculator/tokenizer.php',
    'calculator/parser.php',
    'calculator/evaluator.php',
    'calculator/calculator.php',
    'programmer/int64.php',
    'programmer/parse.php',
    'programmer/programmer.php',
    'converter/units.php',
    'converter/converter.php',
    'cli/io.php',
    'cli/selector.php',
    'cli/terminal.php',
    'cli/pick.php',
    'cli/render.php',
    'cli/tools.php',
    'cli/cli.php',
] as $file) {
    require_once __DIR__ . '/' . $file;
}