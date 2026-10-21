/*
 * Selector tests SL1-SL21: the same 21 behaviours, with the same numbers and names, as
 * javascript/test/select.test.js and python/tests/test_select.py (docs/test-cases.md).
 * Key handling and drawing are pure; the loop and pick() run over a fake keyboard,
 * a fake screen and scripted lines, so no terminal is needed.
 */
#include "cli/pick.h"
#include "cli/select.h"
#include "shared/shared.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define EXPECTED_TESTS 21

#define CHECK(cond) do { if (!(cond)) { snprintf(why, 160, "line %d: %s", __LINE__, #cond); return 0; } } while (0)

typedef int (*TestFn)(char *why);

static int press(SelState *s, int key, unsigned flags)
{
    int typed = 0;
    return (int)sel_apply_key(s, key, flags, &typed);
}

/* The n-th line (0-based) of a '\n'-separated text. */
static int nth_line(const char *text, int n, char *buf, size_t cap)
{
    const char *p = text;
    while (n-- > 0) {
        p = strchr(p, '\n');
        if (!p) return 0;
        p++;
    }
    {
        const char *e = strchr(p, '\n');
        size_t len = e ? (size_t)(e - p) : strlen(p);
        if (len >= cap) len = cap - 1;
        memcpy(buf, p, len);
        buf[len] = '\0';
    }
    return 1;
}

static int starts_with(const char *s, const char *prefix) { return strncmp(s, prefix, strlen(prefix)) == 0; }
static int ends_with(const char *s, const char *suffix)
{
    size_t a = strlen(s), b = strlen(suffix);
    return a >= b && !strcmp(s + a - b, suffix);
}

/* ---------- keys (pure) ---------- */

static int sl1(char *why)
{
    SelState s;
    sel_state_init(&s, 3, 0);
    press(&s, SEL_KEY_DOWN, 0); CHECK(s.index == 1);
    press(&s, SEL_KEY_DOWN, 0); press(&s, SEL_KEY_DOWN, 0); CHECK(s.index == 0); /* wrapped */
    press(&s, SEL_KEY_UP, 0); CHECK(s.index == 2);
    press(&s, SEL_KEY_HOME, 0); CHECK(s.index == 0);
    press(&s, SEL_KEY_END, 0); CHECK(s.index == 2);
    return 1;
}

static int sl2(char *why)
{
    SelState s;
    const char *labels[18];
    char names[18][8], text[8192];
    int i;
    for (i = 0; i < 18; i++) { snprintf(names[i], sizeof names[i], "u%d", i); labels[i] = names[i]; }
    sel_state_init(&s, 18, 0);
    CHECK(s.size == 10);
    for (i = 0; i < 12; i++) press(&s, SEL_KEY_DOWN, 0);
    CHECK(s.index >= s.offset && s.index < s.offset + s.size);
    press(&s, SEL_KEY_END, 0);
    CHECK(s.offset == 8);
    sel_render(text, sizeof text, "T", labels, &s, 0, 0);
    CHECK(strstr(text, "18 of 18") && strstr(text, "\xe2\x9d\xaf u17"));
    return 1;
}

static int sl3(char *why)
{
    SelState s;
    sel_state_init(&s, 3, 0);
    CHECK(press(&s, SEL_KEY_ENTER, 0) == SEL_CHOSEN);
    CHECK(press(&s, SEL_KEY_ESC, 0) == SEL_CONTINUE);
    CHECK(press(&s, SEL_KEY_ESC, SEL_OFFER_BACK) == SEL_BACK);
    CHECK(press(&s, 'b', SEL_OFFER_BACK) == SEL_BACK);
    CHECK(press(&s, 'q', 0) == SEL_CONTINUE);
    CHECK(press(&s, 'q', SEL_OFFER_QUIT) == SEL_QUIT);
    CHECK(press(&s, 'x', SEL_OFFER_BACK | SEL_OFFER_QUIT) == SEL_CONTINUE);
    return 1;
}

static int sl4(char *why)
{
    SelState s;
    sel_state_init(&s, 3, 0);
    CHECK(press(&s, SEL_KEY_ABORT, 0) == SEL_EOF);
    CHECK(press(&s, SEL_KEY_ABORT, SEL_TYPING | SEL_OFFER_BACK) == SEL_EOF);
    CHECK(press(&s, SEL_KEY_OTHER, SEL_OFFER_BACK | SEL_OFFER_QUIT | SEL_TYPING) == SEL_CONTINUE);
    return 1;
}

