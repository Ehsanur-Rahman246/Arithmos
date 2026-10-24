#!/usr/bin/env bash
# test/run_selector.sh — selector tests SL1–SL21 plus X2 (widths, short terminals, erase)
# and X3 (raw bytes → keys). Same numbers as the other editions (docs/test-cases.md).
# Everything runs over a fake keyboard and a fake screen; no real terminal is needed.

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
AR_ROOT=$PWD; AR_SRC=$AR_ROOT/src
source "$AR_SRC/autoload.sh"

ASSERTS=0; FAILS=0; CUR=""
check() {   # LABEL EXPECTED ACTUAL
    ASSERTS=$((ASSERTS + 1)); [[ $2 == "$3" ]] && return 0
    FAILS=$((FAILS + 1)); printf 'FAIL %s (%s): expected [%s] got [%s]\n' "$CUR" "$1" "$2" "$3"
}
has() {     # LABEL HAYSTACK NEEDLE
    ASSERTS=$((ASSERTS + 1)); [[ $2 == *"$3"* ]] && return 0
    FAILS=$((FAILS + 1)); printf 'FAIL %s (%s): [%s] lacks [%s]\n' "$CUR" "$1" "$2" "$3"
}
hasnt() {
    ASSERTS=$((ASSERTS + 1)); [[ $2 != *"$3"* ]] && return 0
    FAILS=$((FAILS + 1)); printf 'FAIL %s (%s): [%s] contains [%s]\n' "$CUR" "$1" "$2" "$3"
}

