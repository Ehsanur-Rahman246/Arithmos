# cli/selector.sh — the arrow-key selector, in the four layers every edition has
# (docs/test-cases.md, SL1–SL21):
#   1. key handling   sel_parse_bytes   raw bytes → KEY            (pure)
#   2. drawing        sel_draw          state → SEL_LINES            (pure)
#   3. loop           sel_loop          draw/read loop over an injectable keyboard and screen
#   4. pick()         see pick.sh
#
# Injectable pieces (function names):
#   SEL_KEYFN   sets KEY (+ KEY_CHAR for printable keys); returns 1 at end of input
#   SEL_OUTFN   TEXT   writes to the screen
#   SEL_SIZEFN  sets SEL_W (columns) and SEL_H (rows); called on EVERY redraw (resizing works)
# Inputs: SEL_TITLE  SEL_OPTS[]  SEL_BACK  SEL_QUIT  SEL_TYPING  SEL_START
# Outputs: SEL_RESULT = index | back | quit | typed | eof,  SEL_INDEX,  SEL_CHAR
# KEY values: up down home end pgup pgdn enter esc ctrl-c ctrl-d char ignore

SEL_TITLE=""; SEL_OPTS=(); SEL_BACK=0; SEL_QUIT=0; SEL_TYPING=0; SEL_START=0
SEL_RESULT=""; SEL_INDEX=0; SEL_CHAR=""; SEL_W=80; SEL_H=24; SEL_ROWS=0
SEL_LINES=(); KEY=""; KEY_CHAR=""

# ---- layer 1: key handling ---------------------------------------------------
# sel_parse_bytes BYTES — one key's raw bytes (an escape sequence is one string).
sel_parse_bytes() {
    local b=$1
    KEY_CHAR=""
    case $b in
        $'\e[A'|$'\eOA')                       KEY=up ;;
        $'\e[B'|$'\eOB')                       KEY=down ;;
        $'\e[H'|$'\eOH'|$'\e[1~'|$'\e[7~')     KEY=home ;;
        $'\e[F'|$'\eOF'|$'\e[4~'|$'\e[8~')     KEY=end ;;
        $'\e[5~')                              KEY=pgup ;;
        $'\e[6~')                              KEY=pgdn ;;
        $'\e')                                 KEY=esc ;;
        $'\e'*)                                KEY=ignore ;;       # unknown escape sequence
        $'\n'|$'\r')                           KEY=enter ;;
        $'\x03')                               KEY=ctrl-c ;;
        $'\x04')                               KEY=ctrl-d ;;
        ''|' '|[[:cntrl:]])                    KEY=ignore ;;       # space and control keys
        *)                                     KEY=char; KEY_CHAR=$b ;;   # printable, incl. UTF-8
    esac
    return 0
}

