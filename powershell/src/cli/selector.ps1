# Arrow-key selector in the same four layers as every other edition (SL1-SL21):
#   1. key handling (pure)     Step-ArSelector
#   2. drawing (pure)          Get-ArSelectorFrame
#   3. draw/read loop          Invoke-ArSelectLoop   (injectable keyboard + screen)
#   4. pick()                  in pick.ps1
# Plus the real console keyboard (ConsoleKeyInfo -> key).
#
# A key is @{ Kind = 'up'|'down'|'home'|'end'|'pgup'|'pgdn'|'enter'|'esc'|'ctrlc'|'ctrld'|'char'|'other'; Char = '' }
# A result is $null (keep going) or @{ Type = 'select'|'back'|'quit'|'abort'|'typed'; Index; Char }

function New-ArKey {
    param([string]$Kind, [string]$Char = '')
    return @{ Kind = $Kind; Char = $Char }
}

function New-ArSelectorState {
    param([string[]]$Items, [hashtable]$Opts)
    $o = @{}
    if ($Opts) { $o = $Opts }
    return @{
        Items = $Items; Index = 0; Top = 0
        Max = 10; Window = 10                         # lists longer than 10 rows scroll
        Back = [bool]$o.Back; Quit = [bool]$o.Quit; Typing = [bool]$o.Typing
    }
}

function Move-ArIndex {
    param([hashtable]$St, [int]$To)
    $n = $St.Items.Count
    $win = [math]::Min($St.Window, $n)
    $St.Index = $To
    if ($To -lt $St.Top) { $St.Top = $To }
    elseif ($To -ge $St.Top + $win) { $St.Top = $To - $win + 1 }
    $St.Top = [math]::Max(0, [math]::Min($St.Top, $n - $win))
}

# The window shrinks so the whole block (title + rows + hint) fits the terminal height (rule 6).
function Set-ArWindow {
    param([hashtable]$St, [int]$Height)
    $St.Window = [math]::Max(1, [math]::Min($St.Max, $Height - 3))
    Move-ArIndex $St $St.Index
}

function Step-ArSelector {
    param([hashtable]$St, [hashtable]$Key)
    $n = $St.Items.Count
    $win = [math]::Max(1, [math]::Min($St.Window, $n))
    $kind = $Key.Kind

    if ($kind -eq 'ctrlc' -or $kind -eq 'ctrld') { return @{ Type = 'abort' } }
    if ($kind -eq 'enter') { return @{ Type = 'select'; Index = $St.Index } }
    if ($kind -eq 'up')    { Move-ArIndex $St (($St.Index - 1 + $n) % $n); return $null }   # wraps
    if ($kind -eq 'down')  { Move-ArIndex $St (($St.Index + 1) % $n); return $null }         # wraps
    if ($kind -eq 'home')  { Move-ArIndex $St 0; return $null }
    if ($kind -eq 'end')   { Move-ArIndex $St ($n - 1); return $null }
    if ($kind -eq 'pgup')  { Move-ArIndex $St ([math]::Max(0, $St.Index - $win)); return $null }
    if ($kind -eq 'pgdn')  { Move-ArIndex $St ([math]::Min($n - 1, $St.Index + $win)); return $null }
    if ($kind -eq 'esc') {
        if ($St.Back) { return @{ Type = 'back' } }
        return $null
    }
    if ($kind -eq 'char') {
        $c = $Key.Char
        # b and q act at once, but only when offered.
        if ($c -ceq 'b' -and $St.Back) { return @{ Type = 'back' } }
        if ($c -ceq 'q' -and $St.Quit) { return @{ Type = 'quit' } }
        # Any other printable key (not space, not a control) opens a typed line.
        if ($St.Typing -and $c.Length -gt 0 -and $c -ne ' ' -and -not [char]::IsControl($c[0])) {
            return @{ Type = 'typed'; Char = $c }
        }
        return $null
    }
    return $null                                       # 'other' and unknown keys are ignored
}

function Format-ArFit {
    param([string]$Text, [int]$Max)
    if ($Text.Length -le $Max) { return $Text }
    if ($Max -le 1) { return $Text.Substring(0, [math]::Max(0, $Max)) }
    return $Text.Substring(0, $Max - 1) + '…'
}

# One logical line = one screen line: every line is at most (width - 1) columns.
# With colour, the selected row is a full reverse-video bar; the pointer is always drawn.
function Get-ArSelectorFrame {
    param([hashtable]$St, [string]$Title, [int]$Width, [bool]$Color)
    $esc = $global:ArEsc
    $max = [math]::Max(1, $Width - 1)
    $lines = [System.Collections.Generic.List[string]]::new()

    $t = Format-ArFit $Title $max
    if ($Color) { $t = "${esc}[1m${t}${esc}[0m" }
    $lines.Add($t)

    $win = [math]::Min($St.Window, $St.Items.Count)
    for ($i = $St.Top; $i -lt $St.Top + $win; $i++) {
        $selected = ($i -eq $St.Index)
        $prefix = '  '
        if ($selected) { $prefix = '❯ ' }
        $row = Format-ArFit ($prefix + $St.Items[$i]) $max
        if ($selected -and $Color) { $row = "${esc}[7m" + $row.PadRight($max) + "${esc}[0m" }
        $lines.Add($row)
    }

    # The hint lists only the keys on offer.
    $parts = @('↑↓ move', 'Enter select')
    if ($St.Back)   { $parts += 'Esc/b back' }
    if ($St.Quit)   { $parts += 'q quit' }
    if ($St.Typing) { $parts += 'or type' }
    $hint = Format-ArFit ($parts -join ' · ') $max
    if ($Color) { $hint = "${esc}[2m${hint}${esc}[0m" }
    $lines.Add($hint)
    return $lines.ToArray()
}

