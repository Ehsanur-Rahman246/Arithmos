#include "cli/cli.h"

#include "calculator/calculator.h"
#include "converter/converter.h"
#include "cli/pick.h"
#include "cli/select.h"
#include "programmer/programmer.h"
#include "shared/shared.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LINE_LEN 4096
#define OUT_LEN 4096

/* The same numbers as PickStatus (PICK_BACK, PICK_QUIT, PICK_EOF), so a pick result can be returned as is. */
enum { RES_BACK = 1, RES_QUIT = 2, RES_EOF = 3 };

static const char *const STANDARD_INTRO =
    "Standard Calculator   (help \xc2\xb7 back \xc2\xb7 quit)\n"
    "Try: 2 + 3 * 4    sqrt(16)    20% of 150    ans * 2\n";
static const char *const STANDARD_HELP =
    "  2 + 3 * 4        + - * / ^ and ( )\n"
    "  sqrt(x) abs(x)   functions\n"
    "  20% of 150       percent;  200 + 10% adds 10% of 200\n"
    "  ans              the last result\n"
    "  back  main menu     quit  exit\n";

static const char *const PROGRAMMER_INTRO =
    "Programmer Calculator \xc2\xb7 64-bit integers   (help \xc2\xb7 back \xc2\xb7 quit)\n"
    "Try: 255    5 AND 3    1 << 3    255 dec hex\n";
static const char *const PROGRAMMER_HELP =
    "  255  0xFF  0b101    show a number in HEX DEC OCT BIN\n"
    "  5 AND 3             also OR, XOR;  NOT 5\n"
    "  1 << 3              shifts: << left, >> arithmetic, >>> logical\n"
    "  255 dec hex         convert between bin, oct, dec, hex\n"
    "  base hex            type numbers in hex from now on\n"
    "  back  main menu     quit  exit\n";

static const char *const CONVERTER_HELP =
    "  100            convert that number\n"
    "  100 cm in      or the full form:  convert 100 cm in\n"
    "  1 km all       the value in every unit\n"
    "  list           categories;   list length   its units\n"
    "  back  previous screen     quit  exit\n";

/* ---------- input / output helpers ---------- */

/* Read the rest of a line into buf[used..]. Returns 0 at end of input. */
static int read_into(char *buf, size_t n, size_t used)
{
    size_t len;
    if (!fgets(buf + used, (int)(n - used), stdin)) return 0;
    len = strlen(buf);
    if (len > 0 && buf[len - 1] == '\n') {
        buf[len - 1] = '\0';
    } else if (len == n - 1) { /* line too long: drop the rest of it */
        int c;
        while ((c = getchar()) != '\n' && c != EOF) {}
    }
    ar_trim(buf);
    return 1;
}

static int read_line(const char *prompt, char *buf, size_t n)
{
    fputs(prompt, stdout);
    fflush(stdout);
    if (!read_into(buf, n, 0)) { putchar('\n'); return 0; }
    return 1;
}

/* The selector consumed one typed key; echo it after the prompt and read the rest. */
static int read_line_after(const char *prompt, int first, char *buf, size_t n)
{
    printf("%s%c", prompt, first);
    fflush(stdout);
    buf[0] = (char)first;
    if (!read_into(buf, n, 1)) { putchar('\n'); return 0; }
    return 1;
}

static void print_error(FILE *f, const ArError *e)
{
    fprintf(f, "Error [%s]: %s\n", ar_code_name(e->code), e->message);
}

static void print_prog_result(FILE *f, const ProgResult *r)
{
    if (r->kind == PROG_RESULT_TEXT) {
        fprintf(f, "%s\n", r->text);
    } else {
        fprintf(f, "HEX: %s\nDEC: %s\nOCT: %s\nBIN: %s\n", r->hex, r->dec, r->oct, r->bin);
    }
}

/* Returns 0 when the line is not a shell command, RES_BACK / RES_QUIT, or -1
 * when it was handled here (help). */
