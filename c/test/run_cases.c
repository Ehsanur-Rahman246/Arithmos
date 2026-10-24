/*
 * Test runner: loads the shared cases (docs/release-1-cases.json), runs them
 * against the three engines, then runs the C-specific extra tests (number
 * formatting boundaries, unit-table sanity, garbage input never crashes).
 * Asserts results and error codes only, never prompt text.
 */
#include "calculator/calculator.h"
#include "converter/converter.h"
#include "programmer/programmer.h"
#include "shared/shared.h"

#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* ---------- minimal JSON reader (objects, arrays, strings, scalars) ---------- */

typedef enum { J_NULL, J_STR, J_ARR, J_OBJ, J_SCALAR } JType;

typedef struct JV {
    JType type;
    char *str;          /* J_STR / J_SCALAR text */
    struct JV **items;  /* J_ARR items, J_OBJ values */
    char **keys;        /* J_OBJ keys */
    size_t n;
} JV;

static const char *jp;

static void j_ws(void) { while (*jp == ' ' || *jp == '\n' || *jp == '\r' || *jp == '\t') jp++; }

static void j_die(const char *msg)
{
    fprintf(stderr, "JSON error: %s near: %.30s\n", msg, jp);
    exit(2);
}

static char *j_string(void)
{
    size_t cap = 64, len = 0;
    char *s = (char *)malloc(cap);
    if (*jp != '"') j_die("expected string");
    jp++;
    while (*jp && *jp != '"') {
        unsigned c = (unsigned char)*jp++;
        if (c == '\\') {
            c = (unsigned char)*jp++;
            switch (c) {
            case 'n': c = '\n'; break;
            case 't': c = '\t'; break;
            case 'r': c = '\r'; break;
            case 'b': c = '\b'; break;
            case 'f': c = '\f'; break;
            case 'u': {
                char hex[5] = {0};
                memcpy(hex, jp, 4);
                jp += 4;
                c = (unsigned)strtoul(hex, NULL, 16);
                if (c >= 0x800) {
                    if (len + 4 >= cap) s = (char *)realloc(s, cap *= 2);
                    s[len++] = (char)(0xE0 | (c >> 12));
                    s[len++] = (char)(0x80 | ((c >> 6) & 0x3F));
                    c = 0x80 | (c & 0x3F);
                } else if (c >= 0x80) {
                    if (len + 4 >= cap) s = (char *)realloc(s, cap *= 2);
                    s[len++] = (char)(0xC0 | (c >> 6));
                    c = 0x80 | (c & 0x3F);
                }
                break;
            }
            default: break; /* \" \\ \/ keep the character */
            }
        }
        if (len + 4 >= cap) s = (char *)realloc(s, cap *= 2);
        s[len++] = (char)c;
    }
    if (*jp != '"') j_die("unterminated string");
    jp++;
    s[len] = '\0';
    return s;
}

static JV *j_value(void)
{
    JV *v = (JV *)calloc(1, sizeof *v);
    j_ws();
    if (*jp == '"') {
        v->type = J_STR;
        v->str = j_string();
    } else if (*jp == '[' || *jp == '{') {
        int obj = *jp == '{';
        char close = obj ? '}' : ']';
        v->type = obj ? J_OBJ : J_ARR;
        jp++;
        j_ws();
        while (*jp != close) {
            if (obj) {
                char *key;
                j_ws();
                key = j_string();
                j_ws();
                if (*jp++ != ':') j_die("expected ':'");
                v->keys = (char **)realloc(v->keys, (v->n + 1) * sizeof *v->keys);
                v->keys[v->n] = key;
            }
            v->items = (JV **)realloc(v->items, (v->n + 1) * sizeof *v->items);
            v->items[v->n++] = j_value();
            j_ws();
            if (*jp == ',') { jp++; j_ws(); }
            else if (*jp != close) j_die("expected ',' or end");
        }
        jp++;
    } else {
        const char *s = jp;
        while (*jp && *jp != ',' && *jp != ']' && *jp != '}' && *jp != ' ' && *jp != '\n') jp++;
        v->type = J_SCALAR;
        v->str = (char *)malloc((size_t)(jp - s) + 1);
        memcpy(v->str, s, (size_t)(jp - s));
        v->str[jp - s] = '\0';
    }
    return v;
}

