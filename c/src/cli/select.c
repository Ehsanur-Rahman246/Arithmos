#if !defined(_WIN32)
#define _POSIX_C_SOURCE 200809L
#endif

#include "cli/select.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_LABEL 70

/* ---------- platform layer: is_tty, enable_ansi, read_key ---------- */

#ifdef _WIN32

#include <conio.h>
#include <io.h>
#include <windows.h>

#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif

static UINT saved_cp = 0;

static void restore_cp(void) { if (saved_cp) SetConsoleOutputCP(saved_cp); }

void term_init(void)
{
    DWORD mode;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == INVALID_HANDLE_VALUE || !GetConsoleMode(h, &mode)) return;
    if (GetConsoleOutputCP() != 65001) {
        saved_cp = GetConsoleOutputCP();
        SetConsoleOutputCP(65001);
        atexit(restore_cp);
    }
}

static int is_tty(void) { return _isatty(_fileno(stdin)) && _isatty(_fileno(stdout)); }

static int enable_ansi(void)
{
    DWORD mode;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == INVALID_HANDLE_VALUE || !GetConsoleMode(h, &mode)) return 0;
    if (mode & ENABLE_VIRTUAL_TERMINAL_PROCESSING) return 1;
    return SetConsoleMode(h, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING) != 0;
}

static int read_key(void)
{
    int c = _getch();
    if (c == 0 || c == 0xE0) { /* extended key: a second code follows */
        switch (_getch()) {
        case 72: return SEL_KEY_UP;
        case 80: return SEL_KEY_DOWN;
        case 71: return SEL_KEY_HOME;
        case 79: return SEL_KEY_END;
        case 73: return SEL_KEY_PGUP;
        case 81: return SEL_KEY_PGDN;
        default: return SEL_KEY_OTHER;
        }
    }
    if (c == 13) return SEL_KEY_ENTER;
    if (c == 27) return SEL_KEY_ESC;
    if (c == 3 || c == 4 || c == 26) return SEL_KEY_ABORT; /* Ctrl-C, Ctrl-D, Ctrl-Z */
    if (c >= 33 && c <= 126) return c;
    return SEL_KEY_OTHER;
}

#else /* POSIX */

#include <sys/select.h>
#include <termios.h>
#include <unistd.h>

void term_init(void) {}

static int is_tty(void) { return isatty(0) && isatty(1); }

static int enable_ansi(void)
{
    const char *t = getenv("TERM");
    return t && *t && strcmp(t, "dumb") != 0;
}

static int input_ready(int ms)
{
    fd_set fds;
    struct timeval tv;
    FD_ZERO(&fds);
    FD_SET(0, &fds);
    tv.tv_sec = 0;
    tv.tv_usec = ms * 1000;
    return select(1, &fds, NULL, NULL, &tv) > 0;
}

static int next_byte(void)
{
    unsigned char c;
    if (!input_ready(50) || read(0, &c, 1) != 1) return -1;
    return c;
}

/* Raw mode is on only while one key is read, so the terminal is never left raw. */
static int read_key(void)
{
    struct termios old, raw;
    unsigned char c;
    int key;

    if (tcgetattr(0, &old)) return SEL_KEY_ABORT;
    raw = old;
    raw.c_lflag &= ~(tcflag_t)(ICANON | ECHO | ISIG);
    raw.c_cc[VMIN] = 1;
    raw.c_cc[VTIME] = 0;
    tcsetattr(0, TCSADRAIN, &raw);

    if (read(0, &c, 1) != 1) {
        key = SEL_KEY_ABORT;
    } else if (c == 27) {
        int c2 = next_byte();
        if (c2 < 0) {
            key = SEL_KEY_ESC; /* a lone Esc */
        } else if (c2 == '[' || c2 == 'O') {
            int param = 0, c3;
            key = SEL_KEY_OTHER;
            while ((c3 = next_byte()) >= 0) {
                if (c3 >= '0' && c3 <= '9') { param = param * 10 + (c3 - '0'); continue; }
                if (c3 == ';') { param = 0; continue; }
                if (c3 == 'A') key = SEL_KEY_UP;
                else if (c3 == 'B') key = SEL_KEY_DOWN;
                else if (c3 == 'H') key = SEL_KEY_HOME;
                else if (c3 == 'F') key = SEL_KEY_END;
                else if (c3 == '~') {
                    if (param == 1 || param == 7) key = SEL_KEY_HOME;
                    else if (param == 4 || param == 8) key = SEL_KEY_END;
                    else if (param == 5) key = SEL_KEY_PGUP;
                    else if (param == 6) key = SEL_KEY_PGDN;
                }
                break;
            }
        } else {
            key = SEL_KEY_OTHER;
        }
    } else if (c == 10 || c == 13) key = SEL_KEY_ENTER;
    else if (c == 3 || c == 4) key = SEL_KEY_ABORT; /* Ctrl-C, Ctrl-D */
    else if (c >= 33 && c <= 126) key = c;
    else key = SEL_KEY_OTHER;

    tcsetattr(0, TCSADRAIN, &old);
    return key;
}

