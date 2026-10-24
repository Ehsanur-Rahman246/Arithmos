#!/usr/bin/env bash
# test/run_cases.sh — loads ../docs/release-1-cases.json and runs every shared case
# against the engines, then runs the Bash extras (formatting boundaries, settled
# amendments, garbage input). Asserts RESULTS and ERROR CODES, never prompt text.
# Usage: bash test/run_cases.sh [path/to/cases.json]

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
AR_ROOT=$PWD; AR_SRC=$AR_ROOT/src
source "$AR_SRC/autoload.sh"
CASES=${1:-../docs/release-1-cases.json}
[[ -r $CASES ]] || { echo "cannot read $CASES"; exit 2; }

PASS=0; FAIL=0; SHARED=0
fail() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }

# ---- JSON → tab-separated records -------------------------------------------------
# The case file is pretty-printed with one value per line, so a tiny awk state machine
# is enough (no jq needed). Records: CASE ID TOOL STEP IN SETUP EXP EXPK CONTAINS ERR.
json_records() {
    "$AR_AWK" '
    function unq(s) { gsub(/\\"/, "\"", s); gsub(/\\\\/, "\\", s); return s }
    function strval(v) { if (substr(v, 1, 1) == "\"") v = substr(v, 2, length(v) - 2); return unq(v) }
    function kv(line,    p, k, v) {
        p = index(line, "\":"); k = substr(line, 1, p - 1); sub(/^[[:space:]]*"/, "", k)
        v = substr(line, p + 2); sub(/^[[:space:]]*/, "", v); sub(/,[[:space:]]*$/, "", v)
        KEY = k; VAL = v
    }
    /^[[:space:]]*\{[[:space:]]*$/ { print (steps ? "STEP" : "CASE"); next }
    mode == "expobj" {
        if ($0 ~ /^[[:space:]]*\}/) { mode = ""; next }
        kv($0); printf "EXPK\t%s\t%s\n", KEY, strval(VAL); next
    }
    mode == "setup" || mode == "contains" {
        if ($0 ~ /^[[:space:]]*\]/) { mode = ""; next }
        s = $0; sub(/^[[:space:]]*/, "", s); sub(/,[[:space:]]*$/, "", s)
        printf "%s\t%s\n", (mode == "setup" ? "SETUP" : "CONTAINS"), strval(s); next
    }
    /^[[:space:]]*\],?[[:space:]]*$/ { steps = 0; next }
    /^[[:space:]]*"[^"]+": / {
        kv($0)
        if      (KEY == "id")               printf "ID\t%s\n",  strval(VAL)
        else if (KEY == "tool")             printf "TOOL\t%s\n", strval(VAL)
        else if (KEY == "input")            printf "IN\t%s\n",  strval(VAL)
        else if (KEY == "error")            printf "ERR\t%s\n", strval(VAL)
        else if (KEY == "expected")         { if (VAL == "{") mode = "expobj"; else printf "EXP\t%s\n", strval(VAL) }
        else if (KEY == "setup")            mode = "setup"
        else if (KEY == "expectedContains") mode = "contains"
        else if (KEY == "steps")            steps = 1
        next
    }' "$1"
}

run_engine() {   # TOOL LINE
    case $1 in
        standard)   calc_eval "$2" ;;
        programmer) pr_exec "$2" ;;
        converter)  conv_exec "$2" ;;
    esac
}

has_line() { [[ $'\n'$1$'\n' == *$'\n'"$2"$'\n'* ]]; }

# ---- running one case or step -----------------------------------------------------
declare -A E_OBJ
E_KIND=""; E_STR=""; E_ERR=""; E_CONT=(); IN=""; HAVE=0; CID=""; TOOL=""

clear_outcome() { E_KIND=""; E_STR=""; E_ERR=""; E_CONT=(); E_OBJ=(); IN=""; HAVE=0; }

