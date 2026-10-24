# cli/terminal.sh — the real terminal: detection, raw keys, size, typed line.
# Raw mode is on only while the selector is on screen. It is restored after every
# selector run and by the EXIT/INT/TERM traps (cli_init), so the terminal is never left raw.

TERM_SAVED=""

# A "real terminal": stdin and stdout are terminals, TERM is not dumb, ARITHMOS_PLAIN is not 1.
term_is_real() { [[ -t 0 && -t 1 && ${TERM:-dumb} != dumb && ${ARITHMOS_PLAIN-} != 1 ]]; }

term_write() { printf '%s' "$1"; }

# term_size — SEL_W / SEL_H from stty (measured on every redraw); 80x24 if unknown.
term_size() {
    local r c
    if read -r r c < <(stty size 2>/dev/null) && [[ $r =~ ^[0-9]+$ && $c =~ ^[0-9]+$ ]] && (( r > 0 && c > 0 )); then
        SEL_H=$r; SEL_W=$c
    else
        SEL_H=24; SEL_W=80
    fi
}

term_raw_on()  { TERM_SAVED=$(stty -g 2>/dev/null); stty -icanon -echo -isig min 1 time 0 2>/dev/null; }
term_raw_off() { if [[ -n $TERM_SAVED ]]; then stty "$TERM_SAVED" 2>/dev/null; TERM_SAVED=""; fi; }

# term_key — read one key (an escape sequence counts as one key) and parse it.
# ESC alone is told apart from ESC [ … by a 50 ms wait for the next byte.
term_key() {
    local c r1 r2 seq i
    KEY=ignore; KEY_CHAR=""
    IFS= read -r -s -n 1 -d '' c || return 1
    seq=$c
    if [[ $c == $'\e' ]]; then
        if IFS= read -r -s -n 1 -t 0.05 -d '' r1; then
            seq+=$r1
            if [[ $r1 == '[' ]]; then                       # CSI: read up to the final byte
                for (( i = 0; i < 6; i++ )); do
                    IFS= read -r -s -n 1 -t 0.05 -d '' r2 || break
                    seq+=$r2
                    [[ $r2 == [[:alpha:]~] ]] && break
                done
            elif [[ $r1 == O ]]; then                       # SS3: exactly one more byte
                IFS= read -r -s -n 1 -t 0.05 -d '' r2 && seq+=$r2
            fi
        fi
    fi
    sel_parse_bytes "$seq"
    return 0
}

# term_select — IO_SELECT on a real terminal: raw on, run the selector, raw off.
term_select() { term_raw_on; sel_loop; term_raw_off; }

# term_prefill PROMPT TEXT — the typed line after a printable key opened it:
# the prompt shows the key and readline edits the rest. 1 at end of input.
term_prefill() {
    LINE=""
    IFS= read -r -e -p "$1" -i "$2" LINE || { [[ -n $LINE ]] || { printf '\n'; return 1; }; }
    return 0
}

# term_cleanup — restore everything the selector may have changed:
# the terminal mode and the (possibly hidden) cursor. Safe to call twice.
term_cleanup() {
    term_raw_off
    if (( AR_FANCY )); then printf '\e[?25h'; fi
}