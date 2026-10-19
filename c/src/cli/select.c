#if !defined(_WIN32)
#define _POSIX_C_SOURCE 200809L
#endif

#include "cli/select.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_VISIBLE 10
#define MAX_LABEL 70

enum { K_UP = 1000, K_DOWN, K_HOME, K_END, K_PGUP, K_PGDN, K_ENTER, K_ESC, K_EOF, K_OTHER };

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
        case 72: return K_UP;
        case 80: return K_DOWN;
        case 71: return K_HOME;
        case 79: return K_END;
        case 73: return K_PGUP;
        case 81: return K_PGDN;
        default: return K_OTHER;
        }
    }
    if (c == 13) return K_ENTER;
    if (c == 27) return K_ESC;
    if (c == 3 || c == 4 || c == 26) return K_EOF; /* Ctrl-C, Ctrl-D, Ctrl-Z */
    if (c >= 32 && c <= 126) return c;
    return K_OTHER;
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

    if (tcgetattr(0, &old)) return K_EOF;
    raw = old;
    raw.c_lflag &= ~(tcflag_t)(ICANON | ECHO | ISIG);
    raw.c_cc[VMIN] = 1;
    raw.c_cc[VTIME] = 0;
    tcsetattr(0, TCSADRAIN, &raw);

    if (read(0, &c, 1) != 1) {
        key = K_EOF;
    } else if (c == 27) {
        int c2 = next_byte();
        if (c2 < 0) {
            key = K_ESC; /* a lone Esc */
        } else if (c2 == '[' || c2 == 'O') {
            int param = 0, c3;
            key = K_OTHER;
            while ((c3 = next_byte()) >= 0) {
                if (c3 >= '0' && c3 <= '9') { param = param * 10 + (c3 - '0'); continue; }
                if (c3 == ';') { param = 0; continue; }
                if (c3 == 'A') key = K_UP;
                else if (c3 == 'B') key = K_DOWN;
                else if (c3 == 'H') key = K_HOME;
                else if (c3 == 'F') key = K_END;
                else if (c3 == '~') {
                    if (param == 1 || param == 7) key = K_HOME;
                    else if (param == 4 || param == 8) key = K_END;
                    else if (param == 5) key = K_PGUP;
                    else if (param == 6) key = K_PGDN;
                }
                break;
            }
        } else {
            key = K_OTHER;
        }
    } else if (c == 10 || c == 13) key = K_ENTER;
    else if (c == 3 || c == 4) key = K_EOF; /* Ctrl-C, Ctrl-D */
    else if (c >= 32 && c <= 126) key = c;
    else key = K_OTHER;

    tcsetattr(0, TCSADRAIN, &old);
    return key;
}

#endif

/* ---------- portable selector ---------- */

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

static void draw(const char *const *labels, int n, int visible, int top, int sel, int redraw)
{
    int i, colour = use_colour();
    if (redraw) printf("\x1b[%dA", visible + 1);
    for (i = top; i < top + visible; i++) {
        printf("\r\x1b[2K");
        if (i == sel) {
            if (colour) printf("\x1b[7m");
            printf("> %.*s", MAX_LABEL, labels[i]);
            if (colour) printf("\x1b[0m");
        } else {
            printf("  %.*s", MAX_LABEL, labels[i]);
        }
        printf("\n");
    }
    printf("\r\x1b[2K  Up/Down move, Enter select, Esc back, or type  (%d/%d)\n", sel + 1, n);
    fflush(stdout);
}

static void erase(int visible)
{
    printf("\x1b[%dA\r\x1b[J", visible + 1);
}

SelResult sel_run(const char *title, int n, const char *const *labels,
                  int *choice, int *typed_char)
{
    int visible = n < MAX_VISIBLE ? n : MAX_VISIBLE;
    int sel = (*choice >= 0 && *choice < n) ? *choice : 0;
    int top = 0;

    if (sel >= visible) top = sel - visible + 1;
    printf("%s\n", title);
    draw(labels, n, visible, top, sel, 0);

    for (;;) {
        int key = read_key();
        switch (key) {
        case K_UP:   sel = (sel + n - 1) % n; break;
        case K_DOWN: sel = (sel + 1) % n; break;
        case K_HOME: sel = 0; break;
        case K_END:  sel = n - 1; break;
        case K_PGUP: sel = sel - visible < 0 ? 0 : sel - visible; break;
        case K_PGDN: sel = sel + visible > n - 1 ? n - 1 : sel + visible; break;
        case K_ENTER:
            erase(visible);
            printf("  > %.*s\n", MAX_LABEL, labels[sel]);
            fflush(stdout);
            *choice = sel;
            return SEL_CHOSEN;
        case K_ESC:
            erase(visible);
            fflush(stdout);
            return SEL_BACK;
        case K_EOF:
            erase(visible);
            fflush(stdout);
            return SEL_EOF;
        default:
            if (key >= 32 && key <= 126) {
                erase(visible);
                fflush(stdout);
                *typed_char = key;
                return SEL_TYPED;
            }
            continue; /* unknown key: ignore */
        }
        if (sel < top) top = sel;
        if (sel >= top + visible) top = sel - visible + 1;
        draw(labels, n, visible, top, sel, 1);
    }
}