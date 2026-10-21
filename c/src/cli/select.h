/* select: optional arrow-key selector for the menus and pickers (spec 2.1).
 *
 * Layers, like the JavaScript and Python editions:
 *   sel_apply_key  key handling   (pure)
 *   sel_render     drawing        (pure: builds the lines of text)
 *   sel_loop       draw/read loop over an injectable keyboard and screen (SelIo)
 *   sel_run        sel_loop on the real terminal
 * Used only on a real terminal; pipes, files and tests keep the numbered lists. */
#ifndef ARITHMOS_SELECT_H
#define ARITHMOS_SELECT_H

#include <stddef.h>

typedef enum {
    SEL_CHOSEN,   /* Enter on a row */
    SEL_BACK,     /* Esc or b, when back is offered */
    SEL_QUIT,     /* q, when quit is offered */
    SEL_EOF,      /* Ctrl-C, Ctrl-D or closed input */
    SEL_TYPED,    /* typing is on and a printable key was pressed */
    SEL_CONTINUE  /* sel_apply_key only: the key did not end the selector */
} SelResult;

/* Key codes. Visible ASCII characters (33..126) are their own code. */
enum {
    SEL_KEY_UP = 1000, SEL_KEY_DOWN, SEL_KEY_HOME, SEL_KEY_END, SEL_KEY_PGUP, SEL_KEY_PGDN,
    SEL_KEY_ENTER, SEL_KEY_ESC, SEL_KEY_ABORT, SEL_KEY_OTHER
};

#define SEL_OFFER_BACK 1u /* Esc / b go back */
#define SEL_OFFER_QUIT 2u /* q quits */
#define SEL_TYPING     4u /* other printable keys start a typed line */
#define SEL_WINDOW     10 /* rows shown at once */

typedef struct {
    int index, offset, count, size;
} SelState;

void sel_state_init(SelState *s, int count, int start);

/* Apply one key. Returns SEL_CONTINUE, or the result that ends the selector.
 * For SEL_TYPED, *typed_char is the character (when typed_char is not NULL). */
SelResult sel_apply_key(SelState *s, int key, unsigned flags, int *typed_char);

/* Build the lines of the list into buf: title, the visible rows (the selected
 * one as a full bar), "N of M" when the list scrolls, and a hint line. Every
 * line ends with '\n'. Returns the number of lines. */
int sel_render(char *buf, size_t cap, const char *title, const char *const *labels,
               const SelState *s, unsigned flags, int colour);

/* The keyboard and screen the loop talks to. */
typedef struct {
    int (*read_key)(void *ctx);                /* next key code; SEL_KEY_ABORT at end of input */
    void (*write)(void *ctx, const char *text);
    void *ctx;
} SelIo;

/* Draw, read keys, return the result. *choice is the starting row on entry and the
 * chosen row on SEL_CHOSEN. Hides the cursor while open, restores it on every exit,
 * and leaves "✔ <title>: <label>" behind when a row is chosen. */
SelResult sel_loop(const SelIo *io, const char *title, int n, const char *const *labels,
                   unsigned flags, int colour, int *choice, int *typed_char);

/* Call once at start-up. On Windows consoles it switches output to UTF-8
 * (and restores it on exit) so the arrows and the em dash display. */
void term_init(void);

/* 1 when the selector can be used: stdin and stdout are terminals, ANSI escape
 * codes work, and ARITHMOS_PLAIN is not set. */
int sel_enabled(void);

/* sel_loop on the real terminal. */
SelResult sel_run(const char *title, int n, const char *const *labels, unsigned flags,
                  int *choice, int *typed_char);

#endif
