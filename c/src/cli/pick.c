#include "cli/pick.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>

#define LINE_LEN 4096
#define OUT_LEN 4096

static const char *number_of(const PickSpec *spec, int i, char *buf, size_t cap)
{
    if (spec->numbers) return spec->numbers[i];
    snprintf(buf, cap, "%d", i + 1);
    return buf;
}

static void show_list(const PickIo *io, const PickSpec *spec)
{
    char line[256], num[16];
    int i;
    io->write(io->ctx, spec->title);
    io->write(io->ctx, "\n");
    for (i = 0; i < spec->n; i++) {
        snprintf(line, sizeof line, "  %s) %s\n", number_of(spec, i, num, sizeof num), spec->labels[i]);
        io->write(io->ctx, line);
    }
}

static int has_space(const char *s)
{
    for (; *s; s++) if (isspace((unsigned char)*s)) return 1;
    return 0;
}

static void write_error(const PickIo *io, const ArError *err)
{
    char line[256];
    snprintf(line, sizeof line, "Error [%s]: %s\n", ar_code_name(err->code), err->message);
    io->write(io->ctx, line);
}

PickStatus pick(const PickIo *io, const PickSpec *spec, int *choice)
{
    char line[LINE_LEN], num[16];
    int i;

    if (!io->select) show_list(io, spec);
    for (;;) {
        if (io->select) {
            int typed = 0;
            unsigned flags = (spec->flags & (SEL_OFFER_BACK | SEL_OFFER_QUIT)) | SEL_TYPING;
            SelResult r = io->select(io->ctx, spec->title, spec->n, spec->labels, flags, choice, &typed);
            if (r == SEL_CHOSEN) return PICK_CHOSEN;
            if (r == SEL_BACK) return PICK_BACK;
            if (r == SEL_QUIT) return PICK_QUIT;
            if (r != SEL_TYPED) return PICK_EOF;
            if (!io->read_line(io->ctx, spec->prompt, typed, line, sizeof line)) return PICK_EOF;
        } else if (!io->read_line(io->ctx, spec->prompt, -1, line, sizeof line)) {
            return PICK_EOF;
        }

        if (!line[0]) continue;
        if (!ar_strcasecmp(line, "quit")) return PICK_QUIT;
        if (!ar_strcasecmp(line, "back") && (spec->flags & SEL_OFFER_BACK)) return PICK_BACK;
        if (!ar_strcasecmp(line, "help") || !strcmp(line, "?")) {
            if (!io->select) show_list(io, spec);
            continue;
        }
        for (i = 0; i < spec->n; i++) {
            if (!ar_strcasecmp(line, number_of(spec, i, num, sizeof num)) ||
                (spec->keys && !ar_strcasecmp(line, spec->keys[i])) ||
                !ar_strcasecmp(line, spec->labels[i])) {
                *choice = i;
                return PICK_CHOSEN;
            }
        }
        if (spec->command && (has_space(line) || !ar_strcasecmp(line, "list"))) {
            char out[OUT_LEN];
            ArError err;
            if (spec->command(line, out, sizeof out, &err) == 0) {
                if (out[0]) {
                    io->write(io->ctx, out);
                    io->write(io->ctx, "\n");
                }
            } else {
                write_error(io, &err);
            }
            continue;
        }
        io->write(io->ctx, "Error [UNKNOWN_COMMAND]: Pick one from the list\n");
    }
}
