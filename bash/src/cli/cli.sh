# cli/cli.sh — main menu, one-shot mode and cli_main (the only layer, with tools.sh, that does I/O).

cli_usage() {
    cat <<'EOF'
Arithmos — Bash edition (Release 1)

Usage:
  arithmos                          interactive menu
  arithmos std "<expression>"       one calculation        (also: standard)
  arithmos prog <command>           one programmer command (also: programmer)
  arithmos convert <value> <from> <to>
  arithmos list [category]
  arithmos --help

Exit status: 0 success, 1 the line produced an Error [CODE], 2 bad usage.
Results go to stdout; Error [CODE] lines and bad-usage text go to stderr.
EOF
}

# cli_init — pick selector or numbered lists, set up colours and the terminal traps.
cli_init() {
    AR_FANCY=0
    if term_is_real; then AR_FANCY=1; io_use_real; else io_use_plain; fi
    style_init
    trap 'term_raw_off' EXIT                    # never leave the terminal raw
    trap 'term_raw_off; printf "\n"; exit 0' INT   # Ctrl-C = end of input: clean exit, new line
    trap 'term_raw_off; exit 143' TERM HUP
    trap 'term_cleanup' EXIT                          # never leave the terminal raw or the cursor hidden
    trap 'term_cleanup; printf "\n"; exit 0' INT      # Ctrl-C = end of input: clean exit, new line
    trap 'term_cleanup; exit 143' TERM HUP
}

# cli_menu — the main menu loop.
cli_menu() {
    local rc=0
    while :; do
        pick_reset
        PK_TITLE="Arithmos 1.0 — Core CLI"; PK_BACK=0; PK_QUIT=1
        PK_HELP=$'Pick a tool with the arrow keys or by typing its number or name.\n  quit  leave Arithmos'
        PK_VAL=(std prog conv exit)
        PK_LAB=("Standard Calculator" "Programmer Calculator" "Unit Converter" "Exit")
        PK_ALT=(standard programmer converter exit)
        PK_NUM=(1 2 3 0)
        pick
        case $PICK_KIND in quit|eof|back) return 0 ;; esac
        case $PICK_VALUE in
            std)  $IO_WRITE "Standard Calculator: type an expression. help for commands, back to return."$'\n'
                  tool_loop "standard> " calc_eval "$STD_HELP"; rc=$? ;;
            prog) $IO_WRITE "Programmer Calculator: 64-bit integers. help for commands, back to return."$'\n'
                  tool_loop "programmer> " pr_exec "$PROG_HELP"; rc=$? ;;
            conv) tool_converter; rc=$? ;;
            exit) return 0 ;;
        esac
        (( rc == 1 )) && return 0               # quit or end of input
    done
}

# cli_oneshot COMMAND ARGS… — one calculation. Exit 0 / 1 (Error [CODE]) / 2 (bad usage).
cli_oneshot() {
    local cmd=${1,,} status
    shift
    case $cmd in
        -h|--help|help) cli_usage; return 0 ;;
        std|standard)    (( $# )) || { cli_usage >&2; return 2; }; calc_eval "$*"; status=$? ;;
        prog|programmer) (( $# )) || { cli_usage >&2; return 2; }; pr_exec "$*"; status=$? ;;
        convert)         (( $# )) || { cli_usage >&2; return 2; }; conv_exec "convert $*"; status=$? ;;
        list)            conv_exec "list $*"; status=$? ;;
        *)               cli_usage >&2; return 2 ;;
    esac
    if (( status == 0 )); then
        printf '%s\n' "$AR_OUT"
        return 0
    fi
    printf 'Error [%s]: %s\n' "$AR_CODE" "$AR_MSG" >&2
    return 1
}

cli_main() {
    cli_init
    if (( $# == 0 )); then cli_menu; return 0; fi
    cli_oneshot "$@"
}