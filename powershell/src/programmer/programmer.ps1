# Programmer Calculator engine (spec §4). Every value is a signed 64-bit integer.
# PowerShell's [long] is a native 64-bit two's-complement type: -band -bor -bxor -bnot
# -shl and the arithmetic -shr act on the 64-bit pattern, so nothing is emulated.
# Literals are parsed with BigInteger so range checks are exact and nothing silently
# passes through [double].

$global:ArBases  = @{ bin = 2; oct = 8; dec = 10; hex = 16 }
$global:ArPrefix = @{ b = 'bin'; o = 'oct'; d = 'dec'; x = 'hex' }
$global:ArTwo63  = [System.Numerics.BigInteger]::Pow(2, 63)
$global:ArTwo64  = [System.Numerics.BigInteger]::Pow(2, 64)
$global:ArMaxLng = [System.Numerics.BigInteger]::Parse('9223372036854775807')

function Get-ArDigitValue {
    param([char]$C)
    $code = [int]$C
    if ($code -ge 48 -and $code -le 57)  { return $code - 48 }     # 0-9
    if ($code -ge 65 -and $code -le 90)  { return $code - 55 }     # A-Z
    if ($code -ge 97 -and $code -le 122) { return $code - 87 }     # a-z
    return 99
}

function Test-ArBaseName {
    param([string]$Name)
    return $global:ArBases.ContainsKey($Name.ToLowerInvariant())
}

# Parse one literal into a [long]. Order (ARCHITECTURE.md): prefix -> digits -> range.
function Convert-ArLiteral {
    param([string]$Text, [string]$BaseName)
    $orig = $Text.Trim()
    $s    = $orig
    $neg  = $false
    if ($s.StartsWith('-')) { $neg = $true; $s = $s.Substring(1) }

    $base = $BaseName
    # A prefix counts only when digits follow it (R30): "0B" in hex mode is the number 11.
    if ($s.Length -gt 2 -and $s -match '^0[bBoOdDxX]') {
        $base = $global:ArPrefix[$s.Substring(1, 1).ToLowerInvariant()]
        $s = $s.Substring(2)
    }
    if ($s.Length -eq 0 -or $s -notmatch '^[0-9A-Za-z]+$') {
        Throw-Ar 'INVALID_NUMBER' "'$orig' is not a number"
    }

    $radix = $global:ArBases[$base]
    $acc = [System.Numerics.BigInteger]::Zero
    foreach ($ch in $s.ToCharArray()) {
        $d = Get-ArDigitValue $ch
        if ($d -ge $radix) {
            Throw-Ar 'INVALID_DIGIT' "'$($ch.ToString().ToUpperInvariant())' is not a $base digit"
        }
        $acc = $acc * $radix + $d
    }

    if ($neg) {                                          # magnitude may not exceed 2^63
        if ($acc -gt $global:ArTwo63) { Throw-Ar 'OUT_OF_RANGE' 'That number does not fit in 64 bits' }
        $val = -$acc
    }
    elseif ($base -eq 'dec') {                           # decimal must fit the signed range
        if ($acc -gt $global:ArMaxLng) { Throw-Ar 'OUT_OF_RANGE' 'That number does not fit in 64 bits' }
        $val = $acc
    }
    else {                                               # bin/oct/hex: raw bit pattern, reinterpreted
        if ($acc -ge $global:ArTwo64) { Throw-Ar 'OUT_OF_RANGE' 'That number needs more than 64 bits' }
        if ($acc -ge $global:ArTwo63) { $val = $acc - $global:ArTwo64 } else { $val = $acc }
    }
    return [long]$val
}

# Show a value in one base. For negatives, hex/oct/bin give the full 64-bit pattern
# (Convert.ToString(long, 2|8|16) does exactly that); dec gives the signed value.
function Format-ArBase {
    param([long]$V, [string]$BaseName)
    return [Convert]::ToString($V, [int]$global:ArBases[$BaseName]).ToUpperInvariant()
}

function Get-ArShiftCount {
    param([string]$Text)
    $t = $Text.Trim()
    $msg = 'A shift count must be a whole number from 0 to 63'
    if ($t -notmatch '^[0-9]+$') { Throw-Ar 'INVALID_SHIFT' $msg }       # -1, 2.5, 0x3
    $big = [System.Numerics.BigInteger]::Parse($t)
    if ($big -gt 63) { Throw-Ar 'INVALID_SHIFT' $msg }
    return [int]$big
}

