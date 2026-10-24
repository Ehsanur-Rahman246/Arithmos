# Runs the shared cases (docs/release-1-cases.json) plus PowerShell extras.
#   pwsh test/run_cases.ps1 [path/to/cases.json]
param([string]$CasesPath = (Join-Path $PSScriptRoot '../../docs/release-1-cases.json'))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'harness.ps1')
. (Join-Path $PSScriptRoot '../src/autoload.ps1')

# ---------- shared cases ----------

function Assert-Step {
    param($Res, $Step, [string]$Id)
    $names = @($Step.PSObject.Properties.Name)
    if ($names -contains 'error') {
        if ($Res.Code -cne [string]$Step.error) {
            throw "$Id expected $($Step.error) but got '$($Res.Code)' [$($Res.Lines -join ' | ')]"
        }
        return
    }
    if ($Res.Code) { throw "$Id unexpected Error [$($Res.Code)]: $($Res.Message)" }
    $lines = @($Res.Lines)
    if ($names -contains 'expectedContains') {
        foreach ($want in @($Step.expectedContains)) {
            if ($lines -cnotcontains [string]$want) { throw "$Id missing line '$want' in [$($lines -join ' | ')]" }
        }
    }
    elseif ($Step.expected -is [string]) {
        if ($lines.Count -lt 1 -or $lines[0] -cne $Step.expected) {
            throw "$Id expected '$($Step.expected)' but got [$($lines -join ' | ')]"
        }
    }
    else {
        foreach ($p in $Step.expected.PSObject.Properties) {
            $want = "$($p.Name): $($p.Value)"
            if ($lines -cnotcontains $want) { throw "$Id missing '$want' in [$($lines -join ' | ')]" }
        }
    }
}

$cases = Get-Content -Raw -Encoding utf8 $CasesPath | ConvertFrom-Json
Check 'case-count' { Assert-Eq @($cases).Count 175 'shared cases' }

foreach ($case in $cases) {
    Check $case.id {
        $session = New-ArSession $case.tool
        $names = @($case.PSObject.Properties.Name)
        if ($names -contains 'setup') {
            foreach ($s in $case.setup) { $null = Invoke-ArLine $case.tool $s $session }
        }
        if ($names -contains 'steps') {
            foreach ($step in $case.steps) {
                Assert-Step (Invoke-ArLine $case.tool $step.input $session) $step $case.id
            }
        }
        else {
            Assert-Step (Invoke-ArLine $case.tool $case.input $session) $case $case.id
        }
    }
}

# ---------- PowerShell extras ----------

function Run1 {
    param([string]$Tool, [string]$Line, $Session = $null)
    if ($null -eq $Session) { $Session = New-ArSession $Tool }
    return Invoke-ArLine $Tool $Line $Session
}
function Expect-Out {
    param([string]$Tool, [string]$Line, [string]$Want)
    $r = Run1 $Tool $Line
    if ($r.Code) { throw "'$Line' gave Error [$($r.Code)]: $($r.Message)" }
    Assert-Eq @($r.Lines)[0] $Want "for '$Line'"
}
function Expect-Line {
    param([string]$Tool, [string]$Line, [string]$Want)
    $r = Run1 $Tool $Line
    if ($r.Code) { throw "'$Line' gave Error [$($r.Code)]: $($r.Message)" }
    Assert-True (@($r.Lines) -ccontains $Want) "'$Line' lacks '$Want' in [$(@($r.Lines) -join ' | ')]"
}
function Expect-Code {
    param([string]$Tool, [string]$Line, [string]$Code)
    $r = Run1 $Tool $Line
    Assert-Eq $r.Code $Code "for '$Line'"
}

