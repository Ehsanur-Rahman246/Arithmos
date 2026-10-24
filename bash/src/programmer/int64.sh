# programmer/int64.sh — the 64-bit signed two's-complement model (spec §4.1).
# Bash arithmetic is a native signed 64-bit integer that wraps on overflow, so
# `<<`, `>>` (arithmetic) and the bitwise operators need no emulation. Only `>>>`
# is built by hand. Results are returned in R.

I64_MAX=9223372036854775807
I64_MIN=$(( -I64_MAX - 1 ))

# i64_lshr VALUE COUNT — logical right shift, COUNT in 0..63.
# (v >> n) sign-extends; the mask INT_MAX >> (n-1) clears exactly the n filled bits.
i64_lshr() {
    local v=$1 n=$2
    if (( n == 0 )); then R=$v; else R=$(( (v >> n) & (I64_MAX >> (n - 1)) )); fi
}

# i64_bin VALUE — full 64-bit pattern in binary, no leading zeros ("0" for zero).
i64_bin() {
    local v=$1 i bit out=""
    for (( i = 63; i >= 0; i-- )); do
        bit=$(( (v >> i) & 1 ))
        if [[ -n $out || $bit == 1 ]]; then out+=$bit; fi
    done
    R=${out:-0}
}

# i64_fmt VALUE BASE — text in bin|oct|dec|hex. For negatives hex/oct/bin show the
# full 64-bit pattern (bash printf converts to unsigned), dec shows the signed value.
i64_fmt() {
    case $2 in
        dec) printf -v R '%d' "$1" ;;
        hex) printf -v R '%X' "$1" ;;
        oct) printf -v R '%o' "$1" ;;
        bin) i64_bin "$1" ;;
    esac
}