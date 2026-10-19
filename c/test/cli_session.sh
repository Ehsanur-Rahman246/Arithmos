#!/bin/sh
# Scripted CLI sessions: pipe a whole session into the binary and check the output.
# Usage: sh test/cli_session.sh ./arithmos
BIN=${1:-./arithmos}
fails=0

# check <name> <expected-substring> <input...>  (input is printf-formatted)
check() {
    name=$1; want=$2; input=$3
    got=$(printf "$input" | "$BIN" 2>&1)
    case "$got" in
        *"$want"*) echo "ok   $name" ;;
        *) echo "FAIL $name: wanted '$want'"; echo "$got" | sed 's/^/     | /'; fails=$((fails + 1)) ;;
    esac
}

check "standard + ans"   "84"                          '1\n25 + 17\nans * 2\nquit\n'
check "div by zero"      "Error [DIV_BY_ZERO]"         '1\n10 / 0\nquit\n'
check "ans survives err" "7"                           '1\n7\n10 / 0\nans\nquit\n'
check "blank ignored"    "42"                          '1\n\n   \n25 + 17\nquit\n'
check "help"             "Commands: help, back, quit"  '1\nhelp\nquit\n'
check "question mark"    "Commands: help, back, quit"  '1\n?\nquit\n'
check "back to menu"     "3) Unit Converter"           '1\nback\n0\n'
check "eof exits"        "standard>"                   '1\n1 + 1\n'
check "programmer AND"   "DEC: 1"                      '2\n5 AND 3\nquit\n'
check "programmer base"  "DEC: -255"                   '2\nbase hex\n-FF\nquit\n'
check "programmer conv"  "FF"                          '2\n255 dec hex\nquit\n'
check "bad digit"        "Error [INVALID_DIGIT]"       '2\nconvert 102 bin dec\nquit\n'
check "converter 1-line" "2.54"                        '3\nconvert 1 in cm\nquit\n'
check "converter list"   "length, mass, area"          '3\nlist\nquit\n'
check "guided flow"      "100 m = 109.361329834 yd"    '3\n1\nm\nyd\n100\nquit\n'
check "guided prompt"    "converter (m → yd)>"         '3\n1\nm\nyd\nquit\n'
check "guided back"      "To unit:"                    '3\n1\nm\nyd\nback\nquit\n'
check "list at values"   "length, mass, area"          '3\n1\nm\nyd\nlist\nquit\n'
check "temperature all"  "f: 32"                       '3\n0 c all\nquit\n'
check "pick error"       "Pick one from the list"      '3\nzzz\nquit\n'
check "menu error"       "Pick one from the list"      'nine\n0\n'
check "garbage no crash" "Error [INVALID_EXPRESSION]"  '1\n)(*&^\nquit\n'

# one-shot mode and exit codes
"$BIN" std "20% of 150" | grep -qx 30 && echo "ok   one-shot std" || { echo "FAIL one-shot std"; fails=$((fails + 1)); }
"$BIN" convert 100 cm in | grep -qx 39.3700787402 && echo "ok   one-shot convert" || { echo "FAIL one-shot convert"; fails=$((fails + 1)); }
"$BIN" std "1/0" >/dev/null 2>&1; [ $? -eq 1 ] && echo "ok   exit 1 on error" || { echo "FAIL exit 1"; fails=$((fails + 1)); }
"$BIN" bogus >/dev/null 2>&1; [ $? -eq 2 ] && echo "ok   exit 2 on usage" || { echo "FAIL exit 2"; fails=$((fails + 1)); }
"$BIN" std "1+1" >/dev/null 2>&1; [ $? -eq 0 ] && echo "ok   exit 0" || { echo "FAIL exit 0"; fails=$((fails + 1)); }

[ "$fails" -eq 0 ] && echo "cli sessions: all passed" || { echo "cli sessions: $fails failed"; exit 1; }
