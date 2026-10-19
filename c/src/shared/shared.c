#include "shared/shared.h"

#include <ctype.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *const CODE_NAMES[] = {
    "OK",
    "INVALID_EXPRESSION",
    "INVALID_NUMBER",
    "DIV_BY_ZERO",
    "DOMAIN_ERROR",
    "UNDEFINED",
    "OVERFLOW",
    "INVALID_DIGIT",
    "INVALID_BASE",
    "OUT_OF_RANGE",
    "INVALID_SHIFT",
    "UNKNOWN_UNIT",
    "INCOMPATIBLE_UNITS",
    "BELOW_ABSOLUTE_ZERO",
    "UNKNOWN_COMMAND"
};

const char *ar_code_name(ArCode code)
{
    int i = (int)code;
    if (i < 0 || i > (int)AR_UNKNOWN_COMMAND) return "UNKNOWN";
    return CODE_NAMES[i];
}

int ar_error_set(ArError *err, ArCode code, const char *fmt, ...)
{
    va_list ap;
    if (!err) return -1;
    err->code = code;
    va_start(ap, fmt);
    vsnprintf(err->message, sizeof err->message, fmt, ap);
    va_end(ap);
    return -1;
}

int ar_strcasecmp(const char *a, const char *b)
{
    while (*a && *b) {
        int ca = tolower((unsigned char)*a);
        int cb = tolower((unsigned char)*b);
        if (ca != cb) return ca - cb;
        a++;
        b++;
    }
    return tolower((unsigned char)*a) - tolower((unsigned char)*b);
}

void ar_trim(char *s)
{
    size_t len = strlen(s), start = 0;
    while (s[start] && isspace((unsigned char)s[start])) start++;
    while (len > start && isspace((unsigned char)s[len - 1])) len--;
    memmove(s, s + start, len - start);
    s[len - start] = '\0';
}

/*
 * Half-away-from-zero rounding needs the exact binary value. printf with many
 * digits prints the exact decimal expansion of a double (glibc, musl, UCRT), so
 * we print 35 significant digits and round that digit string ourselves: digit
 * 13 >= '5' means the remainder is at least one half, so round up in magnitude.
 */
int ar_format_number(double x, char *out, size_t cap, ArError *err)
{
    char buf[96], digits[48], text[96];
    int nd = 0, exp10, n, i, pos = 0;
    const char *p;

    if (isnan(x)) return ar_error_set(err, AR_INVALID_EXPRESSION, "Result is not a number");
    if (isinf(x)) return ar_error_set(err, AR_OVERFLOW, "Result is too large to represent");
    if (x == 0.0) {
        snprintf(out, cap, "0");
        return 0;
    }

    snprintf(buf, sizeof buf, "%.34e", fabs(x));
    p = buf;
    digits[nd++] = *p++;
    if (*p == '.') p++;
    while (*p && *p != 'e') digits[nd++] = *p++;
    exp10 = atoi(p + 1);

    n = 12;
    if (digits[n] >= '5') {
        for (i = n - 1; i >= 0; i--) {
            if (digits[i] == '9') {
                digits[i] = '0';
            } else {
                digits[i]++;
                break;
            }
        }
        if (i < 0) { /* carried out of the top digit: 999... -> 1000... */
            digits[0] = '1';
            for (i = 1; i < n; i++) digits[i] = '0';
            exp10++;
        }
    }
    while (n > 1 && digits[n - 1] == '0') n--;

    if (x < 0) text[pos++] = '-';
    if (exp10 >= -6 && exp10 < 15) {
        if (exp10 >= 0) {
            int intlen = exp10 + 1;
            for (i = 0; i < intlen; i++) text[pos++] = i < n ? digits[i] : '0';
            if (n > intlen) {
                text[pos++] = '.';
                for (i = intlen; i < n; i++) text[pos++] = digits[i];
            }
        } else {
            text[pos++] = '0';
            text[pos++] = '.';
            for (i = 0; i < -exp10 - 1; i++) text[pos++] = '0';
            for (i = 0; i < n; i++) text[pos++] = digits[i];
        }
    } else {
        text[pos++] = digits[0];
        if (n > 1) {
            text[pos++] = '.';
            for (i = 1; i < n; i++) text[pos++] = digits[i];
        }
        pos += snprintf(text + pos, sizeof text - (size_t)pos, "e%c%d",
                        exp10 < 0 ? '-' : '+', abs(exp10));
    }
    text[pos] = '\0';
    snprintf(out, cap, "%s", text);
    return 0;
}
