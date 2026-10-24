# calculator/calculator.sh — Standard Calculator session around the awk engine.
# Pure logic: no reading or printing. The session holds `ans`, which changes only
# after a fully successful evaluation (spec §3.1).

CALC_ANS=0          # raw (full precision) previous result

calc_reset() { CALC_ANS=0; }

# calc_eval EXPRESSION — 0 + AR_OUT on success; 1 + AR_CODE/AR_MSG on error.
calc_eval() {
    local out status a b
    out=$(AR_EXPR=$1 AR_ANS=$CALC_ANS "$AR_AWK" \
            -f "$AR_SRC/shared/format_number.awk" \
            -f "$AR_SRC/calculator/calculator.awk" 2>/dev/null)
    IFS=$'\t' read -r status a b <<<"$out"
    case $status in
        OK)  AR_OUT=$a; CALC_ANS=$b; return 0 ;;
        ERR) ar_fail "$a" "$b"; return 1 ;;
        *)   ar_fail INTERNAL "the calculator engine produced no result"; return 1 ;;
    esac
}