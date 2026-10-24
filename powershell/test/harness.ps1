# Tiny test harness shared by run_cases.ps1 and run_selector.ps1 (no Pester needed).

$global:ArTest = @{ Pass = 0; Fail = 0 }

function Check {
    param([string]$Name, [scriptblock]$Body)
    try { & $Body; $global:ArTest.Pass++ }
    catch {
        $global:ArTest.Fail++
        Write-Host "FAIL $Name : $($_.Exception.Message)"
    }
}

function Assert-True {
    param($Cond, [string]$Msg = 'assertion failed')
    if (-not $Cond) { throw $Msg }
}

function Assert-Eq {
    param($Actual, $Expected, [string]$Msg = '')
    if ([string]$Actual -cne [string]$Expected) { throw "expected '$Expected' but got '$Actual' $Msg" }
}

function Write-ArTestSummary {
    param([string]$Label)
    $p = $global:ArTest.Pass; $f = $global:ArTest.Fail
    Write-Host "$Label : $p passed, $f failed"
    if ($f -gt 0) { exit 1 }
    exit 0
}

# ---- Fakes for the selector and pick() tests ----

function KeyOf {
    param([string]$Kind, [string]$Char = '')
    return New-ArKey $Kind $Char
}

function New-FakeKb {
    param([object[]]$Keys)
    $q = [System.Collections.Generic.Queue[object]]::new()
    foreach ($k in $Keys) { $q.Enqueue($k) }
    return { if ($q.Count -eq 0) { return $null }; return $q.Dequeue() }.GetNewClosure()
}

function New-FakeScreen {
    param([int]$W = 80, [int]$H = 24, [bool]$Color = $false)
    $sb = [System.Text.StringBuilder]::new()
    $size = @{ W = $W; H = $H }
    return @{
        Out   = $sb
        Color = $Color
        Write = { param([string]$t) [void]$sb.Append($t) }.GetNewClosure()
        Size  = { return $size }.GetNewClosure()
    }
}

# A fake io: ReadLine pops queued lines (null when empty), Write is captured in .Out.
function New-FakeIo {
    param([string[]]$Lines = @(), $Select = $null)
    $sb = [System.Text.StringBuilder]::new()
    $q = [System.Collections.Generic.Queue[string]]::new()
    foreach ($l in $Lines) { $q.Enqueue($l) }
    $state = @{ Reads = 0 }
    $io = @{ Out = $sb; State = $state; Color = $false; Select = $Select }
    $io.Write = { param([string]$t) [void]$sb.Append($t) }.GetNewClosure()
        $io.ReadLine = {
        param([string]$p)
        [void]$sb.Append($p)
        $state.Reads++
        if ($q.Count -eq 0) { return $null }
        $line = $q.Dequeue()
        [void]$sb.Append($line + "`n")      # a real terminal echoes the line and the Enter key
        return $line
    }.GetNewClosure()
    return $io
}

# A fake selector: returns queued results, records the call count and the options it got.
function New-FakeSelect {
    param([object[]]$Results, [hashtable]$Calls)
    $q = [System.Collections.Generic.Queue[object]]::new()
    foreach ($r in $Results) { $q.Enqueue($r) }
    return {
        param($t, $items, $o)
        $Calls.N++
        $Calls.Opts = $o
        if ($q.Count -eq 0) { return @{ Type = 'abort' } }
        return $q.Dequeue()
    }.GetNewClosure()
}