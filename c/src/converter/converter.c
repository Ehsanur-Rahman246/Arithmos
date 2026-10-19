#include "converter/converter.h"
#include "converter/units.h"

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_WORDS 16

int conv_category_count(void) { return CONV_CATEGORY_COUNT; }

const ConvCategory *conv_category(int index)
{
    if (index < 0 || index >= CONV_CATEGORY_COUNT) return NULL;
    return &CONV_CATEGORIES[index];
}

int conv_find_unit(const char *symbol, int *category_index, int *unit_index)
{
    int c, u;
    for (c = 0; c < CONV_CATEGORY_COUNT; c++) {
        for (u = 0; u < CONV_CATEGORIES[c].unit_count; u++) {
            if (!ar_strcasecmp(CONV_CATEGORIES[c].units[u].symbol, symbol)) {
                *category_index = c;
                *unit_index = u;
                return 0;
            }
        }
    }
    return -1;
}

/* ---------- small string builder ---------- */

typedef struct {
    char *buf;
    size_t cap, len;
} Sb;

static void sb_add(Sb *sb, const char *s)
{
    size_t l = strlen(s);
    if (sb->cap == 0) return;
    if (sb->len + l + 1 > sb->cap) l = sb->cap > sb->len + 1 ? sb->cap - sb->len - 1 : 0;
    memcpy(sb->buf + sb->len, s, l);
    sb->len += l;
    sb->buf[sb->len] = '\0';
}

/* ---------- value parsing (plain decimal only) ---------- */

static int parse_value(const char *s, double *out, ArError *err)
{
    const char *p = s;
    int digits = 0;
    if (*p == '+' || *p == '-') p++;
    while (*p >= '0' && *p <= '9') { p++; digits++; }
    if (*p == '.') {
        p++;
        while (*p >= '0' && *p <= '9') { p++; digits++; }
    }
    if (digits == 0 || *p != '\0')
        return ar_error_set(err, AR_INVALID_NUMBER, "'%s' is not a number", s);
    *out = strtod(s, NULL);
    if (isinf(*out)) return ar_error_set(err, AR_OVERFLOW, "That number is too large");
    return 0;
}

/* ---------- temperature (formula-based, via Celsius) ---------- */

static double to_celsius(char sym, double v)
{
    if (sym == 'f') return (v - 32.0) * 5.0 / 9.0;
    if (sym == 'k') return v - 273.15;
    return v;
}

static double from_celsius(char sym, double c)
{
    if (sym == 'f') return c * 9.0 / 5.0 + 32.0;
    if (sym == 'k') return c + 273.15;
    return c;
}

static int below_absolute_zero(char sym, double v)
{
    if (sym == 'c') return v < -273.15;
    if (sym == 'f') return v < -459.67;
    return v < 0.0; /* kelvin */
}

static double convert_one(const ConvCategory *cat, const ConvUnit *from, const ConvUnit *to, double v)
{
    if (cat->is_temperature) {
        if (from == to) return v;
        return from_celsius(to->symbol[0], to_celsius(from->symbol[0], v));
    }
    return v * from->factor / to->factor; /* value -> base -> target */
}

/* ---------- convert ---------- */

