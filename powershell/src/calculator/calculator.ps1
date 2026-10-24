# Standard Calculator engine (spec §3): tokenize -> parse (AST) -> evaluate -> format.
# Pure logic: no console I/O. Failures call Throw-Ar.
#
# Token: @{ t = 'num'|'op'|'word'|'end'; v = value; raw = text }
# AST  : @{ k = 'num'|'ans'|'group'|'neg'|'pos'|'pct'|'fn'|'bin'; ... }
# Parser state $P: @{ T = tokens; I = position }

function Get-ArTokens {
    param([string]$Text)
    $inv    = [System.Globalization.CultureInfo]::InvariantCulture
    $tokens = [System.Collections.Generic.List[hashtable]]::new()
    $i = 0
    while ($i -lt $Text.Length) {
        $c = $Text[$i]
        if ([char]::IsWhiteSpace($c)) { $i++; continue }
        $rest = $Text.Substring($i)

        # Numbers: 12, 12.5, .5, 5.  ("1e5" is not supported: 'e5' becomes an unknown word)
        if ($rest -match '^[0-9.]+') {
            $lex = $Matches[0]
            $dots = $lex.Split('.').Count - 1
            if ($dots -gt 1 -or $lex -notmatch '[0-9]') {
                Throw-Ar 'INVALID_EXPRESSION' "Unexpected character '.'"
            }
            $val = [double]::Parse($lex, [System.Globalization.NumberStyles]::Float, $inv)
            if ([double]::IsInfinity($val)) { Throw-Ar 'OVERFLOW' 'That number is too large' }
            $tokens.Add(@{ t = 'num'; v = $val; raw = $lex })
            $i += $lex.Length
            continue
        }

        # Words: sqrt, abs, ans, of (case-insensitive); anything else is an error.
        if ($rest -match '^[A-Za-z_][A-Za-z0-9_]*') {
            $lex = $Matches[0]
            $low = $lex.ToLowerInvariant()
            if ($low -notin @('sqrt', 'abs', 'ans', 'of')) {
                Throw-Ar 'INVALID_EXPRESSION' "Unknown word '$lex'"
            }
            $tokens.Add(@{ t = 'word'; v = $low; raw = $lex })
            $i += $lex.Length
            continue
        }

        if ('+-*/^()%'.Contains([string]$c)) {
            $tokens.Add(@{ t = 'op'; v = [string]$c; raw = [string]$c })
            $i++
            continue
        }
        Throw-Ar 'INVALID_EXPRESSION' "Unexpected character '$c'"
    }
    $tokens.Add(@{ t = 'end'; v = ''; raw = '' })
    return , $tokens.ToArray()          # the comma stops PowerShell unrolling the array
}

# True when the token is an operator whose symbol is one of the characters in $Ops.
function Test-ArOp {
    param($Tok, [string]$Ops)
    return ($Tok.t -eq 'op' -and $Ops.Contains([string]$Tok.v))
}

# ---- Parser. Precedence, high to low (spec §3.3):
#   ( ) and calls  >  postfix %  >  ^ (right-assoc)  >  unary + -  >  * / of  >  + -

function Read-ArExpr {                       # + -
    param($P)
    $left = Read-ArTerm $P
    while ($true) {
        $t = $P.T[$P.I]
        if (-not (Test-ArOp $t '+-')) { break }
        $P.I++
        $right = Read-ArTerm $P
        $left = @{ k = 'bin'; op = $t.v; l = $left; r = $right }
    }
    return $left
}

function Read-ArTerm {                       # * / of
    param($P)
    $left = Read-ArUnary $P
    while ($true) {
        $t = $P.T[$P.I]
        $isMul = Test-ArOp $t '*/'
        $isOf  = ($t.t -eq 'word' -and $t.v -eq 'of')
        if (-not ($isMul -or $isOf)) { break }
        $P.I++
        $right = Read-ArUnary $P
        $op = '*'                            # 'of' is sugar for '*'
        if ($isMul) { $op = $t.v }
        $left = @{ k = 'bin'; op = $op; l = $left; r = $right }
    }
    return $left
}

function Read-ArUnary {                      # unary + - (binds looser than ^: -2^2 = -4)
    param($P)
    $t = $P.T[$P.I]
    if (Test-ArOp $t '+-') {
        $P.I++
        $e = Read-ArUnary $P
        if ($t.v -eq '-') { return @{ k = 'neg'; e = $e } }
        return @{ k = 'pos'; e = $e }
    }
    return Read-ArPower $P
}

function Read-ArPower {                      # ^ is right-associative; its exponent may be unary
    param($P)
    $base = Read-ArPostfix $P
    $t = $P.T[$P.I]
    if (Test-ArOp $t '^') {
        $P.I++
        $exp = Read-ArUnary $P               # 2^3^2 -> 2^(3^2); 2^-1 works
        return @{ k = 'bin'; op = '^'; l = $base; r = $exp }
    }
    return $base
}

function Read-ArPostfix {                    # postfix %, may repeat (50%%)
    param($P)
    $e = Read-ArPrimary $P
    while ($true) {
        $cur = $P.T[$P.I]
        if (-not (Test-ArOp $cur '%')) { break }
        $P.I++
        $e = @{ k = 'pct'; e = $e }
    }
    return $e
}

