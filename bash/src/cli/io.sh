# cli/io.sh — the one small "io object" every screen talks to (ARCHITECTURE: CLI screens).
# The io object is a set of function NAMES, so tests can swap in fakes:
#   IO_WRITE    TEXT          print text (no newline added)
#   IO_READLINE PROMPT        read a line into LINE; returns 1 at end of input
#   IO_PREFILL  PROMPT TEXT   like IO_READLINE but with TEXT already typed (real terminal only)
#   IO_SELECT                 the arrow-key selector; EMPTY means "use numbered lists"

AR_FANCY=0          # 1 on a real terminal (selector, colours, line editing)
LINE=""
IO_WRITE=io_write; IO_READLINE=io_readline; IO_PREFILL=""; IO_SELECT=""

io_write() { printf '%s' "$1"; }

# io_readline PROMPT — a whole line into LINE. At end of input a newline is printed so the
# shell prompt starts on a fresh line, and 1 is returned. A last line without "\n" still counts.
io_readline() {
    LINE=""
    if (( AR_FANCY )); then
        IFS= read -r -e -p "$1" LINE || { [[ -n $LINE ]] || { printf '\n'; return 1; }; }
    else
        printf '%s' "$1"
        IFS= read -r LINE || { [[ -n $LINE ]] || { printf '\n'; return 1; }; }
    fi
    return 0
}

io_use_plain() {
    IO_WRITE=io_write; IO_READLINE=io_readline; IO_PREFILL=""; IO_SELECT=""
}

io_use_real() {
    IO_WRITE=term_write; IO_READLINE=io_readline; IO_PREFILL=term_prefill
    IO_SELECT=term_select
    SEL_KEYFN=term_key; SEL_OUTFN=term_write; SEL_SIZEFN=term_size
}