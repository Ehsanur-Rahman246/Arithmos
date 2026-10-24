# Loads every source file in dependency order.
# MUST be dot-sourced from a script (never from inside a function), otherwise the
# functions vanish when that function returns:
#     . "$PSScriptRoot/../src/autoload.ps1"
$ArSrc = $PSScriptRoot

. (Join-Path $ArSrc 'shared/errors.ps1')
. (Join-Path $ArSrc 'shared/format-number.ps1')
. (Join-Path $ArSrc 'calculator/calculator.ps1')
. (Join-Path $ArSrc 'programmer/programmer.ps1')
. (Join-Path $ArSrc 'converter/units.ps1')
. (Join-Path $ArSrc 'converter/converter.ps1')
. (Join-Path $ArSrc 'cli/io.ps1')
. (Join-Path $ArSrc 'cli/selector.ps1')
. (Join-Path $ArSrc 'cli/pick.ps1')
. (Join-Path $ArSrc 'cli/tools.ps1')
. (Join-Path $ArSrc 'cli/cli.ps1')