# Tool bindings: prompt loops, the guided converter and the main menu.
# This is the only layer that turns engine results into text.

function New-ArSession {
    param([string]$Tool)
    if ($Tool -eq 'standard')   { return @{ Ans = [double]0 } }
    if ($Tool -eq 'programmer') { return @{ Base = 'dec' } }
    return @{}
}

# Run a body and catch ArithmosError (code in Exception.Data). Never lets an exception
# escape: unexpected ones become INTERNAL, so invalid input cannot crash the program.
function Invoke-ArSafe {
    param([scriptblock]$Body)
    try {
        $lines = @(& $Body)
        return @{ Lines = $lines; Code = $null; Message = $null }
    }
    catch {
        $code = $_.Exception.Data['ArCode']
        if (-not $code) { $code = 'INTERNAL' }
        return @{ Lines = @(); Code = [string]$code; Message = $_.Exception.Message }
    }
}

# One line of one tool -> @{ Lines; Code; Message }.  Used by the CLI and by the tests.
function Invoke-ArLine {
    param([string]$Tool, [string]$Line, $Session)
    return Invoke-ArSafe {
        if ($Tool -eq 'standard') { Invoke-ArStandard $Line $Session }
        elseif ($Tool -eq 'programmer') { Get-ArProgrammerLines (Invoke-ArProgrammer $Line $Session) }
        else { Invoke-ArConverter $Line }
    }
}

function Write-ArResult {
    param($Io, [hashtable]$Res)
    $write = $Io.Write
    if ($Res.Code) { Write-ArError $Io $Res.Code $Res.Message; return }
    foreach ($l in $Res.Lines) { & $write ($l + "`n") }
}

# Prompt loop shared by the three tools. Returns 'back', 'quit' or 'eof'.
# help / ?, back, quit are case-insensitive; blank lines are ignored.
function Invoke-ArToolLoop {
    param($Io, [string]$Prompt, [string[]]$Intro, [string[]]$Help, [scriptblock]$Run)
    $write    = $Io.Write
    $readLine = $Io.ReadLine
    foreach ($l in $Intro) { & $write ($l + "`n") }
    while ($true) {
        $line = & $readLine $Prompt
        if ($null -eq $line) { return 'eof' }
        $t = $line.Trim()
        if ($t -eq '') { continue }
        $low = $t.ToLowerInvariant()
        if ($low -eq 'quit') { return 'quit' }
        if ($low -eq 'back') { return 'back' }
        if ($low -eq 'help' -or $low -eq '?') {
            foreach ($h in $Help) { & $write ($h + "`n") }
            continue
        }
        Write-ArResult $Io (& $Run $t)
    }
}

function Invoke-ArStandardTool {
    param($Io, [hashtable]$Session)
    $intro = @('Standard Calculator. Type an expression, e.g. 2 + 3 * 4. Type help for commands.')
    $help = @(
        'Operators: + - * / ^   unary + -   parentheses   % (postfix)   of',
        'Functions: sqrt(x) abs(x)   Previous result: ans',
        'Examples:  20% of 150   200 + 10%   2^3^2   sqrt(16)',
        'Commands:  help (or ?), back, quit'
    )
    $run = { param($l) Invoke-ArLine 'standard' $l $Session }.GetNewClosure()
    return Invoke-ArToolLoop $Io 'standard> ' $intro $help $run
}

function Invoke-ArProgrammerTool {
    param($Io, [hashtable]$Session)
    $intro = @('Programmer Calculator (64-bit signed). Type a number or a command. Type help for commands.')
    $help = @(
        'Value:     0xFF   0b101   0o17   0d9   (a prefix overrides the input base)',
        'Base:      base bin | oct | dec | hex   (sets the input base)',
        'Convert:   [convert] <value> <from> <to>   e.g. 255 dec hex',
        'Bitwise:   <a> AND|OR|XOR <b>    NOT <a>',
        'Shifts:    <a> << <n>   <a> >> <n> (arithmetic)   <a> >>> <n> (logical)   n is decimal 0-63',
        'Commands:  help (or ?), back, quit'
    )
    $run = { param($l) Invoke-ArLine 'programmer' $l $Session }.GetNewClosure()
    return Invoke-ArToolLoop $Io 'programmer> ' $intro $help $run
}