#endif

/* ---------- key handling (pure) ---------- */

void sel_state_init(SelState *s, int count, int start)
{
    s->count = count;
    s->size = count < SEL_WINDOW ? count : SEL_WINDOW;
    s->index = (start >= 0 && start < count) ? start : 0;
    s->offset = s->index >= s->size ? s->index - s->size + 1 : 0;
}

static void move_to(SelState *s, int index)
{
    s->index = index;
    if (index < s->offset) s->offset = index;
    if (index >= s->offset + s->size) s->offset = index - s->size + 1;
}

SelResult sel_apply_key(SelState *s, int key, unsigned flags, int *typed_char)
{
    switch (key) {
    case SEL_KEY_UP:   move_to(s, (s->index + s->count - 1) % s->count); return SEL_CONTINUE;
    case SEL_KEY_DOWN: move_to(s, (s->index + 1) % s->count); return SEL_CONTINUE;
    case SEL_KEY_HOME: move_to(s, 0); return SEL_CONTINUE;
    case SEL_KEY_END:  move_to(s, s->count - 1); return SEL_CONTINUE;
    case SEL_KEY_PGUP: move_to(s, s->index - s->size < 0 ? 0 : s->index - s->size); return SEL_CONTINUE;
    case SEL_KEY_PGDN:
        move_to(s, s->index + s->size > s->count - 1 ? s->count - 1 : s->index + s->size);
        return SEL_CONTINUE;
    case SEL_KEY_ENTER: return SEL_CHOSEN;
    case SEL_KEY_ABORT: return SEL_EOF;
    case SEL_KEY_ESC:
    case 'b':
    case 'B':
        return (flags & SEL_OFFER_BACK) ? SEL_BACK : SEL_CONTINUE;
    case 'q':
    case 'Q':
        return (flags & SEL_OFFER_QUIT) ? SEL_QUIT : SEL_CONTINUE;
    default:
        if ((flags & SEL_TYPING) && key >= 33 && key <= 126) {
            if (typed_char) *typed_char = key;
            return SEL_TYPED;
        }
        return SEL_CONTINUE;
    }
}

/* ---------- drawing (pure) ---------- */

int sel_render(char *buf, size_t cap, const char *title, const char *const *labels,
               const SelState *s, unsigned flags, int colour)
{
    size_t len = 0;
    int i, lines = 0, width = 0;
    const char *sep = "";

#define ADD(...) do { \
        int w_ = snprintf(buf + len, cap - len, __VA_ARGS__); \
        if (w_ > 0 && (size_t)w_ < cap - len) len += (size_t)w_; \
    } while (0)

    for (i = 0; i < s->count; i++) {
        int l = (int)strlen(labels[i]);
        if (l > MAX_LABEL) l = MAX_LABEL;
        if (l > width) width = l;
    }
    buf[0] = '\0';
    ADD("%s%s%s\n", colour ? "\x1b[1m" : "", title, colour ? "\x1b[0m" : "");
    lines++;
    for (i = s->offset; i < s->offset + s->size; i++) {
        if (i == s->index) {
            ADD("%s \xe2\x9d\xaf %-*.*s %s\n", colour ? "\x1b[7m" : "", width, MAX_LABEL, labels[i],
                colour ? "\x1b[0m" : ""); /* the whole selected row is a bar */
        } else {
            ADD("   %.*s\n", MAX_LABEL, labels[i]);
        }
        lines++;
    }
    if (s->count > s->size) {
        ADD("%s   %d of %d%s\n", colour ? "\x1b[2m" : "", s->index + 1, s->count, colour ? "\x1b[0m" : "");
        lines++;
    }
    ADD("%s   \xe2\x86\x91\xe2\x86\x93 move \xc2\xb7 Enter select", colour ? "\x1b[2m" : "");
    sep = " \xc2\xb7 ";
    if (flags & SEL_OFFER_BACK) ADD("%s%s", sep, (flags & SEL_TYPING) ? "Esc/b back" : "Esc back");
    if (flags & SEL_OFFER_QUIT) ADD("%sq quit", sep);
    if (flags & SEL_TYPING) ADD("%sor type", sep);
    ADD("%s\n", colour ? "\x1b[0m" : "");
    lines++;
