/* select: optional arrow-key selector for the menus and pickers (spec 2.1).
 * Used only on a real terminal; pipes, files and tests keep the numbered lists. */
#ifndef ARITHMOS_SELECT_H
#define ARITHMOS_SELECT_H

typedef enum {
    SEL_CHOSEN, /* Enter on a row; *choice is set */
    SEL_BACK,   /* Esc */
    SEL_EOF,    /* Ctrl-C, Ctrl-D or closed input */
    SEL_TYPED   /* a printable key was pressed; *typed_char holds it */
} SelResult;

/* Call once at start-up. On Windows consoles it switches output to UTF-8
 * (and restores it on exit) so the em dash and arrows display. */
void term_init(void);

/* 1 when the selector can be used: stdin and stdout are terminals, ANSI escape
 * codes work, and ARITHMOS_PLAIN is not set. */
int sel_enabled(void);

/* Show `labels` as a list, move with Up/Down/Home/End/PgUp/PgDn.
 * *choice is the starting row on entry and the chosen row on SEL_CHOSEN. */
SelResult sel_run(const char *title, int n, const char *const *labels,
                  int *choice, int *typed_char);

#endif