int conv_convert(const char *value_text, const char *from, const char *to,
                 char *out, size_t cap, ArError *err)
{
    double v = 0.0;
    int fc, fu, tc, tu;
    const ConvCategory *cat;
    const ConvUnit *fromu;
    char num[64];

    if (cap) out[0] = '\0';
    if (parse_value(value_text, &v, err)) return -1;
    if (conv_find_unit(from, &fc, &fu))
        return ar_error_set(err, AR_UNKNOWN_UNIT, "'%s' is not a known unit. Try: list", from);
    cat = &CONV_CATEGORIES[fc];
    fromu = &cat->units[fu];

    if (!ar_strcasecmp(to, "all")) {
        Sb sb;
        int u;
        sb.buf = out;
        sb.cap = cap;
        sb.len = 0;
        if (cat->is_temperature && below_absolute_zero(fromu->symbol[0], v))
            return ar_error_set(err, AR_BELOW_ABSOLUTE_ZERO, "That is below absolute zero");
        for (u = 0; u < cat->unit_count; u++) {
            double r = convert_one(cat, fromu, &cat->units[u], v);
            if (isinf(r) || isnan(r)) {
                if (cap) out[0] = '\0';
                return ar_error_set(err, AR_OVERFLOW, "Result is too large to represent");
            }
            if (ar_format_number(r, num, sizeof num, err)) {
                if (cap) out[0] = '\0';
                return -1;
            }
            if (u) sb_add(&sb, "\n");
            sb_add(&sb, cat->units[u].symbol);
            sb_add(&sb, ": ");
            sb_add(&sb, num);
        }
        return 0;
    }

    if (conv_find_unit(to, &tc, &tu))
        return ar_error_set(err, AR_UNKNOWN_UNIT, "'%s' is not a known unit. Try: list", to);
    if (tc != fc)
        return ar_error_set(err, AR_INCOMPATIBLE_UNITS, "Cannot convert %s to %s",
                            CONV_CATEGORIES[fc].name, CONV_CATEGORIES[tc].name);
    if (cat->is_temperature && below_absolute_zero(fromu->symbol[0], v))
        return ar_error_set(err, AR_BELOW_ABSOLUTE_ZERO, "That is below absolute zero");

    {
        double r = convert_one(cat, fromu, &cat->units[tu], v);
        if (isinf(r) || isnan(r))
            return ar_error_set(err, AR_OVERFLOW, "Result is too large to represent");
        return ar_format_number(r, out, cap, err);
    }
}

/* ---------- one-line commands ---------- */

static int do_list(char **words, int n, char *out, size_t cap, ArError *err)
{
    Sb sb;
    int i;
    sb.buf = out;
    sb.cap = cap;
    sb.len = 0;
    if (cap) out[0] = '\0';
    if (n > 2) return ar_error_set(err, AR_UNKNOWN_COMMAND, "Use: list  or  list <category>");
    if (n == 1) {
        for (i = 0; i < CONV_CATEGORY_COUNT; i++) {
            if (i) sb_add(&sb, ", ");
            sb_add(&sb, CONV_CATEGORIES[i].name);
        }
        return 0;
    }
    for (i = 0; i < CONV_CATEGORY_COUNT; i++) {
        if (!ar_strcasecmp(CONV_CATEGORIES[i].name, words[1])) {
            int u;
            for (u = 0; u < CONV_CATEGORIES[i].unit_count; u++) {
                if (u) sb_add(&sb, ", ");
                sb_add(&sb, CONV_CATEGORIES[i].units[u].symbol);
            }
            return 0;
        }
    }
    return ar_error_set(err, AR_UNKNOWN_COMMAND, "'%s' is not a category. Try: list", words[1]);
}

int conv_run_line(const char *line, char *out, size_t cap, ArError *err)
{
    char copy[1024];
    char *words[MAX_WORDS + 1];
    int n = 0;
    char *p;

    if (cap) out[0] = '\0';
    if (strlen(line) >= sizeof copy)
        return ar_error_set(err, AR_UNKNOWN_COMMAND, "Not a command. Try: convert 100 cm in");
    snprintf(copy, sizeof copy, "%s", line);

    p = copy;
    while (*p) {
        while (*p && isspace((unsigned char)*p)) p++;
        if (!*p) break;
        if (n >= MAX_WORDS) { n = MAX_WORDS + 1; break; }
        words[n++] = p;
        while (*p && !isspace((unsigned char)*p)) p++;
        if (*p) *p++ = '\0';
    }

    if (n == 0) return ar_error_set(err, AR_UNKNOWN_COMMAND, "Type a value, e.g. 100");
    if (!ar_strcasecmp(words[0], "list")) return do_list(words, n, out, cap, err);
    if (!ar_strcasecmp(words[0], "convert")) {
        if (n != 4)
            return ar_error_set(err, AR_UNKNOWN_COMMAND, "Use: convert <value> <from> <to>");
        return conv_convert(words[1], words[2], words[3], out, cap, err);
    }
    if (n == 3) return conv_convert(words[0], words[1], words[2], out, cap, err);
    return ar_error_set(err, AR_UNKNOWN_COMMAND, "Not a command. Try: convert 100 cm in");
}