static const JV *j_get(const JV *o, const char *key)
{
    size_t i;
    if (o->type != J_OBJ) return NULL;
    for (i = 0; i < o->n; i++) if (!strcmp(o->keys[i], key)) return o->items[i];
    return NULL;
}

static const char *j_str(const JV *o, const char *key)
{
    const JV *v = j_get(o, key);
    return v && v->type == J_STR ? v->str : NULL;
}

/* ---------- running a line against a tool ---------- */

typedef struct {
    CalcSession calc;
    ProgSession prog;
} Sessions;

typedef struct {
    int is_err;
    ArCode code;
    char text[4096];
    int is_prog_value;
    ProgResult prog;
} Outcome;

static void run_line(const char *tool, Sessions *ss, const char *line, Outcome *o)
{
    ArError err;
    int rc;
    memset(o, 0, sizeof *o);
    if (!strcmp(tool, "standard")) {
        rc = calc_run(&ss->calc, line, o->text, sizeof o->text, &err);
    } else if (!strcmp(tool, "programmer")) {
        rc = prog_execute(&ss->prog, line, &o->prog, &err);
        if (rc == 0) {
            o->is_prog_value = o->prog.kind == PROG_RESULT_VALUE;
            if (!o->is_prog_value) snprintf(o->text, sizeof o->text, "%s", o->prog.text);
        }
    } else {
        rc = conv_run_line(line, o->text, sizeof o->text, &err);
    }
    if (rc != 0) {
        o->is_err = 1;
        o->code = err.code;
    }
}

static int contains_line(const char *text, const char *line)
{
    size_t n = strlen(line);
    const char *p = text;
    while (*p) {
        const char *e = strchr(p, '\n');
        size_t len = e ? (size_t)(e - p) : strlen(p);
        if (len == n && !strncmp(p, line, n)) return 1;
        if (!e) break;
        p = e + 1;
    }
    return 0;
}

/* spec: a case or a step object with exactly one of expected / expectedContains / error */
static int check(const JV *spec, const Outcome *o, char *why, size_t whylen)
{
    const char *err = j_str(spec, "error");
    const JV *exp = j_get(spec, "expected");
    const JV *cont = j_get(spec, "expectedContains");

    if (err) {
        if (!o->is_err) { snprintf(why, whylen, "expected error %s, got result '%.150s'", err, o->is_prog_value ? o->prog.dec : o->text); return 0; }
        if (strcmp(err, ar_code_name(o->code))) { snprintf(why, whylen, "expected error %s, got %s", err, ar_code_name(o->code)); return 0; }
        return 1;
    }
    if (o->is_err) { snprintf(why, whylen, "unexpected error %s", ar_code_name(o->code)); return 0; }
    if (exp && exp->type == J_STR) {
        if (o->is_prog_value) { snprintf(why, whylen, "expected text '%.150s', got a value", exp->str); return 0; }
        if (strcmp(exp->str, o->text)) { snprintf(why, whylen, "expected '%.150s', got '%.150s'", exp->str, o->text); return 0; }
        return 1;
    }
    if (exp && exp->type == J_OBJ) {
        size_t i;
        if (!o->is_prog_value) { snprintf(why, whylen, "expected a value table, got '%.150s'", o->text); return 0; }
        for (i = 0; i < exp->n; i++) {
            const char *k = exp->keys[i], *want = exp->items[i]->str, *got = NULL;
            if (!strcmp(k, "HEX")) got = o->prog.hex;
            else if (!strcmp(k, "DEC")) got = o->prog.dec;
            else if (!strcmp(k, "OCT")) got = o->prog.oct;
            else if (!strcmp(k, "BIN")) got = o->prog.bin;
            if (!got || strcmp(want, got)) {
                snprintf(why, whylen, "%s: expected '%s', got '%s'", k, want, got ? got : "?");
                return 0;
            }
        }
        return 1;
    }
    if (cont && cont->type == J_ARR) {
        size_t i;
        for (i = 0; i < cont->n; i++) {
            if (!contains_line(o->text, cont->items[i]->str)) {
                snprintf(why, whylen, "missing line '%.150s' in '%.150s'", cont->items[i]->str, o->text);
                return 0;
            }
        }
        return 1;
    }
    snprintf(why, whylen, "case has no outcome");
    return 0;
}

