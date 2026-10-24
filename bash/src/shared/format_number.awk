# format_number.awk — the ONE number formatter (spec §2.3).
# Loaded as: awk -f format_number.awk -f <engine>.awk
# so the Standard Calculator and the Converter print identically.

# True when x is NaN or outside the double range (infinities compare beyond the max).
function ar_isbad(x) {
    return (x != x) || (x > 1.7976931348623157e308) || (x < -1.7976931348623157e308)
}

# ar_format(x): 12 significant digits, half away from zero, trailing zeros trimmed,
# plain notation for 1e-6 <= |x| < 1e15, otherwise <mantissa>e<sign><exponent>.
# The caller must have rejected NaN / Infinity first (they map to error codes).
function ar_format(x,    neg, s, parts, ex, mant, d, up, i, c, n, out, k) {
    if (x == 0) return "0"                         # also covers -0 (rule 4)
    neg = (x < 0)
    if (neg) x = -x

    # %.34e prints the exact binary value (35 significant digits), so ties such as
    # 100000000000.5 are visible; printf's own rounding (half to even) is not used.
    s = sprintf("%.34e", x)
    split(s, parts, "e")
    ex   = parts[2] + 0                            # decimal exponent
    mant = substr(parts[1], 1, 1) substr(parts[1], 3)   # the 35 digits, no point
    d    = substr(mant, 1, 12)                     # keep 12 digits
    up   = (substr(mant, 13, 1) + 0 >= 5)          # half away from zero: look at digit 13

    if (up) {                                      # add one unit in the 12th place
        i = 12
        while (i >= 1) {
            c = substr(d, i, 1) + 0
            if (c < 9) { d = substr(d, 1, i - 1) (c + 1) substr(d, i + 1); break }
            d = substr(d, 1, i - 1) "0" substr(d, i + 1)
            i--
        }
        if (i == 0) { d = "1" substr(d, 1, 11); ex++ }   # 99…9 rolled over to 100…0
    }

    sub(/0+$/, "", d)                              # trim trailing zeros
    n = length(d)

    if (ex >= -6 && ex < 15) {                     # plain notation
        if (ex >= 0) {
            if (n <= ex + 1) {                     # integer: pad with zeros
                out = d
                for (k = n; k < ex + 1; k++) out = out "0"
            } else {
                out = substr(d, 1, ex + 1) "." substr(d, ex + 2)
            }
        } else {                                   # 0.000ddd
            out = "0."
            for (k = -1; k > ex; k--) out = out "0"
            out = out d
        }
    } else {                                       # scientific: 1.5e+20, 2e-7
        out = substr(d, 1, 1)
        if (n > 1) out = out "." substr(d, 2)
        out = out "e" (ex < 0 ? "-" : "+") (ex < 0 ? -ex : ex)
    }
    return (neg ? "-" : "") out
}