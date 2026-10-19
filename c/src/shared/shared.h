/* shared: error codes (spec 2.2), string helpers, number formatting (spec 2.3). */
#ifndef ARITHMOS_SHARED_H
#define ARITHMOS_SHARED_H

#include <stddef.h>

typedef enum {
    AR_OK = 0,
    AR_INVALID_EXPRESSION,
    AR_INVALID_NUMBER,
    AR_DIV_BY_ZERO,
    AR_DOMAIN_ERROR,
    AR_UNDEFINED,
    AR_OVERFLOW,
    AR_INVALID_DIGIT,
    AR_INVALID_BASE,
    AR_OUT_OF_RANGE,
    AR_INVALID_SHIFT,
    AR_UNKNOWN_UNIT,
    AR_INCOMPATIBLE_UNITS,
    AR_BELOW_ABSOLUTE_ZERO,
    AR_UNKNOWN_COMMAND
} ArCode;

typedef struct {
    ArCode code;
    char message[160];
} ArError;

#if defined(__GNUC__)
#define AR_PRINTF(a, b) __attribute__((format(printf, a, b)))
#else
#define AR_PRINTF(a, b)
#endif

/* Name of a code, e.g. "DIV_BY_ZERO". */
const char *ar_code_name(ArCode code);

/* Fill an error (printf-style message). Always returns -1 so callers can
 * write `return ar_error_set(...)`. */
int ar_error_set(ArError *err, ArCode code, const char *fmt, ...) AR_PRINTF(3, 4);

/* Case-insensitive (ASCII) string compare, like strcasecmp. */
int ar_strcasecmp(const char *a, const char *b);

/* Trim leading/trailing whitespace in place. */
void ar_trim(char *s);

/* Format a double with the spec 2.3 rules: 12 significant digits, half away
 * from zero, trailing zeros trimmed, plain notation for 1e-6 <= |x| < 1e15,
 * otherwise <mantissa>e<sign><exponent>. Returns 0 on success; -1 on
 * infinity (OVERFLOW) or NaN. */
int ar_format_number(double x, char *out, size_t cap, ArError *err);

#endif