# flush — run the pending input (if any) and check it against the recorded outcome.
flush() {
    (( HAVE )) || return 0
    local st k ok=1 line
    run_engine "$TOOL" "$IN"; st=$?
    if [[ -n $E_ERR ]]; then                       # expected an error CODE (never the message)
        { (( st != 0 )) && [[ $AR_CODE == "$E_ERR" ]]; } || ok=0
    elif (( st != 0 )); then
        ok=0                                       # an unexpected error
    elif [[ $E_KIND == str ]]; then                # expected is a string
        [[ $AR_OUT == "$E_STR" ]] || ok=0
    elif [[ $E_KIND == obj ]]; then                # expected is an object of HEX/DEC/OCT/BIN
        for k in "${!E_OBJ[@]}"; do has_line "$AR_OUT" "$k: ${E_OBJ[$k]}" || ok=0; done
    fi
    for line in "${E_CONT[@]}"; do                 # expectedContains: every line must appear
        has_line "$AR_OUT" "$line" || ok=0
    done
    if (( ok )); then PASS=$((PASS + 1))
    else fail "$CID: '$IN' -> status $st, out [$AR_OUT], code [$AR_CODE]"; fi
    clear_outcome
}

# ---- walk the records ---------------------------------------------------------------
# JSON order inside a case is id, tool, input, setup, expected. SETUP lines run at once
# (same session) while the input is deferred to flush(), so setup always runs first.
clear_outcome
while IFS=$'\t' read -r tag a b; do
    case $tag in
        CASE)     flush; clear_outcome; SHARED=$((SHARED + 1)) ;;
        ID)       CID=$a ;;
        TOOL)     TOOL=$a; calc_reset; PR_BASE=dec ;;   # fresh session for each case
        STEP)     flush; clear_outcome ;;               # steps share one session
        IN)       IN=$a; HAVE=1 ;;
        SETUP)    run_engine "$TOOL" "$a" ;;
        EXP)      E_KIND=str; E_STR=$a ;;
        EXPK)     E_KIND=obj; E_OBJ[$a]=$b ;;
        CONTAINS) E_CONT+=("$a") ;;
        ERR)      E_ERR=$a ;;
    esac
done < <(json_records "$CASES")
flush

if (( SHARED != 175 )); then fail "expected 175 shared cases, found $SHARED"; fi

# ---- Bash extras: settled amendments, formatting boundaries, garbage input ---------
EXTRA=0
fresh() { calc_reset; PR_BASE=dec; }
x_ok() {    # TOOL LINE EXPECTED-STRING
    EXTRA=$((EXTRA + 1)); run_engine "$1" "$2"; local st=$?
    if (( st == 0 )) && [[ $AR_OUT == "$3" ]]; then PASS=$((PASS + 1))
    else fail "extra $1 '$2': got [$AR_OUT] code [$AR_CODE], want [$3]"; fi
}
x_err() {   # TOOL LINE CODE
    EXTRA=$((EXTRA + 1)); run_engine "$1" "$2"; local st=$?
    if (( st != 0 )) && [[ $AR_CODE == "$3" ]]; then PASS=$((PASS + 1))
    else fail "extra $1 '$2': status $st code [$AR_CODE], want error $3"; fi
}
x_has() {   # TOOL LINE LINE-THAT-MUST-APPEAR
    EXTRA=$((EXTRA + 1)); run_engine "$1" "$2"; local st=$?
    if (( st == 0 )) && has_line "$AR_OUT" "$3"; then PASS=$((PASS + 1))
    else fail "extra $1 '$2': got [$AR_OUT] code [$AR_CODE], want line [$3]"; fi
}

fresh
# Standard: percent rules R1–R4, of (R5), ans (R6), tokenizer (R7, R8), underflow (R9), rounding (R10).
x_ok  standard "200 + (10%)" 200.1
x_ok  standard "200 + 5 * 10%" 200.5
x_ok  standard "2^50%" 1.41421356237
x_ok  standard "50%%" 0.005
x_ok  standard "5 of 10" 50
fresh; x_ok  standard "ANS" 0
x_err standard "1e5" INVALID_EXPRESSION
x_err standard "." INVALID_EXPRESSION
x_err standard "5.5.5" INVALID_EXPRESSION
x_ok  standard "10^-400" 0
x_ok  standard "100000000000.5" 100000000001
x_ok  standard "999999999999.5" 1000000000000
x_ok  standard "1 / 1000000" 0.000001
x_ok  standard "123456789012345" 123456789012000
x_ok  standard "-0" 0
x_ok  standard "(-2)^2" 4
x_ok  standard "abs(-3) + sqrt(9)" 6
x_ok  standard "10 / 4 / 5" 0.5
x_err standard "(-8)^(1/3)" DOMAIN_ERROR
x_err standard "1 / (2 - 2)" DIV_BY_ZERO
x_err standard "sqrt 4" INVALID_EXPRESSION
x_err standard "of 5" INVALID_EXPRESSION
x_err standard "2 \$ 3" INVALID_EXPRESSION
x_err standard "" INVALID_EXPRESSION

