# converter.awk — the arithmetic of the Unit Converter (spec §5.2).
# Input (environment): AR_VALUE, AR_CAT, AR_FROM (symbol), AR_FFAC (its factor),
#                      AR_MODE (one | all), AR_SYMS and AR_FACS (target symbols / factors,
#                      space separated, same order).
# Output: line 1 = OK or ERR<TAB>CODE<TAB>message; then one line per target
#         ("value" for one, "symbol: value" for all).

function num(t) { return (t == "pi") ? atan2(0, -1) : t + 0 }           # π at full precision
function fac(s,    p) {                                                  # "a/b" ratios stay exact
    if (index(s, "/") > 0) { split(s, p, "/"); return num(p[1]) / num(p[2]) }
    return num(s)
}

# Temperature goes through °C and is formula based (offsets, not factors).
function to_c(v, u)   { if (u == "c") return v; if (u == "f") return (v - 32) * 5 / 9; return v - 273.15 }
function from_c(c, u) { if (u == "c") return c; if (u == "f") return c * 9 / 5 + 32;   return c + 273.15 }
function below(v, u)  { return (u == "c" && v < -273.15) || (u == "f" && v < -459.67) || (u == "k" && v < 0) }

BEGIN {
    value = ENVIRON["AR_VALUE"] + 0
    if (ar_isbad(value)) { print "ERR\tOVERFLOW\tThat number is too large"; exit }
    cat  = ENVIRON["AR_CAT"];  from = ENVIRON["AR_FROM"]; mode = ENVIRON["AR_MODE"]
    ffac = fac(ENVIRON["AR_FFAC"])
    n = split(ENVIRON["AR_SYMS"], syms, " ")
    split(ENVIRON["AR_FACS"], facs, " ")

    # Only the input needs checking: if it is not below absolute zero, no result is.
    if (cat == "temperature" && below(value, from)) {
        print "ERR\tBELOW_ABSOLUTE_ZERO\tThat is below absolute zero"; exit
    }
    for (i = 1; i <= n; i++) {
        if (cat == "temperature") r = from_c(to_c(value, from), syms[i])
        else                      r = value * ffac / fac(facs[i])      # value × from ÷ to
        if (ar_isbad(r)) { print "ERR\tOVERFLOW\tResult is too large to represent"; exit }
        out[i] = (mode == "all") ? syms[i] ": " ar_format(r) : ar_format(r)
    }
    print "OK"                                      # printed only after every target succeeded:
    for (i = 1; i <= n; i++) print out[i]           # a failing `all` never shows partial lines
    exit
}