function Resolve-ArBaseName {
    param([string]$Name)
    $low = $Name.ToLowerInvariant()
    if (-not $global:ArBases.ContainsKey($low)) {
        Throw-Ar 'INVALID_BASE' "'$Name' is not a base. Use bin, oct, dec or hex"
    }
    return $low
}

function Convert-ArBases {
    param([string]$Value, [string]$From, [string]$To)
    $f = Resolve-ArBaseName $From
    $t = Resolve-ArBaseName $To
    $v = Convert-ArLiteral $Value $f
    return @{ Kind = 'text'; Text = (Format-ArBase $v $t) }
}

# Public entry. $Session = @{ Base = 'dec' }.
# Returns @{ Kind = 'values'; Value = [long] } | @{ Kind = 'text'; Text } | @{ Kind = 'base'; Base }
function Invoke-ArProgrammer {
    param([string]$Line, [hashtable]$Session)
    $t = $Line.Trim()
    if ($t -eq '') { Throw-Ar 'UNKNOWN_COMMAND' 'Type a number or a command. Try help' }
    $w = @($t -split '\s+')
    $first = $w[0].ToLowerInvariant()
    $cur = [string]$Session.Base

    if ($first -eq 'base') {
        if ($w.Count -ne 2) { Throw-Ar 'INVALID_BASE' 'Use: base bin | oct | dec | hex' }
        $Session.Base = Resolve-ArBaseName $w[1]
        return @{ Kind = 'base'; Base = $Session.Base }
    }
    if ($first -eq 'convert') {
        if ($w.Count -ne 4) { Throw-Ar 'UNKNOWN_COMMAND' 'Use: convert <value> <from> <to>' }
        return Convert-ArBases $w[1] $w[2] $w[3]
    }
    # "convert" is optional: exactly three words whose last two are base names (R24).
    if ($w.Count -eq 3 -and (Test-ArBaseName $w[1]) -and (Test-ArBaseName $w[2])) {
        return Convert-ArBases $w[0] $w[1] $w[2]
    }
    # Shifts: spaces optional (R29). Operator list puts >>> before >>.
    if ($t -match '^(.+?)\s*(>>>|<<|>>)\s*(.+)$') {
        $a  = Convert-ArLiteral $Matches[1] $cur
        $op = $Matches[2]
        $n  = Get-ArShiftCount $Matches[3]
        if ($op -eq '<<') { $r = $a -shl $n }
        elseif ($op -eq '>>') { $r = $a -shr $n }                 # arithmetic: sign-extending
        elseif ($n -eq 0) { $r = $a }
        else { $r = ($a -shr $n) -band ([long]::MaxValue -shr ($n - 1)) }   # logical: clear sign bits
        return @{ Kind = 'values'; Value = [long]$r }
    }
    if ($first -eq 'not') {
        if ($w.Count -ne 2) { Throw-Ar 'UNKNOWN_COMMAND' 'Use: NOT <value>' }
        $a = Convert-ArLiteral $w[1] $cur
        return @{ Kind = 'values'; Value = [long](-bnot $a) }
    }
    # The operator is always the middle word, so FACE XOR BEEF works in hex mode (R11).
    if ($w.Count -eq 3 -and $w[1] -in @('and', 'or', 'xor')) {
        $a = Convert-ArLiteral $w[0] $cur
        $b = Convert-ArLiteral $w[2] $cur
        $o = $w[1].ToLowerInvariant()
        if ($o -eq 'and') { $r = $a -band $b }
        elseif ($o -eq 'or') { $r = $a -bor $b }
        else { $r = $a -bxor $b }
        return @{ Kind = 'values'; Value = [long]$r }
    }
    if ($w.Count -eq 1) {
        return @{ Kind = 'values'; Value = (Convert-ArLiteral $w[0] $cur) }
    }
    Throw-Ar 'UNKNOWN_COMMAND' 'Not a command. Try help'
}

# Turn an engine result into the lines the CLI prints (spec §4.4).
function Get-ArProgrammerLines {
    param([hashtable]$R)
    if ($R.Kind -eq 'values') {
        $v = [long]$R.Value
        return @(
            "HEX: $(Format-ArBase $v 'hex')",
            "DEC: $(Format-ArBase $v 'dec')",
            "OCT: $(Format-ArBase $v 'oct')",
            "BIN: $(Format-ArBase $v 'bin')"
        )
    }
    if ($R.Kind -eq 'base') { return @("Input base: $($R.Base)") }
    return @($R.Text)
}