static int shell_command(const char *line, const char *help)
{
    if (!ar_strcasecmp(line, "back")) return RES_BACK;
    if (!ar_strcasecmp(line, "quit")) return RES_QUIT;
    if (!ar_strcasecmp(line, "help") || !strcmp(line, "?")) {
        fputs(help, stdout);
        return -1;
    }
    return 0;
}

/* ---------- Standard Calculator ---------- */

static int run_standard(void)
{
    CalcSession s;
    char line[LINE_LEN], out[64];
    ArError err;
    calc_session_init(&s);
    fputs(STANDARD_INTRO, stdout);
    for (;;) {
        int cmd;
        if (!read_line("standard> ", line, sizeof line)) return RES_EOF;
        if (!line[0]) continue;
        cmd = shell_command(line, STANDARD_HELP);
        if (cmd == -1) continue;
        if (cmd) return cmd;
        if (calc_run(&s, line, out, sizeof out, &err) == 0) puts(out);
        else print_error(stdout, &err);
    }
}

/* ---------- Programmer Calculator ---------- */

static int run_programmer(void)
{
    ProgSession s;
    char line[LINE_LEN];
    ProgResult res;
    ArError err;
    prog_session_init(&s);
    fputs(PROGRAMMER_INTRO, stdout);
    for (;;) {
        int cmd;
        if (!read_line("programmer> ", line, sizeof line)) return RES_EOF;
        if (!line[0]) continue;
        cmd = shell_command(line, PROGRAMMER_HELP);
        if (cmd == -1) continue;
        if (cmd) return cmd;
        if (prog_execute(&s, line, &res, &err) == 0) print_prog_result(stdout, &res);
        else print_error(stdout, &err);
    }
}

/* ---------- Unit Converter (guided flow) ---------- */

static int count_words(const char *s)
{
    int n = 0;
    while (*s) {
        while (*s && isspace((unsigned char)*s)) s++;
        if (!*s) break;
        n++;
        while (*s && !isspace((unsigned char)*s)) s++;
    }
    return n;
}

static int starts_with_word(const char *s, const char *word)
{
    size_t n = strlen(word);
    size_t i;
    for (i = 0; i < n; i++) {
        if (tolower((unsigned char)s[i]) != word[i]) return 0;
    }
    return s[n] == '\0' || isspace((unsigned char)s[n]);
}

static void run_one_line(const char *line)
{
    char out[OUT_LEN];
    ArError err;
    if (conv_run_line(line, out, sizeof out, &err) == 0) puts(out);
    else print_error(stdout, &err);
}

/* ---------- the terminal side of pick() ---------- */

static SelResult term_select(void *ctx, const char *title, int n, const char *const *labels,
                             unsigned flags, int *choice, int *typed)
{
    (void)ctx;
    return sel_run(title, n, labels, flags, choice, typed);
}

static int term_read_line(void *ctx, const char *prompt, int first, char *buf, size_t cap)
{
    (void)ctx;
    return first >= 0 ? read_line_after(prompt, first, buf, cap) : read_line(prompt, buf, cap);
}

static void term_write(void *ctx, const char *text)
{
    (void)ctx;
    fputs(text, stdout);
}

static PickIo terminal_io(void)
{
    PickIo io;
    io.select = sel_enabled() ? term_select : NULL; /* numbered lists on pipes and files */
    io.read_line = term_read_line;
    io.write = term_write;
    io.ctx = NULL;
    return io;
}

static int converter_command(const char *line, char *out, size_t cap, ArError *err)
{
    return conv_run_line(line, out, cap, err);
}

static int pick_category(int *choice)
{
    const char *names[32];
    int i, n = conv_category_count();
    PickIo io = terminal_io();
    PickSpec spec;
    for (i = 0; i < n; i++) names[i] = conv_category(i)->name;
    spec.title = "Unit Converter \xe2\x80\x94 choose a category";
    spec.n = n;
    spec.labels = names;
    spec.keys = names;
    spec.numbers = NULL;
    spec.flags = SEL_OFFER_BACK | SEL_OFFER_QUIT;
    spec.prompt = "> ";
    spec.command = converter_command;
    return (int)pick(&io, &spec, choice);
}