#undef ADD
    return lines;
}

/* ---------- the draw/read loop (over an injectable keyboard and screen) ---------- */

/* Each frame is built in memory and written once, so the terminal never shows a
 * half-drawn list. Lines are overwritten in place and cleared to the end
 * (\x1b[K) instead of being blanked first, which avoids a flash. */
static void draw(const SelIo *io, const char *text, int lines, int redraw)
{
    char frame[10240];
    size_t len = 0;
    const char *p = text;

    if (redraw) len += (size_t)snprintf(frame, sizeof frame, "\x1b[%dA", lines);
    while (*p && len + 16 < sizeof frame) {
        const char *e = strchr(p, '\n');
        size_t n = e ? (size_t)(e - p) : strlen(p);
        if (len + n + 16 >= sizeof frame) break;
        frame[len++] = '\r';
        memcpy(frame + len, p, n);
        len += n;
        memcpy(frame + len, "\x1b[K\n", 4);
        len += 4;
        if (!e) break;
        p = e + 1;
    }
    frame[len] = '\0';
    io->write(io->ctx, frame);
}

SelResult sel_loop(const SelIo *io, const char *title, int n, const char *const *labels,
                   unsigned flags, int colour, int *choice, int *typed_char)
{
    SelState st;
    char text[8192], tmp[256];
    int drawn;
    SelResult r;

    sel_state_init(&st, n, *choice);
    io->write(io->ctx, "\x1b[?25l"); /* hide the cursor while choosing */
    drawn = sel_render(text, sizeof text, title, labels, &st, flags, colour);
    draw(io, text, drawn, 0);

    for (;;) {
        SelState before = st;
        r = sel_apply_key(&st, io->read_key(io->ctx), flags, typed_char);
        if (r != SEL_CONTINUE) break;
        if (st.index != before.index || st.offset != before.offset) {
            drawn = sel_render(text, sizeof text, title, labels, &st, flags, colour);
            draw(io, text, drawn, 1);
        }
    }

    snprintf(tmp, sizeof tmp, "\x1b[%dA\r\x1b[J", drawn); /* remove the list */
    io->write(io->ctx, tmp);
    if (r == SEL_CHOSEN) {
        *choice = st.index;
        snprintf(tmp, sizeof tmp, "%s\xe2\x9c\x94%s %s: %.*s\n", colour ? "\x1b[32m" : "",
                 colour ? "\x1b[0m" : "", title, MAX_LABEL, labels[st.index]);
        io->write(io->ctx, tmp);
    }
    io->write(io->ctx, "\x1b[?25h");
    return r;
}

/* ---------- the real terminal ---------- */

int sel_enabled(void)
{
    static int cached = -1;
    if (cached < 0) {
        const char *plain = getenv("ARITHMOS_PLAIN");
        cached = !(plain && *plain && strcmp(plain, "0") != 0) && is_tty() && enable_ansi();
    }
    return cached;
}

static int use_colour(void)
{
    const char *nc = getenv("NO_COLOR");
    return !(nc && *nc);
}

static int cursor_hidden = 0;

static void show_cursor_at_exit(void)
{
    if (cursor_hidden) {
        fputs("\x1b[?25h", stdout);
        fflush(stdout);
    }
}

static int term_read_key(void *ctx)
{
    (void)ctx;
    return read_key();
}

static void term_write(void *ctx, const char *text)
{
    (void)ctx;
    fputs(text, stdout);
    fflush(stdout);
}

SelResult sel_run(const char *title, int n, const char *const *labels, unsigned flags,
                  int *choice, int *typed_char)
{
    static int registered = 0;
    SelIo io;
    SelResult r;
    io.read_key = term_read_key;
    io.write = term_write;
    io.ctx = NULL;
    if (!registered) {
        atexit(show_cursor_at_exit); /* never leave the cursor hidden */
        registered = 1;
    }
    cursor_hidden = 1;
    r = sel_loop(&io, title, n, labels, flags, use_colour(), choice, typed_char);
    cursor_hidden = 0;
    return r;
}
