# Arithmos — Bash edition. Requires Bash 4+ and awk.
.PHONY: run test lint

run: ; -bash bin/arithmos

# 175 shared cases + Bash extras, selector tests SL1-SL21 + X2 + X3, scripted CLI sessions.
test: ; bash test/run_cases.sh ../docs/release-1-cases.json && bash test/run_selector.sh && bash test/cli_session.sh

# Optional: needs shellcheck installed.
lint: ; shellcheck -x bin/arithmos src/*.sh src/*/*.sh test/*.sh