# Unit Converter engine (spec §5). Pure logic. Returns arrays of output lines.

function Test-ArNumberText {
    param([string]$T)
    return ($T -match '^-?([0-9]+\.?[0-9]*|\.[0-9]+)$')          # plain decimal only: no 1e3, no 1,000
}

function ConvertTo-ArDouble {
    param([string]$Text)
    if (-not (Test-ArNumberText $Text)) { Throw-Ar 'INVALID_NUMBER' "'$Text' is not a number" }
    $v = [double]::Parse($Text, [System.Globalization.NumberStyles]::Float,
                         [System.Globalization.CultureInfo]::InvariantCulture)
    if ([double]::IsInfinity($v)) { Throw-Ar 'OVERFLOW' 'That number is too large' }
    return $v
}

function Get-ArUnit {
    param([string]$Symbol)
    $e = $global:ArUnitIndex[$Symbol.Trim()]
    if ($null -eq $e) { Throw-Ar 'UNKNOWN_UNIT' "'$Symbol' is not a known unit. Try: list" }
    return $e
}

# Temperature goes through degrees Celsius. Only the INPUT is checked against absolute
# zero, in its own unit, so the exact limits (0 k, -273.15 c, -459.67 f) stay allowed (R20).
function Convert-ArTemperature {
    param([double]$Value, [string]$From, [string]$To)
    $f = $From.ToLowerInvariant()
    $t = $To.ToLowerInvariant()
    $min = @{ c = -273.15; f = -459.67; k = 0.0 }[$f]
    if ($Value -lt $min) { Throw-Ar 'BELOW_ABSOLUTE_ZERO' 'That is below absolute zero' }
    if ($f -eq $t) { return $Value }
    if     ($f -eq 'c') { $c = $Value }
    elseif ($f -eq 'f') { $c = ($Value - 32) * 5 / 9 }
    else                { $c = $Value - 273.15 }
    if     ($t -eq 'c') { return $c }
    elseif ($t -eq 'f') { return $c * 9 / 5 + 32 }
    return $c + 273.15
}

# value x from.factor / to.factor, in that order (ARCHITECTURE.md).
function Convert-ArUnits {
    param([double]$Value, $From, $To)
    if ($From.cat.name -ne $To.cat.name) {
        Throw-Ar 'INCOMPATIBLE_UNITS' "Cannot convert $($From.cat.name) to $($To.cat.name)"
    }
    if ($From.cat.name -eq 'temperature') {
        return Convert-ArTemperature $Value $From.u.s $To.u.s
    }
    $r = $Value * [double]$From.u.f / [double]$To.u.f
    if ([double]::IsNaN($r) -or [double]::IsInfinity($r)) {
        Throw-Ar 'OVERFLOW' 'Result is too large to represent'
    }
    return $r
}

# convert <value> <from> <to|all>  ->  lines
function Invoke-ArConvertCommand {
    param([string]$ValueText, [string]$FromSym, [string]$ToSym)
    $v    = ConvertTo-ArDouble $ValueText
    $from = Get-ArUnit $FromSym
    if ($ToSym.ToLowerInvariant() -eq 'all') {
        # Every unit of the source's category, in table order, source included (R18).
        # Any failure fails the whole command: no partial lines.
        $lines = @()
        foreach ($u in $from.cat.units) {
            $r = Convert-ArUnits $v $from $global:ArUnitIndex[$u.s]
            $lines += ('{0}: {1}' -f $u.s, (Format-ArNumber $r))
        }
        return $lines
    }
    $to = Get-ArUnit $ToSym
    return @(Format-ArNumber (Convert-ArUnits $v $from $to))
}

# One-line commands: convert ..., list, list <category>, <value> <from> <to>.
function Invoke-ArConverter {
    param([string]$Line)
    $t = $Line.Trim()
    if ($t -eq '') { Throw-Ar 'UNKNOWN_COMMAND' 'Type a value, e.g. 100' }
    $w = @($t -split '\s+')
    $first = $w[0].ToLowerInvariant()

    if ($first -eq 'list') {
        if ($w.Count -eq 1) {
            return @(($global:ArCategories | ForEach-Object { $_.name }) -join ', ')
        }
        if ($w.Count -gt 2) { Throw-Ar 'UNKNOWN_COMMAND' 'Use: list  or  list <category>' }
        $cat = $global:ArCategories | Where-Object { $_.name -eq $w[1] }
        if (-not $cat) { Throw-Ar 'UNKNOWN_COMMAND' "'$($w[1])' is not a category. Try: list" }
        return @(($cat.units | ForEach-Object { $_.s }) -join ', ')
    }
    if ($first -eq 'convert') {
        if ($w.Count -ne 4) { Throw-Ar 'UNKNOWN_COMMAND' 'Use: convert <value> <from> <to>' }
        return Invoke-ArConvertCommand $w[1] $w[2] $w[3]
    }
    if ($w.Count -eq 3) { return Invoke-ArConvertCommand $w[0] $w[1] $w[2] }   # the word is optional
    Throw-Ar 'UNKNOWN_COMMAND' 'Not a command. Try: convert 100 cm in'
}