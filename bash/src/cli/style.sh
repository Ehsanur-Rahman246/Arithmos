# cli/style.sh — colours. Plain (empty strings) for pipes, tests and NO_COLOR.
ST_BOLD=""; ST_DIM=""; ST_REV=""; ST_OFF=""

style_init() {
    if (( ${AR_FANCY:-0} )) && [[ -z ${NO_COLOR-} ]]; then
        ST_BOLD=$'\e[1m'; ST_DIM=$'\e[2m'; ST_REV=$'\e[7m'; ST_OFF=$'\e[0m'
    fi
}