static int sl5(char *why)
{
    SelState s;
    int typed = 0;
    sel_state_init(&s, 3, 0);
    CHECK(sel_apply_key(&s, 'x', SEL_TYPING, &typed) == SEL_TYPED && typed == 'x');
    CHECK(sel_apply_key(&s, '1', SEL_TYPING, &typed) == SEL_TYPED && typed == '1');
    return 1;
}

static int sl6(char *why)
{
    SelState s;
    sel_state_init(&s, 3, 0);
    CHECK(press(&s, 'x', 0) == SEL_CONTINUE);
    CHECK(press(&s, '1', SEL_OFFER_BACK | SEL_OFFER_QUIT) == SEL_CONTINUE);
    return 1;
}

static int sl7(char *why)
{
    SelState s;
    unsigned all = SEL_OFFER_BACK | SEL_OFFER_QUIT | SEL_TYPING;
    sel_state_init(&s, 3, 0);
    CHECK(press(&s, SEL_KEY_ESC, all) == SEL_BACK);
    CHECK(press(&s, 'b', all) == SEL_BACK);
    CHECK(press(&s, 'q', all) == SEL_QUIT);
    CHECK(press(&s, SEL_KEY_DOWN, all) == SEL_CONTINUE && s.index == 1);
    CHECK(press(&s, SEL_KEY_ENTER, all) == SEL_CHOSEN);
    CHECK(press(&s, 'b', SEL_TYPING) == SEL_CONTINUE); /* back not offered: b is not a typed key either */
    return 1;
}

static int sl8(char *why)
{
    SelState s;
    sel_state_init(&s, 3, 0);
    CHECK(press(&s, ' ', SEL_TYPING) == SEL_CONTINUE);
    CHECK(press(&s, SEL_KEY_OTHER, SEL_TYPING) == SEL_CONTINUE);
    return 1;
}

/* ---------- drawing (pure) ---------- */

static int sl9(char *why)
{
    SelState s;
    const char *labels[] = {"aa", "bbbb", "c"};
    char text[4096], l1[256], l2[256], l3[256];
    int lines;
    sel_state_init(&s, 3, 1);
    lines = sel_render(text, sizeof text, "Pick", labels, &s, 0, 1);
    nth_line(text, 1, l1, sizeof l1); nth_line(text, 2, l2, sizeof l2); nth_line(text, 3, l3, sizeof l3);
    CHECK(strstr(l2, "\x1b[7m") && strstr(l2, "\xe2\x9d\xaf bbbb"));
    CHECK(!strstr(l1, "\x1b[7m") && !strstr(l3, "\x1b[7m"));
    CHECK(lines == 5); /* title + 3 rows + hint */
    return 1;
}

static int sl10(char *why)
{
    SelState s;
    const char *labels[] = {"aa", "bb"};
    char text[4096], l1[256], l2[256];
    sel_state_init(&s, 2, 0);
    sel_render(text, sizeof text, "Pick", labels, &s, 0, 0);
    nth_line(text, 1, l1, sizeof l1); nth_line(text, 2, l2, sizeof l2);
    CHECK(starts_with(l1, " \xe2\x9d\xaf aa") && starts_with(l2, "   bb"));
    return 1;
}

static void hint_of(unsigned flags, char *out, size_t cap)
{
    SelState s;
    const char *labels[] = {"a", "b"};
    char text[4096];
    int lines;
    sel_state_init(&s, 2, 0);
    lines = sel_render(text, sizeof text, "T", labels, &s, flags, 0);
    nth_line(text, lines - 1, out, cap);
}

static int sl11(char *why)
{
    char h[256];
    hint_of(0, h, sizeof h);
    CHECK(strstr(h, "Enter select") && !strstr(h, "Esc"));
    hint_of(SEL_OFFER_BACK, h, sizeof h);
    CHECK(strstr(h, "Esc back"));
    hint_of(SEL_OFFER_QUIT, h, sizeof h);
    CHECK(strstr(h, "q quit"));
    return 1;
}

static int sl12(char *why)
{
    char h[256];
    hint_of(SEL_OFFER_BACK | SEL_OFFER_QUIT | SEL_TYPING, h, sizeof h);
    CHECK(strstr(h, "Esc/b back") && strstr(h, "q quit") && strstr(h, "or type"));
    return 1;
}

/* ---------- the loop, over a fake keyboard and screen ---------- */

typedef struct {
    int keys[32];
    int nkeys, kpos;
    char out[16384];
} Screen;

static int fake_read_key(void *ctx)
{
    Screen *sc = (Screen *)ctx;
    return sc->kpos < sc->nkeys ? sc->keys[sc->kpos++] : SEL_KEY_ABORT;
}