/* ---------- shared cases ---------- */

static int failures = 0, passes = 0;

static void fail(const char *id, const char *why)
{
    failures++;
    printf("FAIL %s: %s\n", id, why);
}

static int run_shared(const char *path)
{
    FILE *f = fopen(path, "rb");
    long size;
    char *text;
    JV *root;
    size_t i, k;
    size_t counts[3] = {0, 0, 0};

    if (!f) { fprintf(stderr, "cannot open %s\n", path); return 2; }
    fseek(f, 0, SEEK_END);
    size = ftell(f);
    fseek(f, 0, SEEK_SET);
    text = (char *)malloc((size_t)size + 1);
    if (fread(text, 1, (size_t)size, f) != (size_t)size) { fprintf(stderr, "read error\n"); return 2; }
    text[size] = '\0';
    fclose(f);
    jp = text;
    root = j_value();

    for (i = 0; i < root->n; i++) {
        const JV *c = root->items[i];
        const char *id = j_str(c, "id"), *tool = j_str(c, "tool");
        const JV *steps = j_get(c, "steps"), *setup = j_get(c, "setup");
        Sessions ss;
        Outcome o;
        char why[512];
        int ok = 1;

        calc_session_init(&ss.calc);
        prog_session_init(&ss.prog);
        if (!strcmp(tool, "standard")) counts[0]++;
        else if (!strcmp(tool, "programmer")) counts[1]++;
        else counts[2]++;

        if (setup) {
            for (k = 0; k < setup->n; k++) run_line(tool, &ss, setup->items[k]->str, &o);
        }
        if (steps) {
            for (k = 0; k < steps->n && ok; k++) {
                run_line(tool, &ss, j_str(steps->items[k], "input"), &o);
                ok = check(steps->items[k], &o, why, sizeof why);
            }
        } else {
            run_line(tool, &ss, j_str(c, "input"), &o);
            ok = check(c, &o, why, sizeof why);
        }
        if (ok) passes++;
        else fail(id, why);
    }
    printf("shared cases: %d passed, %d failed (standard %zu, programmer %zu, converter %zu; total %zu)\n",
           passes, failures, counts[0], counts[1], counts[2], root->n);
    if (root->n != 175 || counts[0] != 33 || counts[1] != 32 || counts[2] != 110) {
        printf("FAIL: expected 175 cases (33 / 32 / 110)\n");
        failures++;
    }
    return 0;
}

/* ---------- extra tests ---------- */

static void expect_fmt(double x, const char *want)
{
    char out[64];
    ArError err;
    if (ar_format_number(x, out, sizeof out, &err) || strcmp(out, want)) {
        char msg[160];
        snprintf(msg, sizeof msg, "format(%.17g): expected '%s', got '%s'", x, want, out);
        fail("FMT", msg);
    } else passes++;
}