Check 'X-format-boundaries' {
    Assert-Eq (Format-ArNumber ([double]100000000000.5)) '100000000001'      # R10: half away from zero
    Assert-Eq (Format-ArNumber ([double]999999999999.5)) '1000000000000'
    Assert-Eq (Format-ArNumber ([double]999999999999999)) '1e+15'
    Assert-Eq (Format-ArNumber ([double]0.000001)) '0.000001'
    Assert-Eq (Format-ArNumber ([double]0.0000001)) '1e-7'
    Assert-Eq (Format-ArNumber ([double]-0.0)) '0'
    Assert-Eq (Format-ArNumber ([double]1.5e20)) '1.5e+20'
    Assert-Eq (Format-ArNumber ([double]-2.5)) '-2.5'
}
Check 'X-amendments-standard' {
    Expect-Out 'standard' '200 + (10%)' '200.1'          # R1
    Expect-Out 'standard' '200 + 5 * 10%' '200.5'        # R2
    Expect-Out 'standard' '2^50%' '1.41421356237'        # R3
    Expect-Out 'standard' '50%%' '0.005'                 # R4
    Expect-Out 'standard' '5 of 10' '50'                 # R5
    Expect-Out 'standard' 'ANS + 1' '1'                  # R6
    Expect-Code 'standard' '1e5' 'INVALID_EXPRESSION'    # R7
    Expect-Code 'standard' '.' 'INVALID_EXPRESSION'      # R8
    Expect-Code 'standard' '5.5.5' 'INVALID_EXPRESSION'
    Expect-Out 'standard' '10^-400' '0'                  # R9
    Expect-Code 'standard' '(-8)^(1/3)' 'DOMAIN_ERROR'
    Expect-Out 'standard' '.5 + 5.' '5.5'
}
Check 'X-amendments-programmer' {
    Expect-Line 'programmer' 'NOT 0xFF' 'DEC: -256'                  # R12
    Expect-Line 'programmer' 'NOT -1' 'DEC: 0'
    Expect-Code 'programmer' '1 << 0x3' 'INVALID_SHIFT'              # R13
    Expect-Code 'programmer' '1 << 2.5' 'INVALID_SHIFT'
    Expect-Line 'programmer' '-0x80' 'DEC: -128'                     # R14
    Expect-Out  'programmer' 'convert FFFFFFFFFFFFFFFF hex dec' '-1' # R15
    Expect-Line 'programmer' '1<<3' 'DEC: 8'                         # R29
    Expect-Code 'programmer' '0x' 'INVALID_DIGIT'                    # R30 (dec mode)
    $s = New-ArSession 'programmer'
    $null = Invoke-ArLine 'programmer' 'base hex' $s
    $r = Invoke-ArLine 'programmer' '0B' $s                          # R30: number 11 in hex mode
    Assert-True (@($r.Lines) -ccontains 'DEC: 11') '0B in hex mode'
    $r = Invoke-ArLine 'programmer' 'A AND F' $s                     # R11
    Assert-True (@($r.Lines) -ccontains 'HEX: A') 'A AND F'
    $r = Invoke-ArLine 'programmer' 'DEC' $s
    Assert-True (@($r.Lines) -ccontains 'DEC: 3564') 'DEC as a hex number'
}
Check 'X-base-output' {
    $s = New-ArSession 'programmer'
    $r = Invoke-ArLine 'programmer' 'BASE HEX' $s                    # R32: lower-case canonical name
    Assert-Eq @($r.Lines)[0] 'Input base: hex'
    Expect-Code 'programmer' 'base' 'INVALID_BASE'
}
Check 'X-amendments-converter' {
    Expect-Code 'converter' 'convert 1e3 m cm' 'INVALID_NUMBER'      # R16
    Expect-Code 'converter' ('convert 1' + ('0' * 400) + ' m cm') 'OVERFLOW'      # R17 input
    Expect-Code 'converter' ('convert 1' + ('0' * 300) + ' km pm') 'OVERFLOW'     # R17 result
    Expect-Code 'converter' 'list foo' 'UNKNOWN_COMMAND'             # R19
    Expect-Line 'converter' '0 k all' 'c: -273.15'                   # R20
    Expect-Line 'converter' '-273.15 c all' 'k: 0'
    Expect-Line 'converter' '-459.67 f all' 'k: 0'
    Expect-Code 'converter' '-0.001 k all' 'BELOW_ABSOLUTE_ZERO'
    Expect-Out  'converter' '100 cm in' '39.3700787402'
    Expect-Out  'converter' 'list length' 'pm, ang, nm, um, mm, cm, m, km, in, ft, yd, mi, nmi, au, ly'
}
Check 'X-unit-table-sanity' {
    $seen = @{}
    $count = 0
    foreach ($cat in $global:ArCategories) {
        foreach ($u in $cat.units) {
            Assert-True (-not $seen.ContainsKey($u.s)) "duplicate symbol $($u.s)"
            $seen[$u.s] = $true
            $count++
        }
    }
    Assert-Eq $global:ArCategories.Count 12
    Assert-True ($count -gt 100) 'unit count'
}
Check 'X-garbage-never-crashes' {
    $junk = @('', '   ', '!!!', '((((', '))))', '2 +* 3', "`t", 'sqrt', 'sqrt(', '1..2', '%', 'of', 'ans ans',
              '"', '\', '日本語', ('9' * 400), '-', '--5', '<<', '1 <<', '>> 1', 'AND', '0x', 'base', 'convert',
              'convert 1 2 3', 'list a b', '1 2 3', '1 m', 'FFFFFFFFFFFFFFFFFFFFFF', '$(whoami)', '`')
    foreach ($tool in @('standard', 'programmer', 'converter')) {
        foreach ($j in $junk) {
            $r = Run1 $tool $j
            Assert-True ($r.Code -ne 'INTERNAL') "[$tool] '$j' -> INTERNAL: $($r.Message)"
        }
    }
}

