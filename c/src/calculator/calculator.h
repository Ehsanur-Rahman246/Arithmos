/* calculator: Standard Calculator engine (spec 3). Pure logic, no I/O. */
#ifndef ARITHMOS_CALCULATOR_H
#define ARITHMOS_CALCULATOR_H

#include "shared/shared.h"

typedef struct {
    double ans; /* last successful result; 0 before the first calculation */
} CalcSession;

void calc_session_init(CalcSession *s);

/* Evaluate one expression. Returns 0 and fills *result, or -1 and fills *err.
 * Does not change the session. */
int calc_evaluate(const CalcSession *s, const char *line, double *result, ArError *err);

/* Evaluate and format. On success writes the display string to out and updates
 * `ans`; on failure `ans` is unchanged. Returns 0 or -1. */
int calc_run(CalcSession *s, const char *line, char *out, size_t cap, ArError *err);

#endif
