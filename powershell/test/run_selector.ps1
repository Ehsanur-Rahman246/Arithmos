# Selector tests SL1-SL21 (docs/test-cases.md) plus X2 and X3.
#   pwsh test/run_selector.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'harness.ps1')
. (Join-Path $PSScriptRoot '../src/autoload.ps1')

$esc = $global:ArEsc
function Press { param($St, [string]$Kind, [string]$Char = ''); return Step-ArSelector $St (KeyOf $Kind $Char) }
function Strip { param([string]$S); return ($S -replace "\x1b\[[0-9;?]*[A-Za-z]", '') }
$two = @(@{ Label = 'Alpha' }, @{ Label = 'Beta' })          # options for the pick() tests

Check 'SL1' {      # up/down move, wrap around, home/end
    $st = New-ArSelectorState @('a', 'b', 'c') @{}
    $null = Press $st 'down'; Assert-Eq $st.Index 1
    $null = Press $st 'down'; $null = Press $st 'down'; Assert-Eq $st.Index 0 'wrap down'
    $null = Press $st 'up';   Assert-Eq $st.Index 2 'wrap up'
    $null = Press $st 'home'; Assert-Eq $st.Index 0
    $null = Press $st 'end';  Assert-Eq $st.Index 2
}
Check 'SL2' {      # long lists scroll in a window of 10
    $items = 1..15 | ForEach-Object { "item$_" }
    $st = New-ArSelectorState $items @{}
    Assert-Eq @(Get-ArSelectorFrame $st 'T' 80 $false).Count 12 'title + 10 rows + hint'
    $null = Press $st 'end'
    Assert-Eq $st.Top 5
    $f = @(Get-ArSelectorFrame $st 'T' 80 $false)
    Assert-True ($f -ccontains '❯ item15') 'last item shown'
    Assert-True ($f -cnotcontains '  item1') 'first item scrolled away'
}
Check 'SL3' {      # Enter selects; Esc / b / q only work when offered
    $st = New-ArSelectorState @('a', 'b') @{}
    $null = Press $st 'down'
    $r = Press $st 'enter'; Assert-Eq $r.Type 'select'; Assert-Eq $r.Index 1
    Assert-True ($null -eq (Press $st 'esc')) 'esc not offered'
    Assert-True ($null -eq (Press $st 'char' 'b')) 'b not offered'
    Assert-True ($null -eq (Press $st 'char' 'q')) 'q not offered'
    $st2 = New-ArSelectorState @('a', 'b') @{ Back = $true; Quit = $true }
    Assert-Eq (Press $st2 'esc').Type 'back'
    Assert-Eq (Press $st2 'char' 'b').Type 'back'
    Assert-Eq (Press $st2 'char' 'q').Type 'quit'
}
Check 'SL4' {      # Ctrl-C / Ctrl-D abort; other control keys are ignored
    $st = New-ArSelectorState @('a', 'b') @{}
    Assert-Eq (Press $st 'ctrlc').Type 'abort'
    Assert-Eq (Press $st 'ctrld').Type 'abort'
    Assert-True ($null -eq (Press $st 'other')) 'other ignored'
}
Check 'SL5' {      # typing on: a printable key ends the selector and carries the character
    $st = New-ArSelectorState @('a', 'b') @{ Typing = $true }
    $r = Press $st 'char' 'x'
    Assert-Eq $r.Type 'typed'; Assert-Eq $r.Char 'x'
}
Check 'SL6' {      # typing off: printable keys are ignored
    $st = New-ArSelectorState @('a', 'b') @{}
    Assert-True ($null -eq (Press $st 'char' 'x')) 'ignored'
}
Check 'SL7' {      # typing on: Esc, b, q, arrows and Enter keep their meaning
    $st = New-ArSelectorState @('a', 'b') @{ Typing = $true; Back = $true; Quit = $true }
    Assert-Eq (Press $st 'esc').Type 'back'
    Assert-Eq (Press $st 'char' 'b').Type 'back'
    Assert-Eq (Press $st 'char' 'q').Type 'quit'
    $null = Press $st 'down'; Assert-Eq $st.Index 1
    Assert-Eq (Press $st 'enter').Type 'select'
}
Check 'SL8' {      # typing on: space and control keys do not start a typed line
    $st = New-ArSelectorState @('a', 'b') @{ Typing = $true }
    Assert-True ($null -eq (Press $st 'char' ' ')) 'space'
    Assert-True ($null -eq (Press $st 'char' ([string][char]7))) 'control char'
    Assert-True ($null -eq (Press $st 'other')) 'other'
}
Check 'SL9' {      # the selected row is highlighted as a full bar
    $st = New-ArSelectorState @('alpha', 'beta') @{}
    $row = @(Get-ArSelectorFrame $st 'T' 80 $true)[1]
    Assert-True ($row.Contains("${esc}[7m")) 'reverse video'
    Assert-Eq (Strip $row).Length 79 'bar is width - 1 columns'
}
Check 'SL10' {     # plain mode still marks the selected row with the pointer
    $st = New-ArSelectorState @('alpha', 'beta') @{}
    $f = @(Get-ArSelectorFrame $st 'T' 80 $false)
    Assert-True $f[1].StartsWith('❯ ') 'pointer'
    Assert-True $f[2].StartsWith('  ') 'no pointer'
    Assert-True (-not $f[1].Contains($esc)) 'no escape codes'
}
Check 'SL11' {     # hint line lists only the keys on offer
    $st = New-ArSelectorState @('a', 'b') @{}
    $hint = @(Get-ArSelectorFrame $st 'T' 80 $false)[-1]
    Assert-True $hint.Contains('Enter select')
    Assert-True (-not $hint.Contains('Esc')) 'no Esc'
    Assert-True (-not $hint.Contains('quit')) 'no quit'
    Assert-True (-not $hint.Contains('type')) 'no type'
}
Check 'SL12' {     # hint shows Esc/b back and "or type" when typing is on
    $st = New-ArSelectorState @('a', 'b') @{ Back = $true; Quit = $true; Typing = $true }
    $hint = @(Get-ArSelectorFrame $st 'T' 80 $false)[-1]
    Assert-True $hint.Contains('Esc/b back')
    Assert-True $hint.Contains('q quit')
    Assert-True $hint.Contains('or type')
}
Check 'SL13' {     # loop: keys in, index out, summary left behind, cursor restored
    $scr = New-FakeScreen
    $kb = New-FakeKb @((KeyOf 'down'), (KeyOf 'enter'))
    $r = Invoke-ArSelectLoop 'Pick' @('a', 'b', 'c') @{ Back = $true } $kb $scr
    Assert-Eq $r.Type 'select'; Assert-Eq $r.Index 1
    $out = $scr.Out.ToString()
    Assert-True $out.StartsWith("${esc}[?25l") 'cursor hidden first'
    Assert-True $out.Contains('✔ Pick: b') 'summary'
    Assert-True $out.EndsWith("${esc}[?25h") 'cursor restored last'
}
Check 'SL14' {     # loop: Esc, ignored keys, Ctrl-C
    $scr = New-FakeScreen
    $kb = New-FakeKb @((KeyOf 'other'), (KeyOf 'esc'))
    Assert-Eq (Invoke-ArSelectLoop 'T' @('a', 'b') @{ Back = $true } $kb $scr).Type 'back'
    $scr = New-FakeScreen
    $kb = New-FakeKb @((KeyOf 'ctrlc'))
    Assert-Eq (Invoke-ArSelectLoop 'T' @('a', 'b') @{} $kb $scr).Type 'abort'
    Assert-True $scr.Out.ToString().EndsWith("${esc}[?25h") 'cursor restored after Ctrl-C'
}
Check 'SL15' {     # loop: a typed key returns its character and restores the cursor
    $scr = New-FakeScreen
    $kb = New-FakeKb @((KeyOf 'char' 'x'))
    $r = Invoke-ArSelectLoop 'T' @('a', 'b') @{ Typing = $true } $kb $scr
    Assert-Eq $r.Type 'typed'; Assert-Eq $r.Char 'x'
    Assert-True $scr.Out.ToString().EndsWith("${esc}[?25h") 'cursor restored'
}
Check 'SL16' {     # pick() uses the selector when present and maps its results
    $calls = @{ N = 0 }
    $io = New-FakeIo -Select (New-FakeSelect @(@{ Type = 'select'; Index = 1 }) $calls)
    $r = Invoke-ArPick $io 'T' $two $true $true $null
    Assert-Eq $r.Type 'choice'; Assert-Eq $r.Index 1; Assert-Eq $r.Option.Label 'Beta'
    Assert-True $calls.Opts.Typing 'typing is on'
    foreach ($pair in @(@('back', 'back'), @('quit', 'quit'), @('abort', 'eof'))) {
        $io = New-FakeIo -Select (New-FakeSelect @(@{ Type = $pair[0] }) @{ N = 0 })
        Assert-Eq (Invoke-ArPick $io 'T' $two $true $true $null).Type $pair[1]
    }
}
Check 'SL17' {     # pick(): a typed name or number selects it
    $io = New-FakeIo -Lines @('lpha') -Select (New-FakeSelect @(@{ Type = 'typed'; Char = 'a' }) @{ N = 0 })
    Assert-Eq (Invoke-ArPick $io 'T' $two $true $true $null).Index 0 'name'
    $io = New-FakeIo -Lines @('') -Select (New-FakeSelect @(@{ Type = 'typed'; Char = '2' }) @{ N = 0 })
    Assert-Eq (Invoke-ArPick $io 'T' $two $true $true $null).Index 1 'number'
}
Check 'SL18' {     # pick(): a typed one-line command runs and the list comes back
    $seen = @{ Text = $null }
    $h = { param($t) $seen.Text = $t; return $true }.GetNewClosure()
    $calls = @{ N = 0 }
    $sel = New-FakeSelect @(@{ Type = 'typed'; Char = 'l' }, @{ Type = 'select'; Index = 0 }) $calls
    $io = New-FakeIo -Lines @('ist') -Select $sel
    $r = Invoke-ArPick $io 'T' $two $true $true $h
    Assert-Eq $seen.Text 'list'; Assert-Eq $r.Index 0; Assert-Eq $calls.N 2 'list came back'
}
Check 'SL19' {     # pick(): an unknown typed word is an error and the list comes back
    $h = { param($t) return $false }
    $calls = @{ N = 0 }
    $sel = New-FakeSelect @(@{ Type = 'typed'; Char = 'x' }, @{ Type = 'select'; Index = 0 }) $calls
    $io = New-FakeIo -Lines @('yz') -Select $sel
    $r = Invoke-ArPick $io 'T' $two $true $true $h
    Assert-True $io.Out.ToString().Contains('Error [UNKNOWN_COMMAND]') 'error shown'
    Assert-Eq $r.Type 'choice'; Assert-Eq $calls.N 2
}
Check 'SL20' {     # pick(): b, q and Esc act at once, with no prompt line
    $io = New-FakeIo -Select (New-FakeSelect @(@{ Type = 'back' }) @{ N = 0 })
    Assert-Eq (Invoke-ArPick $io 'T' $two $true $true $null).Type 'back'
    Assert-Eq $io.State.Reads 0 'ReadLine never called'
    Assert-True (-not $io.Out.ToString().Contains('> ')) 'no prompt'
    $io = New-FakeIo -Select (New-FakeSelect @(@{ Type = 'quit' }) @{ N = 0 })
    Assert-Eq (Invoke-ArPick $io 'T' $two $true $true $null).Type 'quit'
    Assert-Eq $io.State.Reads 0
}
Check 'SL21' {     # pick(): without a selector (pipes) the numbered list works as before
    $io = New-FakeIo -Lines @('2')
    $r = Invoke-ArPick $io 'T' $two $true $true $null
    Assert-Eq $r.Index 1
    Assert-True $io.Out.ToString().Contains('  1) Alpha') 'row format'
    Assert-Eq (Invoke-ArPick (New-FakeIo -Lines @('', 'beta')) 'T' $two $true $true $null).Index 1 'blank ignored, name'
    Assert-Eq (Invoke-ArPick (New-FakeIo -Lines @('quit')) 'T' $two $true $true $null).Type 'quit'
    Assert-Eq (Invoke-ArPick (New-FakeIo -Lines @('back')) 'T' $two $true $true $null).Type 'back'
    Assert-Eq (Invoke-ArPick (New-FakeIo -Lines @()) 'T' $two $true $true $null).Type 'eof'
}
Check 'X2' {       # lines never wider than the terminal; window shrinks; erase moves up by the line count
    $long = 'x' * 50
    $st = New-ArSelectorState @($long, 'b') @{}
    $f = @(Get-ArSelectorFrame $st 'T' 30 $false)
    foreach ($l in $f) { Assert-True ($l.Length -le 29) "line too wide: $l" }
    Assert-True $f[1].EndsWith('…') 'long line ends with an ellipsis'
    $items = 1..12 | ForEach-Object { "item$_" }
    $st = New-ArSelectorState $items @{}
    Set-ArWindow $st 8
    Assert-Eq $st.Window 5 'window shrinks on a short terminal'
    Assert-Eq @(Get-ArSelectorFrame $st 'T' 80 $false).Count 7 'block fits the height'
    $scr = New-FakeScreen -W 80 -H 8
    $kb = New-FakeKb @((KeyOf 'down'), (KeyOf 'enter'))
    $null = Invoke-ArSelectLoop 'T' $items @{} $kb $scr
    Assert-True $scr.Out.ToString().Contains("${esc}[7A") 'erase moves up by 7'
}
Check 'X3' {       # ConsoleKeyInfo becomes keys (PowerShell's counterpart of byte parsing)
    function CK { param([char]$C, $K, [bool]$Ctrl = $false) return [System.ConsoleKeyInfo]::new($C, $K, $false, $false, $Ctrl) }
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]0) ([ConsoleKey]::UpArrow))).Kind 'up'
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]0) ([ConsoleKey]::DownArrow))).Kind 'down'
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]0) ([ConsoleKey]::Home))).Kind 'home'
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]0) ([ConsoleKey]::End))).Kind 'end'
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]0) ([ConsoleKey]::PageUp))).Kind 'pgup'
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]0) ([ConsoleKey]::PageDown))).Kind 'pgdn'
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]13) ([ConsoleKey]::Enter))).Kind 'enter'
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]27) ([ConsoleKey]::Escape))).Kind 'esc'
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]3) ([ConsoleKey]::C) $true)).Kind 'ctrlc'
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]4) ([ConsoleKey]::D) $true)).Kind 'ctrld'
    $k = ConvertFrom-ArConsoleKey (CK ([char]'x') ([ConsoleKey]::X))
    Assert-Eq $k.Kind 'char'; Assert-Eq $k.Char 'x'
    $k = ConvertFrom-ArConsoleKey (CK ([char]'é') ([ConsoleKey]::E))
    Assert-Eq $k.Char 'é' 'non-ASCII character'
    Assert-Eq (ConvertFrom-ArConsoleKey (CK ([char]0) ([ConsoleKey]::F5))).Kind 'other'
}

Write-ArTestSummary 'run_selector'