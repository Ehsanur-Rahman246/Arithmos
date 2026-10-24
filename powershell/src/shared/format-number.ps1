# Number formatting (spec §2.3): 12 significant digits, half away from zero,
# trailing zeros trimmed, plain notation for 1e-6 <= |x| < 1e15, else <m>e<sign><exp>.
#
# .NET Core 3.0+ prints doubles exactly: ToString('E34') gives the exact expansion
# (like printf("%.34e") in the C edition). We then round the digit string by hand:
# looking at digit 13 (>= 5 rounds up) IS half-away-from-zero on the exact value.

function Format-ArNumber {
    param([double]$X)
    if ([double]::IsNaN($X))      { Throw-Ar 'INVALID_EXPRESSION' 'Result is not a number' }
    if ([double]::IsInfinity($X)) { Throw-Ar 'OVERFLOW' 'Result is too large to represent' }
    if ($X -eq 0) { return '0' }                       # also turns -0 into 0

    $inv   = [System.Globalization.CultureInfo]::InvariantCulture
    $neg   = $X -lt 0
    $text  = [math]::Abs($X).ToString('E34', $inv)     # e.g. 1.2345...E+002
    $parts = $text.Split('E')
    $digits = $parts[0].Replace('.', '')               # 35 digits, first is non-zero
    $exp   = [int]::Parse($parts[1], $inv)             # exponent of the first digit

    # Keep 12 digits, round up when the 13th is 5 or more.
    $n = [System.Numerics.BigInteger]::Parse($digits.Substring(0, 12))
    if ([int]::Parse($digits.Substring(12, 1)) -ge 5) { $n = $n + 1 }
    $ds = $n.ToString()
    if ($ds.Length -gt 12) { $ds = $ds.Substring(0, 12); $exp = $exp + 1 }   # 999...9 carried
    $ds = $ds.TrimEnd('0')                                                   # trailing zeros

    if ($exp -ge -6 -and $exp -lt 15) {
        # Plain notation.
        if ($exp -ge 0) {
            $intLen = $exp + 1
            if ($ds.Length -le $intLen) { $body = $ds.PadRight($intLen, '0') }
            else { $body = $ds.Substring(0, $intLen) + '.' + $ds.Substring($intLen) }
        }
        else {
            $body = '0.' + ('0' * (-$exp - 1)) + $ds
        }
    }
    else {
        # Scientific notation: 1.5e+20, 2e-7.
        $m = $ds.Substring(0, 1)
        if ($ds.Length -gt 1) { $m = $m + '.' + $ds.Substring(1) }
        $sign = '+'
        if ($exp -lt 0) { $sign = '-' }
        $body = "${m}e${sign}$([math]::Abs($exp))"
    }
    if ($neg) { return '-' + $body }
    return $body
}