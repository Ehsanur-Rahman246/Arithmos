# cli/tools.sh — tool bindings: prompt loops for the calculators and the guided converter.
# This and cli.sh are the only code that turns results into text.

STD_HELP=$'Standard Calculator: type an expression and press Enter.\n  + - * / ^ ( )  %  of  sqrt()  abs()  ans\n  help or ?  this text    back  return to the menu    quit  leave Arithmos'
PROG_HELP=$'Programmer Calculator: 64-bit signed integers.\n  <value>   show in HEX / DEC / OCT / BIN     0b 0o 0d 0x prefixes\n  base <bin|oct|dec|hex>   set the input base\n  [convert] <value> <from> <to>   e.g. 255 dec hex\n  AND OR XOR NOT   << >> >>>   (shift count is decimal 0-63)\n  help or ?  this text    back  return to the menu    quit  leave Arithmos'
CONV_PICK_HELP=$'Type a number, a name or a symbol from the list.\n  One-line commands work here too: 100 cm in, convert 100 cm in, list, list length\n  back  go back one screen    quit  leave Arithmos'
CONV_VALUES_HELP=$'Type a value to convert, e.g. 100\n  Or a one-line command: 100 cm in, convert 1 km all, list, list pressure\n  back  choose other units    quit  leave Arithmos'

# tool_report STATUS — print the engine's outcome: the result, or "Error [CODE]: message".
tool_report() {
    if (( $1 == 0 )); then
        $IO_WRITE "$AR_OUT"$'\n'
    else
        $IO_WRITE "Error [$AR_CODE]: $AR_MSG"$'\n'
    fi
}

# tool_loop PROMPT ENGINE_FN HELP_TEXT — the calculators' prompt loop.
# Returns 0 for `back` (go to the menu), 1 for `quit` or end of input.
# Blank lines are ignored; help / ? back quit are case-insensitive.
tool_loop() {
    local prompt=$1 engine=$2 helptext=$3 line lc
    while :; do
        $IO_READLINE "$prompt" || return 1
        ar_trim "$LINE"; line=$R; lc=${line,,}
        case $lc in
            '')        continue ;;
            back)      return 0 ;;
            quit)      return 1 ;;
            help|'?')  $IO_WRITE "$helptext"$'\n'; continue ;;
        esac
        "$engine" "$line"; tool_report $?
    done
}

# conv_pick_cmd LINE — one-line commands typed at a converter picker (100 cm in, list, …).
# Returns 0 when LINE ran as a command, 1 when it is just a wrong answer.
conv_pick_cmd() {
    local -a words
    read -r -a words <<<"$1"
    if (( ${#words[@]} >= 2 )) || [[ ${words[0],,} == list || ${words[0],,} == convert ]]; then
        conv_exec "$1"; tool_report $?; return 0
    fi
    return 1
}

# conv_pick_units CATEGORY TITLE — a picker over the units of one category.
conv_pick_units() {
    local s i=0
    pick_reset
    PK_TITLE=$2; PK_BACK=1; PK_QUIT=1; PK_CMD=conv_pick_cmd; PK_HELP=$CONV_PICK_HELP
    for s in ${CAT_SYMS[$1]}; do
        PK_VAL[i]=$s; PK_LAB[i]="$s — ${U_NAME[$s]}"; PK_ALT[i]=${U_NAME[$s]}
        PK_NUM[i]=$(( i + 1 )); i=$(( i + 1 ))
    done
    pick
}

# conv_values_loop FROM TO — the values prompt: converter (m → yd)>
# Returns 0 for `back` (choose other units), 1 for quit / end of input.
conv_values_loop() {
    local from=$1 to=$2 line lc
    local -a words
    while :; do
        $IO_READLINE "converter ($from → $to)> " || return 1
        ar_trim "$LINE"; line=$R; lc=${line,,}
        case $lc in
            '')        continue ;;
            back)      return 0 ;;
            quit)      return 1 ;;
            help|'?')  $IO_WRITE "$CONV_VALUES_HELP"$'\n'; continue ;;
        esac
        read -r -a words <<<"$line"
        if (( ${#words[@]} == 1 )) && [[ $lc != list && $lc != convert ]]; then
            conv_run "$line" "$from" "$to"                 # a bare value
            if (( $? == 0 )); then $IO_WRITE "$line $from = $AR_OUT $to"$'\n'
            else tool_report 1; fi
        else
            conv_exec "$line"; tool_report $?              # a full one-line form
        fi
    done
}

# tool_converter — guided flow: category → from → to → values. `back` steps back one
# stage and leaves to the main menu from the first. Returns 0 (menu) or 1 (quit/EOF).
tool_converter() {
    local stage=1 cat="" from="" to="" i
    while :; do
        case $stage in
            1)  pick_reset
                PK_TITLE="Unit Converter — choose a category"; PK_BACK=1; PK_QUIT=1
                PK_CMD=conv_pick_cmd; PK_HELP=$CONV_PICK_HELP
                for i in "${!CATEGORIES[@]}"; do
                    PK_VAL[i]=${CATEGORIES[i]}; PK_LAB[i]=${CATEGORIES[i]}
                    PK_ALT[i]=""; PK_NUM[i]=$(( i + 1 ))
                done
                pick
                case $PICK_KIND in back) return 0 ;; quit|eof) return 1 ;; esac
                cat=$PICK_VALUE; stage=2 ;;
            2)  conv_pick_units "$cat" "${cat^} — convert from"
                case $PICK_KIND in back) stage=1; continue ;; quit|eof) return 1 ;; esac
                from=$PICK_VALUE; stage=3 ;;
            3)  conv_pick_units "$cat" "${cat^} — convert from $from to"
                case $PICK_KIND in back) stage=2; continue ;; quit|eof) return 1 ;; esac
                to=$PICK_VALUE; stage=4 ;;
            4)  conv_values_loop "$from" "$to"
                if (( $? == 0 )); then stage=3; else return 1; fi ;;
        esac
    done
}