static void fake_write(void *ctx, const char *text)
{
    Screen *sc = (Screen *)ctx;
    strncat(sc->out, text, sizeof sc->out - strlen(sc->out) - 1);
}

static void screen_keys(Screen *sc, int n, const int *keys)
{
    memset(sc, 0, sizeof *sc);
    memcpy(sc->keys, keys, (size_t)n * sizeof(int));
    sc->nkeys = n;
}

static SelResult run_loop(Screen *sc, int n, const char *const *labels, unsigned flags,
                          int *choice, int *typed)
{
    SelIo io;
    io.read_key = fake_read_key;
    io.write = fake_write;
    io.ctx = sc;
    return sel_loop(&io, "Pick", n, labels, flags, 0, choice, typed);
}

static int sl13(char *why)
{
    static const char *const labels[] = {"a", "b", "c"};
    int keys[] = {SEL_KEY_DOWN, SEL_KEY_DOWN, SEL_KEY_ENTER};
    int choice = 0, typed = 0;
    Screen sc;
    screen_keys(&sc, 3, keys);
    CHECK(run_loop(&sc, 3, labels, SEL_OFFER_BACK, &choice, &typed) == SEL_CHOSEN && choice == 2);
    CHECK(strstr(sc.out, "\xe2\x9c\x94 Pick: c"));
    CHECK(starts_with(sc.out, "\x1b[?25l") && ends_with(sc.out, "\x1b[?25h")); /* hidden, then restored */
    return 1;
}

static int sl14(char *why)
{
    static const char *const labels[] = {"a", "b"};
    int choice = 0, typed = 0;
    Screen sc;
    int esc[] = {SEL_KEY_ESC};
    int ignored[] = {SEL_KEY_OTHER, SEL_KEY_ESC, SEL_KEY_ENTER};
    int abort_[] = {SEL_KEY_ABORT};
    screen_keys(&sc, 1, esc);
    CHECK(run_loop(&sc, 2, labels, SEL_OFFER_BACK, &choice, &typed) == SEL_BACK);
    screen_keys(&sc, 3, ignored); /* Esc is not on offer here: ignored */
    CHECK(run_loop(&sc, 2, labels, 0, &choice, &typed) == SEL_CHOSEN && choice == 0);
    screen_keys(&sc, 1, abort_);
    CHECK(run_loop(&sc, 2, labels, 0, &choice, &typed) == SEL_EOF);
    return 1;
}

static int sl15(char *why)
{
    static const char *const labels[] = {"a", "b"};
    int keys[] = {'x'};
    int choice = 0, typed = 0;
    Screen sc;
    char *hide, *show;
    screen_keys(&sc, 1, keys);
    CHECK(run_loop(&sc, 2, labels, SEL_OFFER_BACK | SEL_TYPING, &choice, &typed) == SEL_TYPED && typed == 'x');
    hide = strstr(sc.out, "\x1b[?25l");
    show = strstr(sc.out, "\x1b[?25h");
    CHECK(hide && show && show > hide && ends_with(sc.out, "\x1b[?25h"));
    return 1;
}

/* ---------- pick(), over a scripted environment ---------- */

typedef struct {
    int use_select;
    /* scripted selector results (SL16) */
    SelResult scripted[4];
    int scripted_choice[4];
    int nscripted, spos;
    unsigned seen_flags;
    int seen_n;
    const char *seen_title;
    const char *seen_label0;
    /* real sel_loop over fake keys (SL17-SL20) */
    Screen keys;
    /* typed lines: the rest of the line after a typed key, or a whole line in plain mode */
    const char *lines[8];
    int nlines, lpos;
    char prompts[8][64];
    int nprompts;
    char out[16384];
} Env;

static SelResult env_select(void *ctx, const char *title, int n, const char *const *labels,
                            unsigned flags, int *choice, int *typed)
{
    Env *e = (Env *)ctx;
    SelIo io;
    e->seen_flags = flags;
    e->seen_n = n;
    e->seen_title = title;
    e->seen_label0 = labels[0];
    if (e->nscripted) {
        SelResult r = e->scripted[e->spos];
        if (r == SEL_CHOSEN) *choice = e->scripted_choice[e->spos];
        e->spos++;
        return r;
    }
    io.read_key = fake_read_key;
    io.write = fake_write;
    io.ctx = &e->keys;
    return sel_loop(&io, title, n, labels, flags, 0, choice, typed);
}

