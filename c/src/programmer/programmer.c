#include "programmer/programmer.h"

#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define MAX_WORDS 16
#define TWO63 ((uint64_t)1 << 63)

/* ---------- 64-bit helpers (native int64_t / uint64_t) ---------- */

/* Reinterpret a 64-bit pattern as signed without implementation-defined casts. */
static int64_t u2i(uint64_t u)
{
    if (u <= (uint64_t)INT64_MAX) return (int64_t)u;
    return (int64_t)(u - TWO63) + INT64_MIN;
}

static uint64_t i2u(int64_t v) { return (uint64_t)v; }

/* ---------- bases ---------- */

static int base_from_name(const char *name)
{
    if (!ar_strcasecmp(name, "bin")) return 2;
    if (!ar_strcasecmp(name, "oct")) return 8;
    if (!ar_strcasecmp(name, "dec")) return 10;
    if (!ar_strcasecmp(name, "hex")) return 16;
    return 0;
}

static const char *base_name(int base)
{
    switch (base) {
    case 2: return "bin";
    case 8: return "oct";
    case 16: return "hex";
    default: return "dec";
    }
}

static int bad_base(ArError *err, const char *input)
{
    return ar_error_set(err, AR_INVALID_BASE, "'%s' is not a base. Use bin, oct, dec or hex", input);
}

/* ---------- literal parsing (spec 4.3) ---------- */

static int digit_value(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    c = (char)tolower((unsigned char)c);
    if (c >= 'a' && c <= 'z') return c - 'a' + 10;
    return -1;
}

static int parse_literal(const char *text, int default_base, int64_t *out, ArError *err)
{
    const char *p = text, *q;
    int neg = 0, base = default_base;
    uint64_t mag = 0;
    int overflow = 0;

    if (*p == '-') { neg = 1; p++; }
    if (p[0] == '0' && p[1]) { /* a prefix beats the input base */
        switch (tolower((unsigned char)p[1])) {
        case 'b': base = 2; p += 2; break;
        case 'o': base = 8; p += 2; break;
        case 'd': base = 10; p += 2; break;
        case 'x': base = 16; p += 2; break;
        default: break;
        }
    }
    if (*p == '\0')
        return ar_error_set(err, AR_INVALID_NUMBER, "'%s' is not a number", text);
    for (q = p; *q; q++) {
        if (!isalnum((unsigned char)*q))
            return ar_error_set(err, AR_INVALID_NUMBER, "'%s' is not a number", text);
    }
    for (q = p; *q; q++) {
        if (digit_value(*q) >= base)
            return ar_error_set(err, AR_INVALID_DIGIT, "'%c' is not a %s digit",
                                toupper((unsigned char)*q), base_name(base));
    }
    for (q = p; *q; q++) {
        uint64_t d = (uint64_t)digit_value(*q);
        if (mag > (UINT64_MAX - d) / (uint64_t)base) { overflow = 1; break; }
        mag = mag * (uint64_t)base + d;
    }

    if (overflow) {
        if (neg || base == 10)
            return ar_error_set(err, AR_OUT_OF_RANGE, "That number does not fit in 64 bits");
        return ar_error_set(err, AR_OUT_OF_RANGE, "That number needs more than 64 bits");
    }
    if (neg) {
        if (mag > TWO63)
            return ar_error_set(err, AR_OUT_OF_RANGE, "That number does not fit in 64 bits");
        *out = mag == TWO63 ? INT64_MIN : -(int64_t)mag;
    } else if (base == 10) {
        if (mag > (uint64_t)INT64_MAX)
            return ar_error_set(err, AR_OUT_OF_RANGE, "That number does not fit in 64 bits");
        *out = (int64_t)mag;
    } else {
        *out = u2i(mag); /* raw bit pattern reinterpreted as signed */
    }
    return 0;
}

/* The shift count is always a plain decimal number from 0 to 63. */
static int parse_shift_count(const char *text, unsigned *out, ArError *err)
{
    unsigned n = 0;
    const char *p = text;
    if (*p == '\0') goto bad;
    for (; *p; p++) {
        if (*p < '0' || *p > '9') goto bad;
        n = n * 10 + (unsigned)(*p - '0');
        if (n > 63) goto bad;
    }
    *out = n;
    return 0;
bad:
    return ar_error_set(err, AR_INVALID_SHIFT, "A shift count must be a whole number from 0 to 63");
}

/* ---------- output (spec 4.4) ---------- */

static void fmt_unsigned(uint64_t u, unsigned base, char *out)
{
    char tmp[72];
    int n = 0, i;
    if (u == 0) tmp[n++] = '0';
    while (u) {
        tmp[n++] = "0123456789ABCDEF"[u % base];
        u /= base;
    }
    for (i = 0; i < n; i++) out[i] = tmp[n - 1 - i];
    out[n] = '\0';
}

