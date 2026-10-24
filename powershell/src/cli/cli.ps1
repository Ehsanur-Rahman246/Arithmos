# Entry logic: interactive menu or one-shot mode.
# One-shot: results to stdout, Error [CODE] lines and usage-after-bad-input to stderr.
# Exit status: 0 success, 1 the line produced an Error [CODE], 2 bad usage.

function Get-ArUsage {
    return @(
        'Usage:',
        '  arithmos                              interactive menu',
        '  arithmos std "<expression>"           one calculation',
        '  arithmos prog "<command>"             one programmer command',
        '  arithmos convert <value> <from> <to>  one conversion (to may be: all)',
        '  arithmos list [category]              list categories or units',
        'Quote anything PowerShell would interpret: "-8 >>> 1", "(2 + 3) * 4".'
    )
}

function Invoke-ArOneShot {
    param([string[]]$Argv)
    $out = [Console]::Out
    $err = [Console]::Error
    $cmd = $Argv[0].ToLowerInvariant()                       # the command word is case-insensitive
    $rest = @()
    if ($Argv.Count -gt 1) { $rest = @($Argv[1..($Argv.Count - 1)]) }
    $joined = ($rest -join ' ').Trim()

    if ($cmd -in @('--help', '-h', 'help', '?')) {
        foreach ($l in (Get-ArUsage)) { $out.WriteLine($l) }
        return 0
    }
    $tool = $null; $line = $null
    if     ($cmd -in @('std', 'standard'))   { $tool = 'standard';   $line = $joined }
    elseif ($cmd -in @('prog', 'programmer')) { $tool = 'programmer'; $line = $joined }
    elseif ($cmd -eq 'convert')              { $tool = 'converter';  $line = "convert $joined" }
    elseif ($cmd -eq 'list')                 { $tool = 'converter';  $line = "list $joined" }

    $bad = ($null -eq $tool) -or ($cmd -ne 'list' -and $joined -eq '')
    if ($bad) {
        foreach ($l in (Get-ArUsage)) { $err.WriteLine($l) }
        return 2
    }
    $res = Invoke-ArLine $tool $line (New-ArSession $tool)
    if ($res.Code) {
        $err.WriteLine("Error [$($res.Code)]: $($res.Message)")
        return 1
    }
    foreach ($l in $res.Lines) { $out.WriteLine($l) }
    return 0
}

function Start-ArCli {
    param([string[]]$Argv)
    # UTF-8 so ❯ ✔ → — render; restored on exit.
    $oldOut = $null; $oldIn = $null
    try {
        $oldOut = [Console]::OutputEncoding
        $oldIn  = [Console]::InputEncoding
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
    }
    catch { }
    try {
        if ($Argv.Count -eq 0) {
            $io = New-ArRealIo
            $null = Start-ArMenu $io
            return 0
        }
        return (Invoke-ArOneShot $Argv)
    }
    finally {
        try {
            if ($oldOut) { [Console]::OutputEncoding = $oldOut }
            if ($oldIn)  { [Console]::InputEncoding  = $oldIn }
            [Console]::Out.Write("$($global:ArEsc)[?25h")     # cursor visible, whatever happened
        }
        catch { }
    }
}