# Guided converter: category -> from -> to -> values. back steps back one stage and
# leaves to the main menu from the first. One-line commands work at every stage.
function Invoke-ArConverterTool {
    param($Io)
    $handler = {
        param($t)
        $w = @($t -split '\s+')
        if ($w.Count -ge 2 -or $w[0].ToLowerInvariant() -eq 'list') {
            Write-ArResult $Io (Invoke-ArLine 'converter' $t $null)
            return $true
        }
        return $false
    }.GetNewClosure()

    $stage = 0
    $cat = $null; $from = $null; $to = $null
    while ($true) {
        if ($stage -eq 0) {
            $opts = @($global:ArCategories | ForEach-Object { @{ Label = $_.name; Names = @($_.name); Cat = $_ } })
            $r = Invoke-ArPick $Io 'Unit Converter — choose a category' $opts $true $true $handler
            if ($r.Type -eq 'back') { return 'back' }
            if ($r.Type -ne 'choice') { return $r.Type }
            $cat = $r.Option.Cat
            $stage = 1
        }
        elseif ($stage -ge 1 -and $stage -le 2) {
            $unitOpts = @($cat.units | ForEach-Object {
                @{ Label = "$($_.s) — $($_.n)"; Names = @($_.s, $_.n.ToLowerInvariant()); Sym = $_.s }
            })
            $catTitle = $cat.name.Substring(0, 1).ToUpperInvariant() + $cat.name.Substring(1)
            if ($stage -eq 1) { $title = "$catTitle — convert from" }
            else { $title = "$catTitle — convert from $from to" }
            $r = Invoke-ArPick $Io $title $unitOpts $true $true $handler
            if ($r.Type -eq 'back') { $stage = $stage - 1; continue }
            if ($r.Type -ne 'choice') { return $r.Type }
            if ($stage -eq 1) { $from = $r.Option.Sym } else { $to = $r.Option.Sym }
            $stage = $stage + 1
        }
        else {
            $f = $from; $t2 = $to
            $run = {
                param($l)
                $s = $l.Trim()
                if (Test-ArNumberText $s) {                       # guided form: just a value
                    Invoke-ArSafe {
                        $out = Invoke-ArConvertCommand $s $f $t2
                        "$s $f = $out $t2"
                    }
                }
                else { Invoke-ArLine 'converter' $s $null }      # one-line forms still work
            }.GetNewClosure()
            $help = @(
                'Type a value to convert, e.g. 100.',
                'One-line forms also work: 100 cm in   convert 100 cm in   1 km all   list   list length',
                'Commands: help (or ?), back (previous screen), quit'
            )
            $end = Invoke-ArToolLoop $Io "converter ($f → $t2)> " @() $help $run
            if ($end -eq 'back') { $stage = 2; continue }
            return $end
        }
    }
}

# Main menu. Sessions live for the whole program run. Returns when the user exits.
function Start-ArMenu {
    param($Io)
    $std  = New-ArSession 'standard'
    $prog = New-ArSession 'programmer'
    $opts = @(
        @{ Label = 'Standard Calculator';   Value = 'standard';   Names = @('standard', 'std') },
        @{ Label = 'Programmer Calculator'; Value = 'programmer'; Names = @('programmer', 'prog') },
        @{ Label = 'Unit Converter';        Value = 'converter';  Names = @('converter', 'convert') },
        @{ Label = 'Exit';                  Value = 'exit';       Names = @('exit'); Num = 0 }
    )
    while ($true) {
        $r = Invoke-ArPick $Io 'Arithmos 1.0 — Core CLI' $opts $false $true $null
        if ($r.Type -ne 'choice') { return }                       # quit or end of input
        $v = $r.Option.Value
        if ($v -eq 'exit') { return }
        if ($v -eq 'standard')        { $end = Invoke-ArStandardTool $Io $std }
        elseif ($v -eq 'programmer')  { $end = Invoke-ArProgrammerTool $Io $prog }
        else                          { $end = Invoke-ArConverterTool $Io }
        if ($end -ne 'back') { return }                            # quit or end of input
    }
}