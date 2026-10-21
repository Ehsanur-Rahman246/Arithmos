/* pick: one question, many answers (the C counterpart of pick.js / pick.py).
 * With a selector: Esc / b go back and q quits at once; any other printable key opens a
 * typed line. Without one (pipes, files, tests): a numbered list answered by typing.
 * Either way a typed line can be a number, a name or symbol, a one-line command, or
 * back / quit / help. All input and output goes through PickIo, so it can be tested. */
#ifndef ARITHMOS_PICK_H
#define ARITHMOS_PICK_H

#include "cli/select.h"
#include "shared/shared.h"

typedef enum { PICK_CHOSEN = 0, PICK_BACK = 1, PICK_QUIT = 2, PICK_EOF = 3 } PickStatus;

typedef struct {
    /* NULL when there is no arrow-key selector. */
    SelResult (*select)(void *ctx, const char *title, int n, const char *const *labels,
                        unsigned flags, int *choice, int *typed_char);
    /* Show `prompt`, read one line. first >= 0 is a key already typed in the selector: it is
     * shown after the prompt and becomes the start of the line. Returns 0 at end of input. */
    int (*read_line)(void *ctx, const char *prompt, int first, char *buf, size_t cap);
    void (*write)(void *ctx, const char *text);
    void *ctx;
} PickIo;

typedef struct {
    const char *title;
    int n;
    const char *const *labels;   /* what is shown */
    const char *const *keys;     /* names or symbols accepted when typed (may be NULL) */
    const char *const *numbers;  /* typed numbers; NULL means "1".."n" */
    unsigned flags;              /* SEL_OFFER_BACK, SEL_OFFER_QUIT (typing is implied) */
    const char *prompt;          /* e.g. "converter> " */
    /* Optional: runs a typed one-line command; returns 0 with `out`, or -1 with `err`. */
    int (*command)(const char *line, char *out, size_t cap, ArError *err);
} PickSpec;

/* Returns the status; on PICK_CHOSEN *choice is the row. *choice also sets the starting row. */
PickStatus pick(const PickIo *io, const PickSpec *spec, int *choice);

#endif