# Programmer: R12–R15, R29, R30, hex-mode keywords (R11), range edges.
fresh
x_has programmer "NOT 0xFF" "DEC: -256"
x_has programmer "NOT -1" "DEC: 0"
x_err programmer "1 << 0x3" INVALID_SHIFT
x_err programmer "1 << 2.5" INVALID_SHIFT
x_has programmer "-0x80" "DEC: -128"
x_ok  programmer "convert FFFFFFFFFFFFFFFF hex dec" "-1"
x_has programmer "1<<3" "DEC: 8"
x_has programmer "-1 >> 63" "DEC: -1"
x_has programmer "-1 >>> 63" "DEC: 1"
x_has programmer "-1 >>> 0" "DEC: -1"
x_has programmer "1 << 0" "DEC: 1"
x_has programmer "0b101" "DEC: 5"
x_has programmer "0o17" "DEC: 15"
x_has programmer "0d12" "DEC: 12"
x_err programmer "0x" INVALID_DIGIT
x_err programmer "1.5" INVALID_NUMBER
x_err programmer "-" INVALID_NUMBER
x_err programmer "FF!" INVALID_NUMBER
x_has programmer "-9223372036854775808" "DEC: -9223372036854775808"
x_err programmer "-9223372036854775809" OUT_OF_RANGE
x_has programmer "-0x8000000000000000" "DEC: -9223372036854775808"
x_err programmer "-0x8000000000000001" OUT_OF_RANGE
x_ok  programmer "base hex" "Input base: hex"
x_has programmer "A AND F" "HEX: A"
x_has programmer "DEC" "DEC: 3564"
x_has programmer "0B" "DEC: 11"
PR_BASE=dec
x_err programmer "BASE" INVALID_BASE
x_err programmer "base" INVALID_BASE
x_err programmer "5 AND" UNKNOWN_COMMAND
x_err programmer "1 foo 2" UNKNOWN_COMMAND
x_err programmer "255 dec foo" UNKNOWN_COMMAND
x_err programmer "convert 255 dec foo" INVALID_BASE
x_err programmer "" UNKNOWN_COMMAND

# Converter: R16, R17, R19, R20, glob-safety of unit lookup, list output.
big=$(printf '9%.0s' {1..400})
x_err converter "convert 1e3 m cm" INVALID_NUMBER
x_err converter "list foo" UNKNOWN_COMMAND
x_ok  converter "convert 1 c k" 274.15
x_ok  converter "convert -273.15 c k" 0
x_err converter "convert 1 kg" UNKNOWN_COMMAND
x_ok  converter "100 cm in" 39.3700787402
x_ok  converter "list" "length, mass, area, volume, time, speed, digital, energy, power, pressure, angle, temperature"
x_ok  converter "list length" "pm, ang, nm, um, mm, cm, m, km, in, ft, yd, mi, nmi, au, ly"
x_err converter "convert 1 * m" UNKNOWN_UNIT
x_err converter "convert $big m cm" OVERFLOW
x_has converter "convert 0 k all" "k: 0"
x_has converter "convert -273.15 c all" "c: -273.15"
x_err converter "convert -273.16 c all" BELOW_ABSOLUTE_ZERO
x_err converter "" UNKNOWN_COMMAND

# Garbage input must never crash or hang: it is an error code or a result, nothing else.
for g in ')(' '@@@' '🙂' "'" '"' '\' '$(whoami)' '`id`' ';;' '*' '~' '1 2 3 4 5' "$(printf 'x%.0s' {1..1000})"; do
    for t in standard programmer converter; do
        AR_CODE=""; run_engine "$t" "$g"; st=$?; EXTRA=$((EXTRA + 1))
        if (( st == 0 )) || [[ -n $AR_CODE ]]; then PASS=$((PASS + 1)); else fail "garbage $t [$g]"; fi
    done
done

printf '\n%d shared cases, %d extras: %d checks passed, %d failed\n' "$SHARED" "$EXTRA" "$PASS" "$FAIL"
exit $(( FAIL > 0 ))