# The io object (ARCHITECTURE.md "CLI screens"): a hashtable of scriptblocks.
#   Write    { param($text) }       write text, no newline added
#   ReadLine { param($prompt) }     returns the line, or $null at end of input
#   Color    [bool]                 colours on (real terminal and no NO_COLOR)
#   Select   scriptblock or $null   arrow-key selector (real terminals only)
# Everything below this layer is I/O free.

function Format-ArStyle {
    param($Io, [string]$Kind, [string]$Text)
    if (-not $Io.Color) { return $Text }
    $code = ''
    if     ($Kind -eq 'bold')  { $code = '1' }
    elseif ($Kind -eq 'dim')   { $code = '2' }
    elseif ($Kind -eq 'red')   { $code = '31' }
    elseif ($Kind -eq 'green') { $code = '32' }
    if ($code -eq '') { return $Text }
    $esc = $global:ArEsc
    return "${esc}[${code}m${Text}${esc}[0m"
}

function Get-ArConsoleSize {
    try {
        $w = [Console]::WindowWidth
        $h = [Console]::WindowHeight
        if ($w -le 0) { $w = 80 }
        if ($h -le 0) { $h = 24 }
        return @{ W = $w; H = $h }
    }
    catch { return @{ W = 80; H = 24 } }
}

function Test-ArInteractive {
    # A real terminal: stdin and stdout are terminals, TERM is not dumb, ARITHMOS_PLAIN is not 1.
    return ((-not [Console]::IsInputRedirected) -and (-not [Console]::IsOutputRedirected) `
            -and ($env:TERM -ne 'dumb') -and ($env:ARITHMOS_PLAIN -ne '1'))
}

function New-ArRealIo {
    $interactive = Test-ArInteractive
    $colorOk = (-not [Console]::IsOutputRedirected) -and (-not $env:NO_COLOR)
    $io = @{
        Write    = { param([string]$Text) [Console]::Out.Write($Text) }
        ReadLine = {
            param([string]$Prompt)
            [Console]::Out.Write($Prompt)
            [Console]::Out.Flush()
            return [Console]::In.ReadLine()          # $null at EOF
        }
        Color    = [bool]$colorOk
        Select   = $null
    }
    if ($interactive) { $io.Select = New-ArRealSelect }
    return $io
}