static void extra_formatting(void)
{
    ArError err;
    char out[64];
    expect_fmt(0.1 + 0.2, "0.3");
    expect_fmt(-0.0, "0");
    expect_fmt(0.0, "0");
    expect_fmt(1e15, "1e+15");
    expect_fmt(999999999999999.0, "1e+15");       /* rounds up into scientific */
    expect_fmt(99999999999.0, "99999999999");
    expect_fmt(123456789012.5, "123456789013");   /* exact tie: away from zero */
    expect_fmt(-123456789012.5, "-123456789013");
    expect_fmt(100000000000.5, "100000000001");   /* R10 */
    expect_fmt(1e-6, "0.000001");
    expect_fmt(9.9999999999996e-7, "0.000001");   /* rounds up into plain notation */
    expect_fmt(9.9999e-7, "9.9999e-7");
    expect_fmt(2e-7, "2e-7");
    expect_fmt(1.5e20, "1.5e+20");
    expect_fmt(-1.5e20, "-1.5e+20");
    expect_fmt(1.0 / 3.0, "0.333333333333");
    expect_fmt(2.0 / 3.0, "0.666666666667");
    expect_fmt(123456.789, "123456.789");
    expect_fmt(1.7976931348623157e308, "1.79769313486e+308");
    expect_fmt(5e-324, "4.94065645841e-324");
    if (ar_format_number(INFINITY, out, sizeof out, &err) == 0 || err.code != AR_OVERFLOW) fail("FMT", "inf must be OVERFLOW");
    else passes++;
    if (ar_format_number(NAN, out, sizeof out, &err) == 0) fail("FMT", "NaN must be an error");
    else passes++;
}

static void extra_units(void)
{
    int c, u, c2, u2;
    for (c = 0; c < conv_category_count(); c++) {
        const ConvCategory *cat = conv_category(c);
        for (u = 0; u < cat->unit_count; u++) {
            if (conv_find_unit(cat->units[u].symbol, &c2, &u2) || c2 != c || u2 != u) {
                char msg[96];
                snprintf(msg, sizeof msg, "symbol '%s' is not unique", cat->units[u].symbol);
                fail("UNITS", msg);
            } else passes++;
        }
    }
    if (conv_category_count() != 12) fail("UNITS", "expected 12 categories");
    else passes++;
}

/* Deterministic pseudo-random bytes; nothing may crash, and every call must
 * return either success or a real error code. */
static void extra_garbage(void)
{
    static const char alphabet[] =
        "0123456789 .+-*/^()%<>!=,;:'\"\\ofnsqrtabsANDORXNOTbasehexdecbinoctconvertlistkgmcf\t\xff\x01";
    uint64_t seed = UINT64_C(12345);
    int iter;
    Sessions ss;
    calc_session_init(&ss.calc);
    prog_session_init(&ss.prog);
    for (iter = 0; iter < 20000; iter++) {
        char line[96];
        char out[4096];
        ProgResult pr;
        ArError err;
        double d;
        int len, i;
        seed = seed * UINT64_C(6364136223846793005)
            + UINT64_C(1442695040888963407);
        len = (int)((seed >> 33) % 40);
        for (i = 0; i < len; i++) {
            seed = seed * UINT64_C(6364136223846793005)
            + UINT64_C(1442695040888963407);
            line[i] = alphabet[(seed >> 33) % (sizeof alphabet - 1)];
        }
        line[len] = '\0';
        if (calc_evaluate(&ss.calc, line, &d, &err) == 0 && (isnan(d) || isinf(d))) fail("GARBAGE", "calculator returned NaN/inf");
        if (prog_execute(&ss.prog, line, &pr, &err) != 0 && (err.code == AR_OK)) fail("GARBAGE", "programmer error without code");
        if (conv_run_line(line, out, sizeof out, &err) != 0 && (err.code == AR_OK)) fail("GARBAGE", "converter error without code");
    }
    passes++;
    /* Deep nesting and very long input must produce an error, not a crash. */
    {
        char *deep = (char *)malloc(5000);
        double d;
        ArError err;
        memset(deep, '(', 3000);
        strcpy(deep + 3000, "1");
        if (calc_evaluate(&ss.calc, deep, &d, &err) == 0) fail("GARBAGE", "3000 open parens must fail");
        else passes++;
        memset(deep, '-', 3000);
        deep[3000] = '1';
        deep[3001] = '\0';
        if (calc_evaluate(&ss.calc, deep, &d, &err) == 0) fail("GARBAGE", "3000 unary minus must fail");
        else passes++;
        free(deep);
    }
}