# Scripted whole sessions through the numbered-list screens (no Select).
Check 'X-session-menu' {
    $io = New-FakeIo -Lines @('1', '2 + 3', '10 / 0', 'help', 'back', '2', 'convert 255 dec hex', 'quit')
    $null = Start-ArMenu $io
    $out = $io.Out.ToString()
    Assert-True ($out -match '(?m)^5\r?$') 'standard result'
    Assert-True ($out.Contains('Error [DIV_BY_ZERO]')) 'error line'
    Assert-True ($out -match '(?m)^FF\r?$') 'programmer result'
    Assert-True ($out.Contains('  1) Standard Calculator')) 'plain list rows'
    Assert-True ($out.Contains('  0) Exit')) 'exit row'
}
Check 'X-session-converter' {
    $io = New-FakeIo -Lines @('3', 'length', 'm', 'yd', '100', '0 c f', 'list pressure', 'back', 'back', 'back', 'quit')
    $null = Start-ArMenu $io
    $out = $io.Out.ToString()
    Assert-True ($out.Contains('Unit Converter — choose a category')) 'category screen'
    Assert-True ($out.Contains('Length — convert from')) 'from screen'
    Assert-True ($out.Contains('converter (m → yd)>')) 'values prompt shows the units'
    Assert-True ($out.Contains('100 m = 109.361329834 yd')) 'guided result'
    Assert-True ($out -match '(?m)^32\r?$') 'one-line form at the values prompt'
}
Check 'X-session-eof' {
    $io = New-FakeIo -Lines @('1', '1 + 1')          # input ends inside the tool: clean exit
    $null = Start-ArMenu $io
    Assert-True ($io.Out.ToString().Contains("2`n")) 'result before EOF'
}

# One-shot mode in a real child process: results, stderr, exit status.
Check 'X-one-shot-exit-codes' {
    $pw = (Get-Process -Id $PID).Path
    $entry = Join-Path $PSScriptRoot '../bin/arithmos.ps1'
    $o = & $pw -NoProfile -File $entry std '1 + 1' 2>&1
    Assert-Eq $LASTEXITCODE 0 'success'
    Assert-Eq (@($o)[0]) '2'
    $o = & $pw -NoProfile -File $entry std '10 / 0' 2>&1
    Assert-Eq $LASTEXITCODE 1 'Error [CODE]'
    Assert-True ("$o".Contains('DIV_BY_ZERO')) 'error text'
    $null = & $pw -NoProfile -File $entry bogus 2>&1
    Assert-Eq $LASTEXITCODE 2 'bad usage'
    $o = & $pw -NoProfile -File $entry prog '-8 >>> 1' 2>&1
    Assert-True (@($o) -ccontains 'DEC: 9223372036854775804') 'prog one-shot'
}

Write-ArTestSummary 'run_cases'