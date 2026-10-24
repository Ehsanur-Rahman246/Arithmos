# src/autoload.sh — one plain list of `source` lines, in dependency order
# (shared → engines → cli). Arrows point down only: engines never source cli/.
# Must be sourced from the top level (not from inside a function) so that
# `declare -A` tables become global.

: "${AR_SRC:?AR_SRC must point at the src folder}"

export LC_NUMERIC=C            # awk and printf must use "." as the decimal point
AR_AWK=${AR_AWK:-awk}          # override to pick gawk / mawk explicitly

for AR_F in \
    shared/errors \
    calculator/calculator \
    programmer/int64 programmer/parse programmer/programmer \
    converter/units converter/converter \
    cli/style cli/io cli/selector cli/terminal cli/pick cli/tools cli/cli
do
    source "$AR_SRC/$AR_F.sh"
done
unset AR_F