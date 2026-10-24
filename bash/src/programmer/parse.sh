# programmer/parse.sh — literal parsing (spec §4.2, §4.3).
# Order: sign → prefix → garbage check (INVALID_NUMBER) → digit check (INVALID_DIGIT)
# → range (OUT_OF_RANGE). User text is NEVER fed to $(( )) directly: it is validated
# as digits first, so there is no arithmetic injection and no silent overflow.

PR_DIGITS=0123456789ABCDEF
declare -A PR_RADIX=([bin]=2 [oct]=8 [dec]=10 [hex]=16)
declare -A PR_BITS=([bin]=1 [oct]=3 [hex]=4)
declare -A PR_VALID=([bin]='^[01]+$' [oct]='^[0-7]+$' [dec]='^[0-9]+$' [hex]='^[0-9A-Fa-f]+$')

# pr_digit_value CHAR — numeric value in R; 16 when CHAR is not a hex digit
# (so it is invalid in every base).
pr_digit_value() {
    local d=${1^^} head
    head=${PR_DIGITS%%"$d"*}
    R=${#head}
}

# pr_base_name TEXT — canonical lower-case base name in R, or INVALID_BASE.
pr_base_name() {
    local t=${1,,}
    case $t in bin|oct|dec|hex) R=$t; return 0 ;; esac
    ar_fail INVALID_BASE "'$1' is not a base. Use bin, oct, dec or hex"
}

pr_is_base() { case ${1,,} in bin|oct|dec|hex) return 0 ;; esac; return 1; }

# pr_parse TEXT BASE — value in R (a 64-bit signed integer), or an error.
pr_parse() {
    local text=$1 base=$2 neg=0 body i ch len lim v bits first blen
    body=$text
    if [[ $body == -* ]]; then neg=1; body=${body#-}; fi

    # A prefix overrides the input base, but only when something follows it (R30):
    # "0B" in hex mode is the number 11, "0B1" is binary 1.
    if   [[ $body =~ ^0[bB](.+)$ ]]; then base=bin; body=${BASH_REMATCH[1]}
    elif [[ $body =~ ^0[oO](.+)$ ]]; then base=oct; body=${BASH_REMATCH[1]}
    elif [[ $body =~ ^0[dD](.+)$ ]]; then base=dec; body=${BASH_REMATCH[1]}
    elif [[ $body =~ ^0[xX](.+)$ ]]; then base=hex; body=${BASH_REMATCH[1]}
    fi

    # Empty or non-alphanumeric garbage → INVALID_NUMBER.
    if [[ -z $body || ! $body =~ ^[[:alnum:]]+$ ]]; then
        ar_fail INVALID_NUMBER "'$text' is not a number"; return 1
    fi

    # First digit that does not exist in the base → INVALID_DIGIT.
    if [[ ! $body =~ ${PR_VALID[$base]} ]]; then
        for (( i = 0; i < ${#body}; i++ )); do
            ch=${body:i:1}
            pr_digit_value "$ch"
            if (( R >= PR_RADIX[$base] )); then
                ar_fail INVALID_DIGIT "'${ch^^}' is not a $base digit"; return 1
            fi
        done
    fi

    while [[ $body == 0?* ]]; do body=${body#0}; done      # strip leading zeros (keep one)

    if [[ $base == dec ]]; then
        # Compare as strings against the limits; $(( )) would wrap silently.
        len=${#body}
        if (( neg )); then lim=9223372036854775808; else lim=9223372036854775807; fi
        if (( len > 19 )) || { (( len == 19 )) && [[ $body > $lim ]]; }; then
            ar_fail OUT_OF_RANGE "That number does not fit in 64 bits"; return 1
        fi
        if (( neg )) && [[ $body == 9223372036854775808 ]]; then
            R=$I64_MIN
        else
            R=$(( 10#$body ))                              # fits: at most INT_MAX
            if (( neg )); then R=$(( -R )); fi
        fi
        return 0
    fi

    # bin / oct / hex: a raw bit pattern of at most 64 bits, reinterpreted as signed.
    bits=${PR_BITS[$base]}
    pr_digit_value "${body:0:1}"; first=$R
    if   (( first >= 8 )); then blen=4
    elif (( first >= 4 )); then blen=3
    elif (( first >= 2 )); then blen=2
    else blen=1; fi
    if (( (${#body} - 1) * bits + blen > 64 )); then
        if (( neg )); then ar_fail OUT_OF_RANGE "That number does not fit in 64 bits"
        else ar_fail OUT_OF_RANGE "That number needs more than 64 bits"; fi
        return 1
    fi
    v=0
    for (( i = 0; i < ${#body}; i++ )); do
        pr_digit_value "${body:i:1}"
        v=$(( (v << bits) | R ))                           # never shifts out a set bit
    done
    if (( neg )); then
        # The magnitude must not exceed 2^63: as a signed pattern, only INT_MIN is negative.
        if (( v < 0 && v != I64_MIN )); then
            ar_fail OUT_OF_RANGE "That number does not fit in 64 bits"; return 1
        fi
        v=$(( -v ))
    fi
    R=$v
    return 0
}