# programmer/programmer.sh — commands of the Programmer Calculator (spec §4.5).
# Session state: the input base. Pure logic; the result text is left in AR_OUT.

PR_BASE=dec
PR_KIND=text        # values | text | base   (what the last successful command produced)

# pr_show_all VALUE — HEX / DEC / OCT / BIN lines (spec §4.4) into AR_OUT.
pr_show_all() {
    local v=$1 hex dec oct bin
    i64_fmt "$v" hex; hex=$R
    i64_fmt "$v" dec; dec=$R
    i64_fmt "$v" oct; oct=$R
    i64_fmt "$v" bin; bin=$R
    AR_OUT="HEX: $hex"$'\n'"DEC: $dec"$'\n'"OCT: $oct"$'\n'"BIN: $bin"
    PR_KIND=values
    return 0
}

# pr_convert VALUE FROM TO — just the converted number in the target base.
# The explicit FROM base reads the value, independent of the input base.
pr_convert() {
    local from to v
    pr_base_name "$2" || return 1; from=$R
    pr_base_name "$3" || return 1; to=$R
    pr_parse "$1" "$from" || return 1; v=$R
    i64_fmt "$v" "$to"
    AR_OUT=$R; PR_KIND=text
    return 0
}

# pr_shift_line LINE — "<a> << <n>", ">>" and ">>>"; spaces around the operator are optional.
pr_shift_line() {
    local line=$1 left rest op right v n digits
    left=${line%%[<>]*}
    rest=${line:${#left}}
    case $rest in                                  # longest operator first
        '>>>'*) op='>>>'; right=${rest#'>>>'} ;;
        '>>'*)  op='>>';  right=${rest#'>>'} ;;
        '<<'*)  op='<<';  right=${rest#'<<'} ;;
        *) ar_fail UNKNOWN_COMMAND "Not a command. Try help"; return 1 ;;
    esac
    ar_trim "$left";  left=$R
    ar_trim "$right"; right=$R
    if [[ -z $left || -z $right || $left == *[[:space:]]* || $right == *[[:space:]]* ]]; then
        ar_fail UNKNOWN_COMMAND "Not a command. Try help"; return 1
    fi
    pr_parse "$left" "$PR_BASE" || return 1; v=$R
    # The count is always a plain decimal 0..63: "-1", "2.5", "0x3" are INVALID_SHIFT.
    if [[ ! $right =~ ^[0-9]+$ ]]; then
        ar_fail INVALID_SHIFT "A shift count must be a whole number from 0 to 63"; return 1
    fi
    digits=$right
    while [[ $digits == 0?* ]]; do digits=${digits#0}; done
    if (( ${#digits} > 2 )) || (( 10#$digits > 63 )); then
        ar_fail INVALID_SHIFT "A shift count must be a whole number from 0 to 63"; return 1
    fi
    n=$(( 10#$digits ))
    case $op in
        '<<')  R=$(( v << n )) ;;                  # bits shifted past bit 63 are dropped
        '>>')  R=$(( v >> n )) ;;                  # arithmetic, sign-extending
        '>>>') i64_lshr "$v" "$n" ;;               # logical, zero-filling
    esac
    pr_show_all "$R"
}

# pr_exec LINE — run one command line. 0 + AR_OUT on success, 1 + AR_CODE on error.
pr_exec() {
    local line a b v op n lc1
    local -a words
    AR_OUT=""; PR_KIND=text
    ar_trim "$1"; line=$R
    if [[ -z $line ]]; then
        ar_fail UNKNOWN_COMMAND "Type a number or a command. Try help"; return 1
    fi

    case $line in
        *\<*|*\>*) pr_shift_line "$line"; return ;;
    esac

    read -r -a words <<<"$line"
    n=${#words[@]}
    lc1=${words[0],,}

    case $lc1 in
        base)                                         # base <bin|oct|dec|hex>
            if (( n != 2 )); then ar_fail INVALID_BASE "Use: base bin | oct | dec | hex"; return 1; fi
            pr_base_name "${words[1]}" || return 1
            PR_BASE=$R; PR_KIND=base; AR_OUT="Input base: $PR_BASE"
            return 0 ;;
        not)                                          # NOT <a>
            if (( n != 2 )); then ar_fail UNKNOWN_COMMAND "Use: NOT <value>"; return 1; fi
            pr_parse "${words[1]}" "$PR_BASE" || return 1
            v=$(( ~R )); pr_show_all "$v"; return 0 ;;
        convert)                                      # convert <value> <from> <to>
            if (( n != 4 )); then ar_fail UNKNOWN_COMMAND "Use: convert <value> <from> <to>"; return 1; fi
            pr_convert "${words[1]}" "${words[2]}" "${words[3]}"; return ;;
    esac

    if (( n == 1 )); then                             # a bare value: show it in all bases
        pr_parse "${words[0]}" "$PR_BASE" || return 1
        pr_show_all "$R"; return 0
    fi

    if (( n == 3 )); then
        # The operator is always the MIDDLE word (R11), so "A AND F" works in hex mode.
        op=${words[1],,}
        case $op in
            and|or|xor)
                pr_parse "${words[0]}" "$PR_BASE" || return 1; a=$R
                pr_parse "${words[2]}" "$PR_BASE" || return 1; b=$R
                case $op in
                    and) v=$(( a & b )) ;;
                    or)  v=$(( a | b )) ;;
                    xor) v=$(( a ^ b )) ;;
                esac
                pr_show_all "$v"; return 0 ;;
        esac
        # "255 dec hex": the word `convert` may be omitted when the last two words are bases.
        if pr_is_base "${words[1]}" && pr_is_base "${words[2]}"; then
            pr_convert "${words[0]}" "${words[1]}" "${words[2]}"; return
        fi
    fi

    ar_fail UNKNOWN_COMMAND "Not a command. Try help"
    return 1
}