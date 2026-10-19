/* converter: Unit Converter engine (spec 5). Pure logic, no I/O.
 * Units live in a data table (units.c); adding a unit is a data change. */
#ifndef ARITHMOS_CONVERTER_H
#define ARITHMOS_CONVERTER_H

#include "shared/shared.h"

typedef struct {
    const char *symbol; /* lowercase, unique across all categories */
    const char *name;
    double factor;      /* base units per one of this unit (unused for temperature) */
} ConvUnit;

typedef struct {
    const char *name;
    const char *base_unit;
    const ConvUnit *units;
    int unit_count;
    int is_temperature;
} ConvCategory;

int conv_category_count(void);
const ConvCategory *conv_category(int index);

/* Case-insensitive symbol lookup across all categories. Returns 0 if found. */
int conv_find_unit(const char *symbol, int *category_index, int *unit_index);

/* Convert `value_text` from one unit to another and write the formatted number.
 * `to` may be "all": one "<symbol>: <value>" line per unit of the source's
 * category, in table order. Returns 0 or -1 (err filled, out emptied). */
int conv_convert(const char *value_text, const char *from, const char *to,
                 char *out, size_t cap, ArError *err);

/* Run a one-line command: `[convert] <value> <from> <to|all>`, `list`,
 * `list <category>`. Returns 0 or -1. */
int conv_run_line(const char *line, char *out, size_t cap, ArError *err);

#endif
