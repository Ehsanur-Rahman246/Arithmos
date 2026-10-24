# Runs both test programs; exit status 1 if either fails.
$pw = (Get-Process -Id $PID).Path
& $pw -NoProfile -File (Join-Path $PSScriptRoot 'run_cases.ps1')
$a = $LASTEXITCODE
& $pw -NoProfile -File (Join-Path $PSScriptRoot 'run_selector.ps1')
$b = $LASTEXITCODE
if ($a -ne 0 -or $b -ne 0) { exit 1 }
exit 0