# pick(): one question, many answers (ARCHITECTURE.md "CLI screens").
#   Options : array of @{ Label; Num (optional display number); Names (optional aliases); ... }
#   OnLine  : $null or scriptblock { param($text) } -> $true when it ran the text as a command
# Returns   : @{ Type = 'choice'; Index; Option } | @{ Type = 'back' } | @{ Type = 'quit' } | @{ Type = 'eof' }
# With io.Select it is the arrow-key selector (typing still works); otherwise a numbered
# list answered by typing a number, a name or a symbol.

function Find-ArOption {
    param([object[]]$Options, [string]$Text)
    $t = $Text.Trim()
    $num = 0
    if ([int]::TryParse($t, [ref]$num)) {
        for ($i = 0; $i -lt $Options.Count; $i++) {
            if ($Options[$i].Num -eq $num) { return $i }
        }
    }
    $low = $t.ToLowerInvariant()
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $o = $Options[$i]
        if ($o.Label.ToLowerInvariant() -eq $low) { return $i }
        if ($o.Names) {
            foreach ($n in $o.Names) { if ("$n".ToLowerInvariant() -eq $low) { return $i } }
        }
    }
    return -1
}

function Write-ArError {
    param($Io, [string]$Code, [string]$Message)
    $write = $Io.Write
    & $write ((Format-ArStyle $Io 'red' "Error [${Code}]: $Message") + "`n")
}

function Invoke-ArPick {
    param($Io, [string]$Title, [object[]]$Options, [bool]$Back, [bool]$Quit, $OnLine)
    $write    = $Io.Write
    $readLine = $Io.ReadLine
    $select   = $Io.Select

    for ($i = 0; $i -lt $Options.Count; $i++) {
        if (-not $Options[$i].ContainsKey('Num')) { $Options[$i].Num = $i + 1 }
    }
    $labels  = @($Options | ForEach-Object { [string]$_.Label })
    $selOpts = @{ Back = $Back; Quit = $Quit; Typing = $true }
    $shown = $false

    while ($true) {
        $text = $null
        if ($select) {
            # Arrow-key selector. b / q / Esc act at once: no prompt line.
            $r = & $select $Title $labels $selOpts
            if ($r.Type -eq 'select') { return @{ Type = 'choice'; Index = $r.Index; Option = $Options[$r.Index] } }
            if ($r.Type -eq 'back')   { return @{ Type = 'back' } }
            if ($r.Type -eq 'quit')   { return @{ Type = 'quit' } }
            if ($r.Type -ne 'typed')  { return @{ Type = 'eof' } }            # Ctrl-C / Ctrl-D
            # A printable key opens a typed line: the prompt shows the key, the rest is read.
            $rest = & $readLine ('> ' + $r.Char)
            if ($null -eq $rest) { return @{ Type = 'eof' } }
            $text = $r.Char + $rest
        }
        else {
            # Numbered list (pipes, files, tests, ARITHMOS_PLAIN=1).
            if (-not $shown) {
                & $write ((Format-ArStyle $Io 'bold' $Title) + "`n")
                foreach ($o in $Options) { & $write ("  $($o.Num)) $($o.Label)`n") }
                $shown = $true
            }
            $text = & $readLine '> '
            if ($null -eq $text) { return @{ Type = 'eof' } }
        }

        $t = $text.Trim()
        if ($t -eq '') { continue }
        $low = $t.ToLowerInvariant()
        if ($low -eq 'help' -or $low -eq '?') {
            & $write "Pick with the arrow keys, or type a number, a name or a symbol. Commands: help, back, quit.`n"
            continue
        }
        if ($low -eq 'quit') { return @{ Type = 'quit' } }
        if ($low -eq 'back' -and $Back) { return @{ Type = 'back' } }

        $idx = Find-ArOption $Options $t
        if ($idx -ge 0) { return @{ Type = 'choice'; Index = $idx; Option = $Options[$idx] } }

        if ($OnLine -and (& $OnLine $t)) { continue }                          # a one-line command ran
        Write-ArError $Io 'UNKNOWN_COMMAND' 'Pick one from the list'           # list comes back
    }
}