# Draw/read loop over an injectable keyboard and screen.
#   $ReadKey = scriptblock returning a key (or $null = end of input)
#   $Screen  = @{ Write = {param($t)}; Size = { @{W;H} }; Color = [bool] }
# A redraw moves up by the number of lines drawn; the size is measured on every redraw.
function Invoke-ArSelectLoop {
    param([string]$Title, [string[]]$Items, [hashtable]$Opts, [scriptblock]$ReadKey, [hashtable]$Screen)
    $esc = $global:ArEsc
    $write = $Screen.Write
    $st = New-ArSelectorState $Items $Opts
    $drawn = 0
    $result = $null
    & $write "${esc}[?25l"                              # hide the cursor
    try {
        while ($true) {
            $size = & $Screen.Size
            Set-ArWindow $st $size.H
            $frame = @(Get-ArSelectorFrame $st $Title $size.W ([bool]$Screen.Color))
            if ($drawn -gt 0) { & $write "${esc}[${drawn}A`r${esc}[J" }
            & $write (($frame -join "`n") + "`n")
            $drawn = $frame.Count

            $key = & $ReadKey
            if ($null -eq $key) { $result = @{ Type = 'abort' }; break }
            $result = Step-ArSelector $st $key
            if ($null -ne $result) { break }
        }
    }
    finally {
        if ($drawn -gt 0) { & $write "${esc}[${drawn}A`r${esc}[J" }          # erase the block
        if ($result -and $result.Type -eq 'select') {
            & $write ("✔ ${Title}: " + $Items[$result.Index] + "`n")          # summary left behind
        }
        & $write "${esc}[?25h"                                                # cursor back
    }
    return $result
}

# ---- Real console keyboard ----

# ConsoleKeyInfo -> key (Modifiers: Alt = 1, Shift = 2, Control = 4).
function ConvertFrom-ArConsoleKey {
    param([System.ConsoleKeyInfo]$Info)
    $ctrl = (([int]$Info.Modifiers -band 4) -ne 0)
    $code = [int]$Info.KeyChar
    if (($ctrl -and $Info.Key -eq [System.ConsoleKey]::C) -or $code -eq 3) { return New-ArKey 'ctrlc' }
    if (($ctrl -and $Info.Key -eq [System.ConsoleKey]::D) -or $code -eq 4) { return New-ArKey 'ctrld' }
    $k = $Info.Key
    if ($k -eq [System.ConsoleKey]::UpArrow)    { return New-ArKey 'up' }
    if ($k -eq [System.ConsoleKey]::DownArrow)  { return New-ArKey 'down' }
    if ($k -eq [System.ConsoleKey]::Home)       { return New-ArKey 'home' }
    if ($k -eq [System.ConsoleKey]::End)        { return New-ArKey 'end' }
    if ($k -eq [System.ConsoleKey]::PageUp)     { return New-ArKey 'pgup' }
    if ($k -eq [System.ConsoleKey]::PageDown)   { return New-ArKey 'pgdn' }
    if ($k -eq [System.ConsoleKey]::Enter)      { return New-ArKey 'enter' }
    if ($k -eq [System.ConsoleKey]::Escape)     { return New-ArKey 'esc' }
    $c = $Info.KeyChar
    if ($code -ne 0 -and -not [char]::IsControl($c)) { return New-ArKey 'char' ([string]$c) }
    return New-ArKey 'other'
}

function Read-ArConsoleKey {
    try { return ConvertFrom-ArConsoleKey ([Console]::ReadKey($true)) }
    catch { return $null }                                # input closed: treat as end of input
}

# The io.Select scriptblock. Ctrl-C is delivered as a key only while a selector is on
# screen; the setting is restored in finally, so the terminal is never left in a odd state.
function New-ArRealSelect {
    return {
        param([string]$Title, [string[]]$Items, [hashtable]$Opts)
        $screen = @{
            Write = { param([string]$T) [Console]::Out.Write($T); [Console]::Out.Flush() }
            Size  = { Get-ArConsoleSize }
            Color = (-not $env:NO_COLOR)
        }
        $keys = { Read-ArConsoleKey }
        $old = [Console]::TreatControlCAsInput
        try {
            [Console]::TreatControlCAsInput = $true
            return Invoke-ArSelectLoop $Title $Items $Opts $keys $screen
        }
        finally { [Console]::TreatControlCAsInput = $old }
    }
}