# ---- fakes: keyboard, screen, size -------------------------------------------------
FK_KEYS=(); FK_OUT=""; FK_W=80; FK_H=24
fk_key() {                                  # pops the next scripted key; 1 = end of input
    (( ${#FK_KEYS[@]} )) || return 1
    local k=${FK_KEYS[0]}
    FK_KEYS=("${FK_KEYS[@]:1}")
    case $k in char:*) KEY=char; KEY_CHAR=${k#char:} ;; *) KEY=$k; KEY_CHAR="" ;; esac
    return 0
}
fk_out()  { FK_OUT+=$1; }
fk_size() { SEL_W=$FK_W; SEL_H=$FK_H; }

reset_sel() {
    SEL_TITLE="Pick"; SEL_OPTS=(a b c d); SEL_BACK=0; SEL_QUIT=0; SEL_TYPING=0; SEL_START=0
    SEL_KEYFN=fk_key; SEL_OUTFN=fk_out; SEL_SIZEFN=fk_size
    ST_BOLD=""; ST_DIM=""; ST_REV=""; ST_OFF=""
    FK_KEYS=(); FK_OUT=""; FK_W=80; FK_H=24
}
run() { FK_KEYS=("$@"); FK_OUT=""; sel_loop; }          # run the loop over scripted keys

# ---- fakes for pick(): scripted selector results and typed lines ---------------------
FK_LINES=(); FK_SEL=(); FK_SELCALLS=0; FK_PREFILLS=0; FK_CMDRAN=""
fk_pop_line() { (( ${#FK_LINES[@]} )) || return 1; LINE=${FK_LINES[0]}; FK_LINES=("${FK_LINES[@]:1}"); }
fk_readline() { fk_pop_line; }
fk_prefill()  { FK_PREFILLS=$((FK_PREFILLS + 1)); fk_pop_line; }
fk_select() {
    FK_SELCALLS=$((FK_SELCALLS + 1))
    if (( ${#FK_SEL[@]} == 0 )); then SEL_RESULT=eof; return 0; fi
    local r=${FK_SEL[0]}; FK_SEL=("${FK_SEL[@]:1}")
    case $r in
        index:*) SEL_RESULT=index; SEL_INDEX=${r#index:} ;;
        typed:*) SEL_RESULT=typed; SEL_CHAR=${r#typed:} ;;
        *)       SEL_RESULT=$r ;;
    esac
}
fk_cmd() { FK_CMDRAN=$1; return 0; }                     # a one-line command handler that "ran"
reset_pick() {
    pick_reset; PK_TITLE=T; PK_VAL=(a b c); PK_LAB=(alpha beta gamma); PK_ALT=("" "" "")
    PK_NUM=(1 2 3); PK_BACK=1; PK_QUIT=1
    FK_OUT=""; FK_LINES=(); FK_SEL=(); FK_SELCALLS=0; FK_PREFILLS=0; FK_CMDRAN=""
    IO_WRITE=fk_out; IO_READLINE=fk_readline; IO_PREFILL=fk_prefill; IO_SELECT=fk_select
}

# ---- SL1–SL21 ----------------------------------------------------------------------------
t_SL1() {   # up/down move, wrap around, home/end
    reset_sel; run up enter;                   check "up wraps to last" 3 "$SEL_INDEX"
    reset_sel; run down down enter;            check "down" 2 "$SEL_INDEX"
    reset_sel; run down down home enter;       check "home" 0 "$SEL_INDEX"
    reset_sel; run end enter;                  check "end" 3 "$SEL_INDEX"
    reset_sel; run down down down down enter;  check "down wraps to first" 0 "$SEL_INDEX"
}
t_SL2() {   # long lists scroll in a window of 10
    local i
    reset_sel; SEL_OPTS=(); for i in {0..14}; do SEL_OPTS+=("opt$i"); done
    fk_size; sel_window_rows
    check "window of 10" 10 "$SEL_ROWS"
    sel_draw 12 3
    check "title + 10 rows + hint" 12 "${#SEL_LINES[@]}"
    has   "selected row visible" "${SEL_LINES[*]}" opt12
    hasnt "scrolled-away row hidden" "${SEL_LINES[*]}" opt0
    run $(printf 'down %.0s' {1..12}) enter
    check "scrolled to row 12" 12 "$SEL_INDEX"
}
t_SL3() {   # Enter selects; Esc / b / q only work when offered
    reset_sel; run esc char:b char:q enter;  check "nothing offered" index "$SEL_RESULT"
    reset_sel; SEL_BACK=1; run esc;          check "Esc when offered" back "$SEL_RESULT"
    reset_sel; SEL_BACK=1; run char:b;       check "b when offered" back "$SEL_RESULT"
    reset_sel; SEL_QUIT=1; run char:q;       check "q when offered" quit "$SEL_RESULT"
    reset_sel; SEL_BACK=1; run char:q enter; check "q not offered" index "$SEL_RESULT"
}
t_SL4() {   # Ctrl-C / Ctrl-D abort; other control keys are ignored
    reset_sel; run ignore ctrl-c;  check "ctrl-c" eof "$SEL_RESULT"
    reset_sel; run ctrl-d;         check "ctrl-d" eof "$SEL_RESULT"
    reset_sel; run ignore enter;   check "control key ignored" index "$SEL_RESULT"
}
t_SL5() {   # typing on: a printable key ends the selector and carries the character
    reset_sel; SEL_TYPING=1; run char:x
    check "result" typed "$SEL_RESULT"; check "char" x "$SEL_CHAR"
}
t_SL6() {   # typing off: printable keys are ignored
    reset_sel; run char:x enter; check "ignored" index "$SEL_RESULT"
}
t_SL7() {   # typing on: Esc, b, q, arrows and Enter keep their meaning
    reset_sel; SEL_TYPING=1; SEL_BACK=1; SEL_QUIT=1
    run esc;         check "esc" back "$SEL_RESULT"
    run char:b;      check "b" back "$SEL_RESULT"
    run char:q;      check "q" quit "$SEL_RESULT"
    run down enter;  check "arrows + enter" 1 "$SEL_INDEX"
}
t_SL8() {   # typing on: space and control keys do not start a typed line
    sel_parse_bytes " ";       check "space" ignore "$KEY"
    sel_parse_bytes $'\x01';   check "ctrl-a" ignore "$KEY"
    reset_sel; SEL_TYPING=1; run ignore enter; check "loop goes on" index "$SEL_RESULT"
}
t_SL9() {   # the selected row is highlighted as a full bar
    reset_sel; ST_REV=$'\e[7m'; ST_OFF=$'\e[0m'; fk_size; sel_window_rows; sel_draw 1 0
    local line=${SEL_LINES[2]} bare
    bare=${line//"$ST_REV"/}; bare=${bare//"$ST_OFF"/}
    check "bar spans width-1 columns" 79 "${#bare}"
    has   "reverse video on" "$line" "$ST_REV"
    hasnt "other rows plain" "${SEL_LINES[1]}" "$ST_REV"
}
t_SL10() {  # plain mode still marks the selected row with the pointer
    reset_sel; fk_size; sel_window_rows; sel_draw 2 0
    check "pointer" "❯ c" "${SEL_LINES[3]}"; check "indent" "  a" "${SEL_LINES[1]}"
}
t_SL11() {  # hint line lists only the keys on offer
    reset_sel; sel_hint
    has "enter" "$R" Enter; hasnt "no Esc" "$R" Esc; hasnt "no quit" "$R" quit; hasnt "no type" "$R" type
}
t_SL12() {  # hint shows Esc/b back and "or type" when typing is on
    reset_sel; SEL_BACK=1; SEL_TYPING=1; SEL_QUIT=1; sel_hint
    has "back" "$R" "Esc/b back"; has "type" "$R" "or type"; has "quit" "$R" "q quit"
}
t_SL13() {  # loop: keys in, index out, summary left behind, cursor restored
    reset_sel; SEL_TITLE=Pick; run down enter
    check "index" 1 "$SEL_INDEX"
    has "summary" "$FK_OUT" "✔ Pick: b"
    has "cursor hidden" "$FK_OUT" $'\e[?25l'
    has "cursor restored" "$FK_OUT" $'\e[?25h'
}
t_SL14() {  # loop: Esc, ignored keys, Ctrl-C
    reset_sel; SEL_BACK=1; run ignore esc;   check "esc" back "$SEL_RESULT"
    reset_sel; run ignore ignore ctrl-c;     check "ctrl-c" eof "$SEL_RESULT"
    reset_sel; run;                          check "end of input" eof "$SEL_RESULT"
}
t_SL15() {  # loop: a typed key returns its character and restores the cursor
    reset_sel; SEL_TYPING=1; run char:7
    check "typed" typed "$SEL_RESULT"; check "char" 7 "$SEL_CHAR"
    has "cursor restored" "$FK_OUT" $'\e[?25h'
}
t_SL16() {  # pick() uses the selector when present and maps its results
    reset_pick; FK_SEL=(index:1); pick; check "choice" choice "$PICK_KIND"; check "value" b "$PICK_VALUE"
    reset_pick; FK_SEL=(back); pick;   check "back" back "$PICK_KIND"
    reset_pick; FK_SEL=(quit); pick;   check "quit" quit "$PICK_KIND"
    reset_pick; FK_SEL=(eof);  pick;   check "eof" eof "$PICK_KIND"
}
t_SL17() {  # pick(): a typed name or number selects it
    reset_pick; FK_SEL=(typed:g); FK_LINES=(gamma); pick; check "name" c "$PICK_VALUE"
    reset_pick; FK_SEL=(typed:2); FK_LINES=(2);     pick; check "number" b "$PICK_VALUE"
}
t_SL18() {  # pick(): a typed one-line command runs and the list comes back
    reset_pick; PK_CMD=fk_cmd; FK_SEL=(typed:1 index:0); FK_LINES=("100 cm in"); pick
    check "command ran" "100 cm in" "$FK_CMDRAN"
    check "list came back" 2 "$FK_SELCALLS"
    check "then a choice" a "$PICK_VALUE"
}
t_SL19() {  # pick(): an unknown typed word is an error and the list comes back
    reset_pick; FK_SEL=(typed:z index:2); FK_LINES=(zzz); pick
    has "error shown" "$FK_OUT" "Error [UNKNOWN_COMMAND]"
    check "list came back" c "$PICK_VALUE"
}
t_SL20() {  # pick(): b, q and Esc act at once, with no prompt line
    reset_pick; FK_SEL=(back); pick; check "back" back "$PICK_KIND"
    reset_pick; FK_SEL=(quit); pick; check "quit" quit "$PICK_KIND"
    check "no typed line was opened" 0 "$FK_PREFILLS"
}
t_SL21() {  # pick(): without a selector (pipes) the numbered list works as before
    reset_pick; IO_SELECT=""; FK_LINES=(2); pick
    check "typed number" b "$PICK_VALUE"
    has "list printed" "$FK_OUT" "  1) alpha"
    reset_pick; IO_SELECT=""; FK_LINES=(gamma); pick; check "typed name" c "$PICK_VALUE"
}
t_X2() {    # lines never wider than the terminal; short terminals shrink the window; erase count
    local l max=0 i
    reset_sel; SEL_OPTS=("a label that is much longer than the terminal is wide" b c d)
    FK_W=20; fk_size; sel_window_rows; sel_draw 0 0
    for l in "${SEL_LINES[@]}"; do (( ${#l} > max )) && max=${#l}; done
    check "no line wider than 19" 1 "$(( max <= 19 ))"; max=0
    has "long label ends with an ellipsis" "${SEL_LINES[1]}" "…"
    reset_sel; SEL_OPTS=(); for i in {0..14}; do SEL_OPTS+=("o$i"); done
    FK_H=8; fk_size; sel_window_rows; check "window shrinks to 5 rows" 5 "$SEL_ROWS"
    reset_sel; run down enter
    has "erase moves up by the drawn line count" "$FK_OUT" $'\e[6A\e[J'
}
t_X3() {    # raw terminal bytes become keys (arrows, Esc, Home/End, PgUp/PgDn, Ctrl-C/D, UTF-8)
    local -a B=($'\e[A' $'\e[B' $'\e[H' $'\eOF' $'\e[5~' $'\e[6~' $'\e' $'\x03' $'\x04' $'\r' $'\e[3~')
    local -a W=(up down home end pgup pgdn esc ctrl-c ctrl-d enter ignore)
    local i
    for i in "${!B[@]}"; do sel_parse_bytes "${B[i]}"; check "bytes → ${W[i]}" "${W[i]}" "$KEY"; done
    sel_parse_bytes "é"; check "utf-8 key" char "$KEY"; check "utf-8 char" "é" "$KEY_CHAR"
}

RAN=0
for n in SL1 SL2 SL3 SL4 SL5 SL6 SL7 SL8 SL9 SL10 SL11 SL12 SL13 SL14 SL15 SL16 SL17 SL18 SL19 SL20 SL21 X2 X3; do
    CUR=$n; "t_$n"; RAN=$((RAN + 1))
done
printf '%d selector tests (SL1–SL21 + X2 + X3), %d assertions, %d failed\n' "$RAN" "$ASSERTS" "$FAILS"
(( RAN == 23 )) || { echo "expected 23 tests, ran $RAN"; FAILS=$((FAILS + 1)); }
exit $(( FAILS > 0 ))