function Read-ArClose {                      # expects ')'
    param($P)
    $t = $P.T[$P.I]
    if (Test-ArOp $t ')') { $P.I++; return }
    if ($t.t -eq 'end') { Throw-Ar 'INVALID_EXPRESSION' 'Missing closing parenthesis' }
    Throw-Ar 'INVALID_EXPRESSION' 'Unexpected symbol'
}

function Read-ArPrimary {
    param($P)
    $t = $P.T[$P.I]
    if ($t.t -eq 'num') { $P.I++; return @{ k = 'num'; v = $t.v } }
    if ($t.t -eq 'word') {
        if ($t.v -eq 'ans') { $P.I++; return @{ k = 'ans' } }
        if ($t.v -eq 'of')  { Throw-Ar 'INVALID_EXPRESSION' "Unexpected 'of'" }
        $fn = $t.v                           # sqrt or abs: parentheses are required
        $P.I++
        $nx = $P.T[$P.I]
        if (-not (Test-ArOp $nx '(')) {
            Throw-Ar 'INVALID_EXPRESSION' "$fn needs parentheses, like ${fn}(4)"
        }
        $P.I++
        $arg = Read-ArExpr $P
        Read-ArClose $P
        return @{ k = 'fn'; name = $fn; e = $arg }
    }
    if (Test-ArOp $t '(') {
        $P.I++
        $inner = Read-ArExpr $P
        Read-ArClose $P
        # 'group' stops a % inside parentheses from acting as a relative percent: 200 + (10%) = 200.1
        return @{ k = 'group'; e = $inner }
    }
    if ($t.t -eq 'end') { Throw-Ar 'INVALID_EXPRESSION' 'The expression ends too early' }
    Throw-Ar 'INVALID_EXPRESSION' 'Unexpected symbol'
}

# ---- Evaluator (IEEE doubles) ----

function Assert-ArResult {
    param([double]$R)
    if ([double]::IsNaN($R))      { Throw-Ar 'DOMAIN_ERROR' 'The result is not a number' }
    if ([double]::IsInfinity($R)) { Throw-Ar 'OVERFLOW' 'The result is too large' }
    return $R
}

function Get-ArPower {                       # spec §3.5
    param([double]$A, [double]$B)
    if ($A -eq 0 -and $B -eq 0) { Throw-Ar 'UNDEFINED' '0^0 is undefined' }
    if ($A -eq 0 -and $B -lt 0) { Throw-Ar 'DIV_BY_ZERO' 'Zero cannot be raised to a negative power' }
    if ($A -lt 0 -and $B -ne [math]::Floor($B)) {
        Throw-Ar 'DOMAIN_ERROR' 'A negative number cannot have a fractional power'
    }
    return [math]::Pow($A, $B)
}

function Invoke-ArEval {
    param($Node, $Ctx)
    $k = $Node.k
    if ($k -eq 'num')   { return [double]$Node.v }
    if ($k -eq 'ans')   { return [double]$Ctx.Ans }
    if ($k -eq 'group') { return Invoke-ArEval $Node.e $Ctx }
    if ($k -eq 'neg')   { $v = Invoke-ArEval $Node.e $Ctx; return -$v }
    if ($k -eq 'pos')   { return Invoke-ArEval $Node.e $Ctx }
    if ($k -eq 'pct')   { $v = Invoke-ArEval $Node.e $Ctx; return $v / 100 }
    if ($k -eq 'fn') {
        $v = Invoke-ArEval $Node.e $Ctx
        if ($Node.name -eq 'sqrt') {
            if ($v -lt 0) { Throw-Ar 'DOMAIN_ERROR' 'Cannot take the square root of a negative number' }
            return [math]::Sqrt($v)
        }
        return [math]::Abs($v)
    }
    # Binary operator.
    $op = $Node.op
    $a  = Invoke-ArEval $Node.l $Ctx
    if (($op -eq '+' -or $op -eq '-') -and $Node.r.k -eq 'pct') {
        # A % that is the DIRECT right operand of + or - is relative to the left side.
        $b = $a * (Invoke-ArEval $Node.r $Ctx)
    }
    else {
        $b = Invoke-ArEval $Node.r $Ctx
    }
    if     ($op -eq '+') { $r = $a + $b }
    elseif ($op -eq '-') { $r = $a - $b }
    elseif ($op -eq '*') { $r = $a * $b }
    elseif ($op -eq '/') {
        if ($b -eq 0) { Throw-Ar 'DIV_BY_ZERO' 'Cannot divide by zero' }
        $r = $a / $b
    }
    else { $r = Get-ArPower $a $b }
    return Assert-ArResult $r
}

# Public entry: evaluate one line. $Session = @{ Ans = [double] }.
# ans changes only after a fully successful evaluation (spec §3.1).
function Invoke-ArStandard {
    param([string]$Line, [hashtable]$Session)
    $tokens = Get-ArTokens $Line
    if ($tokens.Count -eq 1) { Throw-Ar 'INVALID_EXPRESSION' 'Nothing to calculate' }
    $p = @{ T = $tokens; I = 0 }
    $ast = Read-ArExpr $p
    if ($p.T[$p.I].t -ne 'end') { Throw-Ar 'INVALID_EXPRESSION' 'Unexpected symbol' }   # 2(3), 2 3
    $v   = Invoke-ArEval $ast $Session
    $out = Format-ArNumber $v
    $Session.Ans = $v
    return $out
}