static void fill_value(ProgResult *res, int64_t v)
{
    res->kind = PROG_RESULT_VALUE;
    res->text[0] = '\0';
    fmt_unsigned(i2u(v), 16, res->hex);
    snprintf(res->dec, sizeof res->dec, "%lld", (long long)v);
    fmt_unsigned(i2u(v), 8, res->oct);
    fmt_unsigned(i2u(v), 2, res->bin);
}

static void fill_text(ProgResult *res, const char *text)
{
    res->kind = PROG_RESULT_TEXT;
    snprintf(res->text, sizeof res->text, "%s", text);
}

/* ---------- operations ---------- */

static int64_t arith_shift_right(int64_t v, unsigned n)
{
    if (v >= 0) return v >> n;
    return ~((~v) >> n); /* sign-extending, without relying on >> of negatives */
}

static int do_convert(const char *value, const char *from, const char *to,
                      ProgResult *res, ArError *err)
{
    int fb = base_from_name(from), tb = base_from_name(to);
    int64_t v;
    char buf[80];
    if (!fb) return bad_base(err, from);
    if (!tb) return bad_base(err, to);
    if (parse_literal(value, fb, &v, err)) return -1;
    if (tb == 10) snprintf(buf, sizeof buf, "%lld", (long long)v);
    else fmt_unsigned(i2u(v), (unsigned)tb, buf);
    fill_text(res, buf);
    return 0;
}

static int do_binary(ProgSession *s, const char *a, const char *op, const char *b,
                     ProgResult *res, ArError *err)
{
    int64_t x, y = 0;
    unsigned n = 0;
    int is_shift = !strcmp(op, "<<") || !strcmp(op, ">>") || !strcmp(op, ">>>");
    uint64_t r;

    if (parse_literal(a, s->input_base, &x, err)) return -1;
    if (is_shift) {
        if (parse_shift_count(b, &n, err)) return -1;
    } else if (parse_literal(b, s->input_base, &y, err)) {
        return -1;
    }

    if (!strcmp(op, "<<")) r = i2u(x) << n;
    else if (!strcmp(op, ">>")) r = i2u(arith_shift_right(x, n));
    else if (!strcmp(op, ">>>")) r = i2u(x) >> n;
    else if (!ar_strcasecmp(op, "and")) r = i2u(x) & i2u(y);
    else if (!ar_strcasecmp(op, "or")) r = i2u(x) | i2u(y);
    else r = i2u(x) ^ i2u(y); /* xor */
    fill_value(res, u2i(r));
    return 0;
}

static int is_operator(const char *w)
{
    return !ar_strcasecmp(w, "and") || !ar_strcasecmp(w, "or") || !ar_strcasecmp(w, "xor") ||
           !strcmp(w, "<<") || !strcmp(w, ">>") || !strcmp(w, ">>>");
}

/* ---------- command dispatch ---------- */

void prog_session_init(ProgSession *s) { s->input_base = 10; }

int prog_execute(ProgSession *s, const char *line, ProgResult *res, ArError *err)
{
    char copy[1024];
    char *words[MAX_WORDS + 1];
    int n = 0;
    char *p;
    int64_t v;

    if (strlen(line) >= sizeof copy)
        return ar_error_set(err, AR_UNKNOWN_COMMAND, "Not a command. Try help");
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

    if (n == 0)
        return ar_error_set(err, AR_UNKNOWN_COMMAND, "Type a number or a command. Try help");

    if (!ar_strcasecmp(words[0], "base")) {
        int b;
        if (n != 2) return ar_error_set(err, AR_INVALID_BASE, "Use: base bin | oct | dec | hex");
        b = base_from_name(words[1]);
        if (!b) return bad_base(err, words[1]);
        s->input_base = b;
        {
            char msg[48];
            snprintf(msg, sizeof msg, "Input base: %s", base_name(b));
            fill_text(res, msg);
        }
        return 0;
    }

    if (!ar_strcasecmp(words[0], "convert")) {
        if (n != 4)
            return ar_error_set(err, AR_UNKNOWN_COMMAND, "Use: convert <value> <from> <to>");
        return do_convert(words[1], words[2], words[3], res, err);
    }

    /* `255 dec hex`: three words whose last two are base names. */
    if (n == 3 && base_from_name(words[1]) && base_from_name(words[2]))
        return do_convert(words[0], words[1], words[2], res, err);

    if (!ar_strcasecmp(words[0], "not")) {
        if (n != 2) return ar_error_set(err, AR_UNKNOWN_COMMAND, "Use: NOT <value>");
        if (parse_literal(words[1], s->input_base, &v, err)) return -1;
        fill_value(res, u2i(~i2u(v)));
        return 0;
    }

    if (n == 1) {
        if (parse_literal(words[0], s->input_base, &v, err)) return -1;
        fill_value(res, v);
        return 0;
    }

    /* The operator is always the middle word (amendment R11). */
    if (n == 3 && is_operator(words[1]))
        return do_binary(s, words[0], words[1], words[2], res, err);

    return ar_error_set(err, AR_UNKNOWN_COMMAND, "Not a command. Try help");
}