static void extra_cases(void)
{
    /* Amendments R1-R20 that are settled in both reference editions. */
    static const struct { const char *tool, *line, *want; } t[] = {
        {"standard", "200 + (10%)", "200.1"},
        {"standard", "200 + 5 * 10%", "200.5"},
        {"standard", "2^50%", "1.41421356237"},
        {"standard", "50%%", "0.005"},
        {"standard", "5 of 10", "50"},
        {"standard", "ANS", "0"},
        {"standard", "10^-400", "0"},
        {"standard", "1e5", "!INVALID_EXPRESSION"},
        {"standard", ".", "!INVALID_EXPRESSION"},
        {"standard", "5.5.5", "!INVALID_EXPRESSION"},
        {"standard", "5.", "5"},
        {"standard", ".5", "0.5"},
        {"programmer", "NOT 0xFF", ""},
        {"programmer", "1 << 0x3", "!INVALID_SHIFT"},
        {"programmer", "1 << 2.5", "!INVALID_SHIFT"},
        {"programmer", "convert FFFFFFFFFFFFFFFF hex dec", "-1"},
        {"programmer", "1.5", "!INVALID_NUMBER"},
        {"programmer", "-", "!INVALID_NUMBER"},
        {"programmer", "FF!", "!INVALID_NUMBER"},
        {"converter", "convert 1e3 m cm", "!INVALID_NUMBER"},
        {"converter", "convert 5.5.5 m cm", "!INVALID_NUMBER"},
        {"converter", "convert 1 m xyz", "!UNKNOWN_UNIT"},
        {"converter", "list foo", "!UNKNOWN_COMMAND"},
        {"converter", "list length extra", "!UNKNOWN_COMMAND"},
        {"converter", "convert 0 k all", ""},
        {"converter", "convert -273.15 c all", ""},
        {"converter", "convert -459.67 f all", ""},
        {"converter", "convert 1 m cm cm", "!UNKNOWN_COMMAND"},
        {"converter", "foo bar", "!UNKNOWN_COMMAND"}
    };
    size_t i;
    for (i = 0; i < sizeof t / sizeof t[0]; i++) {
        Sessions ss;
        Outcome o;
        calc_session_init(&ss.calc);
        prog_session_init(&ss.prog);
        run_line(t[i].tool, &ss, t[i].line, &o);
        if (t[i].want[0] == '!') {
            if (!o.is_err || strcmp(ar_code_name(o.code), t[i].want + 1)) {
                char msg[160];
                snprintf(msg, sizeof msg, "'%s': expected %s", t[i].line, t[i].want + 1);
                fail("EXTRA", msg);
            } else passes++;
        } else if (t[i].want[0] == '\0') {
            if (o.is_err) fail("EXTRA", t[i].line);
            else passes++;
        } else if (o.is_err || strcmp(o.text, t[i].want)) {
            char msg[520];
            snprintf(msg, sizeof msg, "'%.150s': expected '%.150s', got '%.150s'", t[i].line, t[i].want, o.text);
            fail("EXTRA", msg);
        } else passes++;
    }
    /* A failed expression leaves ans unchanged (also S33), and ans is case-insensitive. */
    {
        CalcSession s;
        char out[64];
        ArError err;
        calc_session_init(&s);
        calc_run(&s, "7", out, sizeof out, &err);
        calc_run(&s, "1/0", out, sizeof out, &err);
        calc_run(&s, "AnS + 1", out, sizeof out, &err);
        if (strcmp(out, "8")) fail("EXTRA", "ans after an error");
        else passes++;
    }
    /* Parse errors beat evaluation errors: nothing is evaluated for a bad line. */
    {
        CalcSession s;
        double d;
        ArError err;
        calc_session_init(&s);
        if (calc_evaluate(&s, "1/0 +", &d, &err) == 0 || err.code != AR_INVALID_EXPRESSION)
            fail("EXTRA", "1/0 + must be INVALID_EXPRESSION");
        else passes++;
    }
}

int main(int argc, char **argv)
{
    const char *path = argc > 1 ? argv[1] : "../docs/release-1-cases.json";
    int rc = run_shared(path);
    if (rc) return rc;
    extra_formatting();
    extra_units();
    extra_garbage();
    extra_cases();
    printf("total: %d passed, %d failed\n", passes, failures);
    return failures ? 1 : 0;
}