# ---- layer 2: drawing ----------------------------------------------------------
# sel_fit TEXT — R = TEXT cut to at most SEL_W-1 columns (longer text ends with "…"),
# so one logical line is always one screen line and the cursor-up redraw stays exact.
sel_fit() {
    local max=$(( SEL_W - 1 ))
    (( max < 2 )) && max=2
    if (( ${#1} > max )); then R=${1:0:max-1}…; else R=$1; fi
}

# sel_window_rows — SEL_ROWS = rows shown: at most 10, shrunk so the block (rows + title
# + hint) leaves the cursor line free on the current terminal height.
sel_window_rows() {
    local n=${#SEL_OPTS[@]} r=10 avail=$(( SEL_H - 3 ))
    (( r > n )) && r=$n
    (( avail < 1 )) && avail=1
    (( r > avail )) && r=$avail
    SEL_ROWS=$r
}

# sel_hint — R = hint line listing only the keys that are on offer.
sel_hint() {
    R="↑↓ move · Enter select"
    (( SEL_BACK ))   && R+=" · Esc/b back"
    (( SEL_QUIT ))   && R+=" · q quit"
    (( SEL_TYPING )) && R+=" · or type"
    return 0
}

# sel_draw IDX TOP — SEL_LINES = title, SEL_ROWS rows starting at TOP, hint.
# Colour on (ST_REV set): the selected row is a full reverse-video bar.
# Colour off: the row is only marked with the ❯ pointer.
sel_draw() {
    local idx=$1 top=$2 i end line pad
    SEL_LINES=()
    sel_fit "$SEL_TITLE"; SEL_LINES+=("$ST_BOLD$R$ST_OFF")
    end=$(( top + SEL_ROWS ))
    for (( i = top; i < end; i++ )); do
        if (( i == idx )); then
            sel_fit "❯ ${SEL_OPTS[i]}"; line=$R
            if [[ -n $ST_REV ]]; then
                pad=$(( SEL_W - 1 - ${#line} )); (( pad < 0 )) && pad=0
                printf -v pad '%*s' "$pad" ''
                line="$ST_REV$line$pad$ST_OFF"
            fi
        else
            sel_fit "  ${SEL_OPTS[i]}"; line=$R
        fi
        SEL_LINES+=("$line")
    done
    sel_hint; sel_fit "$R"
    SEL_LINES+=("$ST_DIM$R$ST_OFF")
}

# sel_emit — write SEL_LINES, each terminated by a newline, in a single screen call.
sel_emit() {
    local s="" l
    for l in "${SEL_LINES[@]}"; do s+=$l$'\n'; done
    $SEL_OUTFN "$s"
}

# ---- layer 3: the draw/read loop -----------------------------------------------
# A redraw moves the cursor up by the number of lines drawn and clears to the end of
# the screen. A chosen row leaves "✔ <title>: <label>" behind. The cursor is hidden
# while the selector is up and always restored.
sel_loop() {
    local n=${#SEL_OPTS[@]} idx=${SEL_START:-0} top=0 drawn=0 page k
    SEL_RESULT=""; SEL_INDEX=0; SEL_CHAR=""
    $SEL_OUTFN $'\e[?25l'
    while :; do
        $SEL_SIZEFN
        sel_window_rows
        page=$SEL_ROWS
        (( idx < top )) && top=$idx                          # keep the selection in view
        (( idx >= top + page )) && top=$(( idx - page + 1 ))
        (( top > n - page )) && top=$(( n - page ))
        (( top < 0 )) && top=0
        if (( drawn > 0 )); then printf -v k '\e[%dA\e[J' "$drawn"; $SEL_OUTFN "$k"; fi
        sel_draw "$idx" "$top"
        drawn=${#SEL_LINES[@]}
        sel_emit
        if ! $SEL_KEYFN; then SEL_RESULT=eof; break; fi
        case $KEY in
            up)     idx=$(( (idx + n - 1) % n )) ;;          # wraps
            down)   idx=$(( (idx + 1) % n )) ;;
            home)   idx=0 ;;
            end)    idx=$(( n - 1 )) ;;
            pgup)   idx=$(( idx - page )); (( idx < 0 )) && idx=0 ;;
            pgdn)   idx=$(( idx + page )); (( idx > n - 1 )) && idx=$(( n - 1 )) ;;
            enter)  SEL_RESULT=index; SEL_INDEX=$idx; break ;;
            esc)    if (( SEL_BACK )); then SEL_RESULT=back; break; fi ;;
            ctrl-c|ctrl-d) SEL_RESULT=eof; break ;;
            char)
                # b and q act at once, but only when offered.
                if [[ $KEY_CHAR == b ]] && (( SEL_BACK )); then SEL_RESULT=back; break; fi
                if [[ $KEY_CHAR == q ]] && (( SEL_QUIT )); then SEL_RESULT=quit; break; fi
                # Any other printable key (or an unoffered b/q) opens a typed line.
                if (( SEL_TYPING )); then SEL_RESULT=typed; SEL_CHAR=$KEY_CHAR; break; fi ;;
            *) : ;;                                          # ignore
        esac
    done
    if (( drawn > 0 )); then printf -v k '\e[%dA\e[J' "$drawn"; $SEL_OUTFN "$k"; fi
    if [[ $SEL_RESULT == index ]]; then
        $SEL_OUTFN "✔ $SEL_TITLE: ${SEL_OPTS[SEL_INDEX]}"$'\n'
    fi
    $SEL_OUTFN $'\e[?25h'
    return 0
}