/* programmer: Programmer Calculator engine (spec 4). Pure logic, no I/O.
 * Every value is a signed 64-bit two's-complement integer (int64_t). */
#ifndef ARITHMOS_PROGRAMMER_H
#define ARITHMOS_PROGRAMMER_H

#include "shared/shared.h"

typedef struct {
    int input_base; /* 2, 8, 10 or 16; default 10 */
} ProgSession;

typedef enum {
    PROG_RESULT_VALUE, /* hex/dec/oct/bin are filled */
    PROG_RESULT_TEXT   /* text is filled: a conversion result or a status line */
} ProgResultKind;

typedef struct {
    ProgResultKind kind;
    char text[96];
    char hex[24];
    char dec[24];
    char oct[32];
    char bin[72];
} ProgResult;

void prog_session_init(ProgSession *s);

/* Run one line. Returns 0 and fills *res, or -1 and fills *err. */
int prog_execute(ProgSession *s, const char *line, ProgResult *res, ArError *err);

#endif
