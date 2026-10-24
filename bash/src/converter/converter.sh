# converter/converter.sh — Unit Converter commands (spec §5.1). Pure logic.

# conv_known SYMBOL — true when SYMBOL (already lower-case) is a unit.
# The regex guard matters: an associative-array subscript of * or @ means "all".
conv_known() { [[ $1 =~ ^[a-z0-9]+$ && -n ${U_CAT[$1]+x} ]]; }

# conv_list [CATEGORY] — all categories, or the unit symbols of one category.
conv_list() {
    local c s out="" first=1
    if (( $# == 0 )); then
        for c in "${CATEGORIES[@]}"; do out+="${out:+, }$c"; done
    elif (( $# == 1 )); then
        c=${1,,}
        if [[ ! $c =~ ^[a-z]+$ || -z ${CAT_SYMS[$c]+x} ]]; then
            ar_fail UNKNOWN_COMMAND "'$1' is not a category. Try: list"; return 1
        fi
        for s in ${CAT_SYMS[$c]}; do out+="${out:+, }$s"; done
    else
        ar_fail UNKNOWN_COMMAND "Use: list  or  list <category>"; return 1
    fi
    AR_OUT=$out
    return 0
}

# conv_run VALUE FROM TO — convert; TO may be "all".
conv_run() {
    local v=$1 from=${2,,} to=${3,,} cat syms facs s mode out first code msg
    local re='^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)$'      # a plain decimal; no 1e3, no commas
    if [[ ! $v =~ $re ]]; then ar_fail INVALID_NUMBER "'$1' is not a number"; return 1; fi
    if ! conv_known "$from"; then ar_fail UNKNOWN_UNIT "'$2' is not a known unit. Try: list"; return 1; fi
    cat=${U_CAT[$from]}
    if [[ $to == all ]]; then
        mode=all; syms=${CAT_SYMS[$cat]}
    else
        if ! conv_known "$to"; then ar_fail UNKNOWN_UNIT "'$3' is not a known unit. Try: list"; return 1; fi
        if [[ ${U_CAT[$to]} != "$cat" ]]; then
            ar_fail INCOMPATIBLE_UNITS "Cannot convert $cat to ${U_CAT[$to]}"; return 1
        fi
        mode=one; syms=$to
    fi
    facs=""
    for s in $syms; do facs+="${U_FAC[$s]} "; done
    out=$(AR_VALUE=$v AR_CAT=$cat AR_FROM=$from AR_FFAC=${U_FAC[$from]} AR_MODE=$mode \
          AR_SYMS=$syms AR_FACS=$facs "$AR_AWK" \
            -f "$AR_SRC/shared/format_number.awk" \
            -f "$AR_SRC/converter/converter.awk" 2>/dev/null)
    first=${out%%$'\n'*}
    case $first in
        OK)  AR_OUT=${out#*$'\n'}; return 0 ;;
        ERR*) IFS=$'\t' read -r _ code msg <<<"$first"; ar_fail "$code" "$msg"; return 1 ;;
        *)   ar_fail INTERNAL "the converter engine produced no result"; return 1 ;;
    esac
}

# conv_exec LINE — the one-line forms: convert 100 cm in | 100 cm in | list | list length
conv_exec() {
    local line n w1
    local -a words
    AR_OUT=""
    ar_trim "$1"; line=$R
    if [[ -z $line ]]; then ar_fail UNKNOWN_COMMAND "Type a value, e.g. 100"; return 1; fi
    read -r -a words <<<"$line"
    n=${#words[@]}; w1=${words[0],,}
    if [[ $w1 == list ]]; then conv_list "${words[@]:1}"; return; fi
    if [[ $w1 == convert ]]; then
        if (( n != 4 )); then ar_fail UNKNOWN_COMMAND "Use: convert <value> <from> <to>"; return 1; fi
        conv_run "${words[1]}" "${words[2]}" "${words[3]}"; return
    fi
    if (( n == 3 )); then conv_run "${words[0]}" "${words[1]}" "${words[2]}"; return; fi
    ar_fail UNKNOWN_COMMAND "Not a command. Try: convert 100 cm in"
    return 1
}