/* `from` is NULL for the from-unit screen, or the chosen from-unit's symbol. */
static int pick_unit(const ConvCategory *cat, const char *from, int *choice)
{
    const char *keys[32], *labels[32];
    char text[32][96], title[160], cap[32];
    int i, n = cat->unit_count;
    PickIo io = terminal_io();
    PickSpec spec;
    for (i = 0; i < n; i++) {
        snprintf(text[i], sizeof text[i], "%-8s%s", cat->units[i].symbol, cat->units[i].name);
        keys[i] = cat->units[i].symbol;
        labels[i] = text[i];
    }
    snprintf(cap, sizeof cap, "%s", cat->name);
    if (cap[0] >= 'a' && cap[0] <= 'z') cap[0] = (char)(cap[0] - 'a' + 'A');
    if (from) snprintf(title, sizeof title, "%s \xe2\x80\x94 convert from %s to", cap, from);
    else snprintf(title, sizeof title, "%s \xe2\x80\x94 convert from", cap);
    spec.title = title;
    spec.n = n;
    spec.labels = labels;
    spec.keys = keys;
    spec.numbers = NULL;
    spec.flags = SEL_OFFER_BACK | SEL_OFFER_QUIT;
    spec.prompt = "> ";
    spec.command = converter_command;
    return (int)pick(&io, &spec, choice);
}

static int run_converter(void)
{
    enum { ST_CATEGORY, ST_FROM, ST_TO, ST_VALUES } st = ST_CATEGORY;
    int cat = 0, from = 0, to = 0, r;
    char line[LINE_LEN], out[OUT_LEN], prompt[96];

    for (;;) {
        const ConvCategory *c = conv_category(cat);
        switch (st) {
        case ST_CATEGORY:
            r = pick_category(&cat);
            if (r == PICK_CHOSEN) st = ST_FROM;
            else return r; /* back from the first screen leaves the tool */
            break;
        case ST_FROM:
            r = pick_unit(c, NULL, &from);
            if (r == PICK_CHOSEN) st = ST_TO;
            else if (r == PICK_BACK) st = ST_CATEGORY;
            else return r;
            break;
        case ST_TO:
            r = pick_unit(c, c->units[from].symbol, &to);
            if (r == PICK_CHOSEN) st = ST_VALUES;
            else if (r == PICK_BACK) st = ST_FROM;
            else return r;
            break;
        case ST_VALUES: {
            ArError err;
            char cap[32];
            snprintf(cap, sizeof cap, "%s", c->name);
            if (cap[0] >= 'a' && cap[0] <= 'z') cap[0] = (char)(cap[0] - 'a' + 'A');
            printf("\n%s: %s \xe2\x86\x92 %s\n", cap, c->units[from].symbol, c->units[to].symbol);
            puts("Type a number or a full command.   (help \xc2\xb7 back \xc2\xb7 quit)");
            snprintf(prompt, sizeof prompt, "converter (%s \xe2\x86\x92 %s)> ",
                     c->units[from].symbol, c->units[to].symbol);
            for (;;) {
                if (!read_line(prompt, line, sizeof line)) return RES_EOF;
                if (!line[0]) continue;
                if (!ar_strcasecmp(line, "back")) { st = ST_TO; break; }
                if (!ar_strcasecmp(line, "quit")) return RES_QUIT;
                if (!ar_strcasecmp(line, "help") || !strcmp(line, "?")) {
                    fputs(CONVERTER_HELP, stdout);
                    continue;
                }
                if (!starts_with_word(line, "convert") && !starts_with_word(line, "list") &&
                    count_words(line) == 1) {
                    if (conv_convert(line, c->units[from].symbol, c->units[to].symbol,
                                     out, sizeof out, &err) == 0) {
                        char shown[64];
                        if (ar_format_number(strtod(line, NULL), shown, sizeof shown, &err))
                            snprintf(shown, sizeof shown, "%.60s", line);
                        printf("%s %s = %s %s\n", shown, c->units[from].symbol, out,
                               c->units[to].symbol);
                    } else {
                        print_error(stdout, &err);
                    }
                } else {
                    run_one_line(line);
                }
            }
            break;
        }
        }
    }
}

