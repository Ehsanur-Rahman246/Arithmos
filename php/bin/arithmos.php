#!/usr/bin/env php
<?php
declare(strict_types=1);

// Entry point: argv -> Cli::main. Nothing else lives here.
require_once __DIR__ . '/../src/autoload.php';

exit(\Arithmos\Cli\Cli::main($argv));