static int env_read_line(void *ctx, const char *prompt, int first, char *buf, size_t cap)
{
    Env *e = (Env *)ctx;
    const char *rest;
    if (e->nprompts < 8) {
        snprintf(e->prompts[e->nprompts], sizeof e->prompts[0], "%s", prompt);
        if (first >= 0) {
            size_t l = strlen(e->prompts[e->nprompts]);
            e->prompts[e->nprompts][l] = (char)first;
            e->prompts[e->nprompts][l + 1] = '\0';
        }
        e->nprompts++;
    }
    if (e->lpos >= e->nlines) return 0;
    rest = e->lines[e->lpos++];
    if (first >= 0) {
        buf[0] = (char)first;
        snprintf(buf + 1, cap - 1, "%s", rest);
    } else {
        snprintf(buf, cap, "%s", rest);
    }
    return 1;
}

static void env_write(void *ctx, const char *text)
{
    Env *e = (Env *)ctx;
    strncat(e->out, text, sizeof e->out - strlen(e->out) - 1);
}

static int fake_command(const char *line, char *out, size_t cap, ArError *err)
{
    (void)err;
    snprintf(out, cap, "ran:%s", line);
    return 0;
}

static PickIo env_io(Env *e)
{
    PickIo io;
    io.select = e->use_select ? env_select : NULL;
    io.read_line = env_read_line;
    io.write = env_write;
    io.ctx = e;
    return io;
}

static const char *const CAT_NAMES[] = {"length", "mass", "area"};

static PickSpec cat_spec(unsigned flags, int with_command)
{
    PickSpec spec;
    spec.title = "Cat";
    spec.n = 3;
    spec.labels = CAT_NAMES;
    spec.keys = CAT_NAMES;
    spec.numbers = NULL;
    spec.flags = flags;
    spec.prompt = "> ";
    spec.command = with_command ? fake_command : NULL;
    return spec;
}

static int sl16(char *why)
{
    static const char *const labels[] = {"x", "y"};
    Env e;
    PickIo io;
    PickSpec spec;
    int choice = 0;

    memset(&e, 0, sizeof e);
    e.use_select = 1;
    e.nscripted = 4;
    e.scripted[0] = SEL_CHOSEN; e.scripted_choice[0] = 1;
    e.scripted[1] = SEL_BACK;
    e.scripted[2] = SEL_QUIT;
    e.scripted[3] = SEL_EOF;
    io = env_io(&e);
    spec = cat_spec(SEL_OFFER_BACK | SEL_OFFER_QUIT, 0);
    spec.title = "t";
    spec.n = 2;
    spec.labels = labels;
    spec.keys = labels;
    CHECK(pick(&io, &spec, &choice) == PICK_CHOSEN && choice == 1);
    CHECK(e.seen_flags == (SEL_OFFER_BACK | SEL_OFFER_QUIT | SEL_TYPING) && e.seen_n == 2);
    CHECK(!strcmp(e.seen_title, "t") && !strcmp(e.seen_label0, "x"));
    CHECK(pick(&io, &spec, &choice) == PICK_BACK);
    CHECK(pick(&io, &spec, &choice) == PICK_QUIT);
    CHECK(pick(&io, &spec, &choice) == PICK_EOF);
    return 1;
}

static int sl17(char *why)
{
    Env e;
    PickIo io;
    PickSpec spec = cat_spec(SEL_OFFER_BACK | SEL_OFFER_QUIT, 1);
    int k1[] = {'m'}, k2[] = {'3'};
    int choice = 0;

    memset(&e, 0, sizeof e);
    e.use_select = 1;
    screen_keys(&e.keys, 1, k1);
    e.lines[0] = "ass"; e.nlines = 1;
    io = env_io(&e);
    CHECK(pick(&io, &spec, &choice) == PICK_CHOSEN && choice == 1); /* typed "mass" */
    CHECK(!strcmp(e.prompts[0], "> m")); /* the typed key is shown after the prompt */

    memset(&e, 0, sizeof e);
    e.use_select = 1;
    screen_keys(&e.keys, 1, k2);
    e.lines[0] = ""; e.nlines = 1;
    io = env_io(&e);
    CHECK(pick(&io, &spec, &choice) == PICK_CHOSEN && choice == 2); /* typed "3" */
    return 1;
}

static int sl18(char *why)
{
    Env e;
    PickIo io;
    PickSpec spec = cat_spec(SEL_OFFER_BACK | SEL_OFFER_QUIT, 1);
    int keys[] = {'l', SEL_KEY_ENTER};
    int choice = 0;

    memset(&e, 0, sizeof e);
    e.use_select = 1;
    screen_keys(&e.keys, 2, keys);
    e.lines[0] = "ist"; e.nlines = 1;
    io = env_io(&e);
    CHECK(pick(&io, &spec, &choice) == PICK_CHOSEN && choice == 0);
    CHECK(strstr(e.out, "ran:list\n")); /* the command ran, then the list came back */
    return 1;
}

