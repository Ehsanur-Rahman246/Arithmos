# cli/pick.sh — pick(): one question, many answers.
# On a real terminal it is the arrow-key selector; everywhere else a numbered list
# answered by typing a number, a name or a symbol (spec §2.1: both are required).
#
# Inputs:  PK_TITLE  PK_VAL[] PK_LAB[] PK_ALT[] PK_NUM[]  PK_BACK PK_QUIT
#          PK_CMD  (optional function: runs a typed one-line command, returns 0 when it did)
#          PK_HELP (text for `help`)
# Outputs: PICK_KIND = choice | back | quit | eof,  PICK_INDEX,  PICK_VALUE
#
# Typed answers, in order: number / value / name / label → choice; help or ? → help text;
# back / quit (when offered); a one-line command via PK_CMD; otherwise
# Error [UNKNOWN_COMMAND] and the list is shown again.

PK_TITLE=""; PK_VAL=(); PK_LAB=(); PK_ALT=(); PK_NUM=()
PK_BACK=0; PK_QUIT=1; PK_CMD=""; PK_HELP=""
PICK_KIND=""; PICK_INDEX=0; PICK_VALUE=""

pick_reset() {
    PK_TITLE=""; PK_VAL=(); PK_LAB=(); PK_ALT=(); PK_NUM=()
    PK_BACK=0; PK_QUIT=1; PK_CMD=""; PK_HELP=""
}

# pick_answer LINE — interpret one typed line; leaves PICK_KIND empty to ask again.
pick_answer() {
    local line lc i
    ar_trim "$1"; line=$R; lc=${line,,}
    [[ -z $lc ]] && return 0
    for i in "${!PK_VAL[@]}"; do
        if [[ $lc == "${PK_NUM[i]}" || $lc == "${PK_VAL[i],,}" \
           || $lc == "${PK_ALT[i],,}" || $lc == "${PK_LAB[i],,}" ]]; then
            PICK_KIND=choice; PICK_INDEX=$i; PICK_VALUE=${PK_VAL[i]}; return 0
        fi
    done
    case $lc in
        help|'?') $IO_WRITE "$PK_HELP"$'\n'; return 0 ;;
        back) if (( PK_BACK )); then PICK_KIND=back; return 0; fi ;;
        quit) if (( PK_QUIT )); then PICK_KIND=quit; return 0; fi ;;
    esac
    if [[ -n $PK_CMD ]] && $PK_CMD "$line"; then return 0; fi
    $IO_WRITE "Error [UNKNOWN_COMMAND]: Pick one from the list"$'\n'
    return 0
}

pick() {
    local line i
    PICK_KIND=""
    while :; do
        if [[ -n $IO_SELECT ]]; then
            SEL_TITLE=$PK_TITLE; SEL_OPTS=("${PK_LAB[@]}")
            SEL_BACK=$PK_BACK; SEL_QUIT=$PK_QUIT; SEL_TYPING=1; SEL_START=0
            $IO_SELECT
            case $SEL_RESULT in
                index) PICK_KIND=choice; PICK_INDEX=$SEL_INDEX
                       PICK_VALUE=${PK_VAL[SEL_INDEX]}; return 0 ;;
                back|quit|eof) PICK_KIND=$SEL_RESULT; return 0 ;;     # b / q / Esc act at once
                typed)                                                # a printable key opened a line
                    $IO_PREFILL "> " "$SEL_CHAR" || { PICK_KIND=eof; return 0; }
                    line=$LINE ;;
                *) PICK_KIND=eof; return 0 ;;
            esac
        else
            $IO_WRITE "$PK_TITLE"$'\n'
            for i in "${!PK_LAB[@]}"; do $IO_WRITE "  ${PK_NUM[i]}) ${PK_LAB[i]}"$'\n'; done
            $IO_READLINE "> " || { PICK_KIND=eof; return 0; }
            line=$LINE
        fi
        pick_answer "$line"
        [[ -n $PICK_KIND ]] && return 0
    done
}