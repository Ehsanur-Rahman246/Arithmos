#!/usr/bin/env bash
# test/cli_session.sh — whole sessions piped into bin/arithmos (numbered-list mode),
# plus one-shot mode and its exit codes. Checks lines and codes, not exact transcripts.

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
BIN=$PWD/bin/arithmos
export ARITHMOS_PLAIN=1 NO_COLOR=1

PASS=0; FAIL=0
line_in() {   # NAME TEXT LINE — LINE must appear as a whole line of TEXT
    if [[ $'\n'$2$'\n' == *$'\n'"$3"$'\n'* ]]; then PASS=$((PASS + 1))
    else FAIL=$((FAIL + 1)); printf 'FAIL %s: line [%s] not in:\n%s\n' "$1" "$3" "$2"; fi
}
eq() {        # NAME EXPECTED ACTUAL
    if [[ $2 == "$3" ]]; then PASS=$((PASS + 1))
    else FAIL=$((FAIL + 1)); printf 'FAIL %s: expected [%s] got [%s]\n' "$1" "$2" "$3"; fi
}

# 1. Main menu (spec §2.1) and a clean exit with 0.
out=$(printf '0\n' | "$BIN"); rc=$?
line_in "menu title" "$out" "Arithmos 1.0 — Core CLI"
line_in "menu row 1" "$out" "  1) Standard Calculator"
line_in "menu row 0" "$out" "  0) Exit"
eq "exit 0 returns 0" 0 "$rc"

# 2. Standard session: result, ans, an error that keeps ans.
out=$(printf '1\n25 + 17\nans * 2\n10 / 0\nans\nquit\n' | "$BIN"); rc=$?
line_in "std result" "$out" "standard> 42"
line_in "std ans" "$out" "standard> 84"
[[ $out == *"Error [DIV_BY_ZERO]"* ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "FAIL std error"; }
eq "std quit returns 0" 0 "$rc"

# 3. Programmer session: base, value, back to the menu, exit.
out=$(printf '2\nbase hex\nFF\nback\n0\n' | "$BIN")
line_in "base echo" "$out" "programmer> Input base: hex"
[[ $out == *"DEC: 255"* ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "FAIL prog value"; }

# 4. Guided converter: category → from → to → value (spec §5.1 example).
# The picker prompt "> " has no newline when input is piped, so it shares a line
# with the next prompt. Check that the result appears inside the output instead.
out=$(printf '3\nlength\nm\nyd\n100\nquit\n' | "$BIN")
if [[ $out == *"converter (m → yd)> 100 m = 109.361329834 yd"* ]]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1)); printf 'FAIL guided flow: result not found in:\n%s\n' "$out"
fi

# 5. End of input exits cleanly; garbage never crashes.
printf '' | "$BIN" >/dev/null; eq "EOF at the menu" 0 "$?"
out=$(printf '1\n)(\n@@\nquit\n' | "$BIN"); rc=$?
[[ $out == *"Error [INVALID_EXPRESSION]"* ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "FAIL garbage"; }
eq "garbage session exit" 0 "$rc"

# 6. One-shot mode (R31): stdout results, stderr errors, exit 0 / 1 / 2.
out=$("$BIN" std "20% of 150");               eq "one-shot std" 30 "$out"
out=$("$BIN" STD "1+1");                      eq "command word is case-insensitive" 2 "$out"
out=$("$BIN" standard "2 * 3");               eq "long form" 6 "$out"
out=$("$BIN" prog 0xFF AND 0x0F);             [[ $out == *"DEC: 15"* ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "FAIL one-shot prog"; }
out=$("$BIN" convert 100 cm in);              eq "one-shot convert" 39.3700787402 "$out"
out=$("$BIN" list length);                    eq "one-shot list" "pm, ang, nm, um, mm, cm, m, km, in, ft, yd, mi, nmi, au, ly" "$out"
out=$("$BIN" std "10 / 0" 2>/dev/null); rc=$?;  eq "error: nothing on stdout" "" "$out"; eq "error: exit 1" 1 "$rc"
err=$("$BIN" std "10 / 0" 2>&1 >/dev/null);     [[ $err == "Error [DIV_BY_ZERO]"* ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "FAIL stderr text"; }
"$BIN" bogus >/dev/null 2>&1;                 eq "unknown command: exit 2" 2 "$?"
"$BIN" std >/dev/null 2>&1;                   eq "missing expression: exit 2" 2 "$?"
"$BIN" --help >/dev/null 2>&1;                eq "--help: exit 0" 0 "$?"

printf '%d checks passed, %d failed\n' "$PASS" "$FAIL"
exit $(( FAIL > 0 ))