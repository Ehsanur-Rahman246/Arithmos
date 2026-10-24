# shared/errors.sh — the error model (spec §2.2).
#
# Engines never print. On failure they call ar_fail CODE MESSAGE, which records
# the error in AR_CODE / AR_MSG and returns 1. On success they return 0 and leave
# their result in AR_OUT. Only the cli layer turns these into text.
# Error codes are the 14 in spec §2.2; tests assert the code, never the message.

AR_CODE=""     # last error code
AR_MSG=""      # last error message
AR_OUT=""      # last successful result (may be several lines)
R=""           # general-purpose "return register" for small helpers

# ar_fail CODE MESSAGE — record an error and return 1.
ar_fail() {
    AR_CODE=$1
    AR_MSG=$2
    return 1
}

# ar_trim TEXT — strip leading and trailing whitespace; result in R.
ar_trim() {
    R=$1
    R=${R#"${R%%[![:space:]]*}"}
    R=${R%"${R##*[![:space:]]}"}
}