static int sl19(char *why)
{
    Env e;
    PickIo io;
    PickSpec spec = cat_spec(SEL_OFFER_BACK | SEL_OFFER_QUIT, 0);
    int keys[] = {'x', SEL_KEY_ESC};
    int choice = 0;

    memset(&e, 0, sizeof e);
    e.use_select = 1;
    screen_keys(&e.keys, 2, keys);
    e.lines[0] = "yz"; e.nlines = 1;
    io = env_io(&e);
    CHECK(pick(&io, &spec, &choice) == PICK_BACK); /* then Esc goes back */
    CHECK(strstr(e.out, "Error [UNKNOWN_COMMAND]: Pick one from the list"));
    return 1;
}

static int sl20(char *why)
{
    Env e;
    PickIo io;
    PickSpec spec = cat_spec(SEL_OFFER_BACK | SEL_OFFER_QUIT, 0);
    int kb[] = {'b'}, kq[] = {'q'}, ke[] = {SEL_KEY_ESC}, kd[] = {SEL_KEY_ABORT};
    int choice = 0;
    const int *keys[4] = {kb, kq, ke, kd};
    PickStatus want[4] = {PICK_BACK, PICK_QUIT, PICK_BACK, PICK_EOF};
    int i;

    for (i = 0; i < 4; i++) {
        memset(&e, 0, sizeof e);
        e.use_select = 1;
        screen_keys(&e.keys, 1, keys[i]);
        io = env_io(&e);
        CHECK(pick(&io, &spec, &choice) == want[i]);
        CHECK(e.nprompts == 0); /* no prompt line was shown */
    }
    return 1;
}

static int sl21(char *why)
{
    Env e;
    PickIo io;
    PickSpec spec = cat_spec(SEL_OFFER_BACK | SEL_OFFER_QUIT, 0);
    int choice = 0;

    memset(&e, 0, sizeof e);
    e.use_select = 0; /* a pipe: no selector */
    e.lines[0] = "mass"; e.nlines = 1;
    io = env_io(&e);
    CHECK(pick(&io, &spec, &choice) == PICK_CHOSEN && choice == 1);
    CHECK(strstr(e.out, "  1) length") && strstr(e.out, "  3) area")); /* the numbered list is shown */
    CHECK(!strcmp(e.prompts[0], "> "));
    return 1;
}

/* ---------- runner ---------- */

static const struct { const char *name; TestFn fn; } TESTS[] = {
    {"up/down move, wrap around, home/end", sl1},
    {"long lists scroll in a window of 10", sl2},
    {"Enter selects; Esc / b / q only work when offered", sl3},
    {"Ctrl-C / Ctrl-D abort; other control keys are ignored", sl4},
    {"typing on: a printable key ends the selector and carries the character", sl5},
    {"typing off: printable keys are ignored", sl6},
    {"typing on: Esc, b, q, arrows and Enter keep their meaning", sl7},
    {"typing on: space and control keys do not start a typed line", sl8},
    {"the selected row is highlighted as a full bar", sl9},
    {"plain mode still marks the selected row with the pointer", sl10},
    {"hint line lists only the keys on offer", sl11},
    {"hint shows Esc/b back and or type when typing is on", sl12},
    {"loop: keys in, index out, summary left behind, cursor restored", sl13},
    {"loop: Esc, ignored keys, Ctrl-C", sl14},
    {"loop: a typed key returns its character and restores the cursor", sl15},
    {"pick() uses the selector when present and maps its results", sl16},
    {"pick(): a typed name or number selects it", sl17},
    {"pick(): a typed one-line command runs and the list comes back", sl18},
    {"pick(): an unknown typed word is an error and the list comes back", sl19},
    {"pick(): b, q and Esc act at once, with no prompt line", sl20},
    {"pick(): without a selector (pipes) the numbered list works as before", sl21}
};

int main(void)
{
    int n = (int)(sizeof TESTS / sizeof TESTS[0]), i, passed = 0, failed = 0;
    for (i = 0; i < n; i++) {
        char why[200] = "";
        if (TESTS[i].fn(why)) {
            passed++;
            printf("ok   SL%d  %s\n", i + 1, TESTS[i].name);
        } else {
            failed++;
            printf("FAIL SL%d  %s -- %s\n", i + 1, TESTS[i].name, why);
        }
    }
    printf("selector tests: %d passed, %d failed (SL1-SL%d)\n", passed, failed, n);
    if (n != EXPECTED_TESTS) {
        printf("FAIL: expected %d selector tests\n", EXPECTED_TESTS);
        return 1;
    }
    return failed ? 1 : 0;
}