/* ---------- main menu ---------- */

static int run_menu(void)
{
    static const char *const labels[] = {"Standard Calculator", "Programmer Calculator",
                                         "Unit Converter", "Exit"};
    static const char *const keys[] = {"standard", "programmer", "converter", "exit"};
    static const char *const numbers[] = {"1", "2", "3", "0"};
    PickIo io = terminal_io();
    PickSpec spec;
    int choice = 0;

    spec.title = "Arithmos 1.0 \xe2\x80\x94 Core CLI";
    spec.n = 4;
    spec.labels = labels;
    spec.keys = keys;
    spec.numbers = numbers;
    spec.flags = SEL_OFFER_QUIT; /* there is nowhere further back than the menu */
    spec.prompt = "> ";
    spec.command = NULL;

    for (;;) {
        int r;
        if (pick(&io, &spec, &choice) != PICK_CHOSEN || choice == 3) return 0;
        r = choice == 0 ? run_standard() : choice == 1 ? run_programmer() : run_converter();
        if (r == RES_QUIT || r == RES_EOF) return 0;
        /* RES_BACK: show the menu again */
    }
}

/* ---------- one-shot mode ---------- */

static const char *const USAGE =
    "Usage:\n"
    "  arithmos                          interactive menu\n"
    "  arithmos std \"<expression>\"       one Standard Calculator line\n"
    "  arithmos prog \"<command>\"         one Programmer Calculator line\n"
    "  arithmos convert <value> <from> <to>   one Unit Converter line (also: list, ... all)\n";

static void join_args(int argc, char **argv, int start, char *buf, size_t cap)
{
    int i;
    size_t len = 0;
    buf[0] = '\0';
    for (i = start; i < argc; i++) {
        size_t l = strlen(argv[i]);
        if (len + l + 2 > cap) break;
        if (i > start) buf[len++] = ' ';
        memcpy(buf + len, argv[i], l);
        len += l;
        buf[len] = '\0';
    }
}

static int one_shot(int argc, char **argv)
{
    const char *cmd = argv[1];
    char line[LINE_LEN], out[OUT_LEN];
    ArError err;
    int is_std  = !ar_strcasecmp(cmd, "std")  || !ar_strcasecmp(cmd, "standard");
    int is_prog = !ar_strcasecmp(cmd, "prog") || !ar_strcasecmp(cmd, "programmer");
    int is_conv = !ar_strcasecmp(cmd, "convert") || !ar_strcasecmp(cmd, "list");

    if (!ar_strcasecmp(cmd, "help") || !strcmp(cmd, "--help") || !strcmp(cmd, "-h")) {
        fputs(USAGE, stdout);
        return 0;
    }
    if (!is_std && !is_prog && !is_conv) { fputs(USAGE, stderr); return 2; }
    join_args(argc, argv, is_conv ? 1 : 2, line, sizeof line); /* convert/list keep their own word */
    ar_trim(line);
    if (!line[0]) { fputs(USAGE, stderr); return 2; }

    if (is_std) {
        CalcSession s;
        calc_session_init(&s);
        if (calc_run(&s, line, out, sizeof out, &err) == 0) { puts(out); return 0; }
    } else if (is_prog) {
        ProgSession s;
        ProgResult res;
        prog_session_init(&s);
        if (prog_execute(&s, line, &res, &err) == 0) { print_prog_result(stdout, &res); return 0; }
    } else {
        if (conv_run_line(line, out, sizeof out, &err) == 0) { puts(out); return 0; }
    }
    print_error(stderr, &err);
    return 1;
}

int arithmos_main(int argc, char **argv)
{
    term_init();
    if (argc > 1) return one_shot(argc, argv);
    return run_menu();
}
