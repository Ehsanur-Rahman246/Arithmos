/*
 * Standard Calculator: tokenize -> parse (AST) -> evaluate -> format.
 *
 * Grammar, lowest to highest precedence (spec 3.3):
 *   additive       := multiplicative (('+' | '-') multiplicative)*
 *   multiplicative := unary (('*' | '/' | 'of') unary)*
 *   unary          := ('+' | '-') unary | power
 *   power          := postfix ['^' unary]          (right-associative)
 *   postfix        := primary '%'*
 *   primary        := number | ans | ('sqrt'|'abs') '(' additive ')' | '(' additive ')'
 *
 * A '%' that is the *direct* right operand of '+' or '-' is relative to the
 * left operand; anywhere else it is value / 100 (spec 3.4, amendments R1-R4).
 */
#include "calculator/calculator.h"

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_DEPTH 200

/* ---------- tokenizer ---------- */

typedef enum {
    T_NUM, T_PLUS, T_MINUS, T_STAR, T_SLASH, T_CARET, T_LPAREN, T_RPAREN,
    T_PERCENT, T_SQRT, T_ABS, T_ANS, T_OF, T_END
} TokType;

typedef struct {
    TokType type;
    double num;
    const char *text;
    size_t len;
} Token;

static int is_digit(int c) { return c >= '0' && c <= '9'; }
static int is_alpha(int c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }

static int word_is(const char *text, size_t len, const char *kw)
{
    size_t i;
    for (i = 0; i < len; i++) {
        if (kw[i] == '\0' || tolower((unsigned char)text[i]) != kw[i]) return 0;
    }
    return kw[len] == '\0';
}

static int tokenize(const char *s, Token *toks, size_t *count, ArError *err)
{
    size_t n = 0;
    const char *p = s;

    while (*p) {
        unsigned char c = (unsigned char)*p;
        Token *t = &toks[n];
        if (isspace(c)) { p++; continue; }
        t->text = p;
        t->num = 0;

        if (is_digit(c) || c == '.') {
            int digits = 0;
            size_t len;
            char *tmp;
            while (is_digit((unsigned char)*p)) { p++; digits++; }
            if (*p == '.') {
                p++;
                while (is_digit((unsigned char)*p)) { p++; digits++; }
            }
            if (digits == 0) /* a lone "."; "5.5.5" is 5.5 then .5 and fails in the parser */
                return ar_error_set(err, AR_INVALID_EXPRESSION, "Unexpected character '.'");
            len = (size_t)(p - t->text);
            tmp = (char *)malloc(len + 1);
            if (!tmp) return ar_error_set(err, AR_INVALID_EXPRESSION, "Out of memory");
            memcpy(tmp, t->text, len);
            tmp[len] = '\0';
            t->num = strtod(tmp, NULL);
            free(tmp);
            t->type = T_NUM;
            t->len = len;
            n++;
            continue;
        }

        if (is_alpha(c)) {
            size_t len;
            p++;
            while (is_alpha((unsigned char)*p) || is_digit((unsigned char)*p) || *p == '_') p++;
            len = (size_t)(p - t->text);
            t->len = len;
            if (word_is(t->text, len, "sqrt")) t->type = T_SQRT;
            else if (word_is(t->text, len, "abs")) t->type = T_ABS;
            else if (word_is(t->text, len, "ans")) t->type = T_ANS;
            else if (word_is(t->text, len, "of")) t->type = T_OF;
            else return ar_error_set(err, AR_INVALID_EXPRESSION, "Unknown word '%.*s'", (int)len, t->text);
            n++;
            continue;
        }

        t->len = 1;
        switch (c) {
        case '+': t->type = T_PLUS; break;
        case '-': t->type = T_MINUS; break;
        case '*': t->type = T_STAR; break;
        case '/': t->type = T_SLASH; break;
        case '^': t->type = T_CARET; break;
        case '(': t->type = T_LPAREN; break;
        case ')': t->type = T_RPAREN; break;
        case '%': t->type = T_PERCENT; break;
        default: {
            int k = c >= 0xF0 ? 4 : c >= 0xE0 ? 3 : c >= 0xC0 ? 2 : 1, i;
            for (i = 1; i < k; i++)
                if (((unsigned char)p[i] & 0xC0) != 0x80) { k = 1; break; }
            return ar_error_set(err, AR_INVALID_EXPRESSION, "Unexpected character '%.*s'", k, p);
        }
        }
        p++;
        n++;
    }
    toks[n].type = T_END;
    toks[n].text = p;
    toks[n].len = 0;
    toks[n].num = 0;
    *count = n;
    return 0;
}

/* ---------- AST ---------- */

typedef enum {
    N_NUM, N_ANS, N_PCT, N_NEG, N_POS, N_GROUP, N_SQRT, N_ABS,
    N_ADD, N_SUB, N_MUL, N_DIV, N_POW
} NodeType;

typedef struct Node {
    NodeType type;
    double num;
    struct Node *l, *r;
} Node;

typedef struct {
    const Token *toks;
    size_t pos;
    Node *pool;
    size_t used;
    int depth;
    ArError *err;
} Parser;

static Node *new_node(Parser *P, NodeType type, Node *l, Node *r)
{
    Node *n = &P->pool[P->used++];
    n->type = type;
    n->num = 0;
    n->l = l;
    n->r = r;
    return n;
}

static const Token *cur(const Parser *P) { return &P->toks[P->pos]; }

static Node *parse_additive(Parser *P);

static Node *fail_depth(Parser *P)
{
    ar_error_set(P->err, AR_INVALID_EXPRESSION, "The expression is nested too deeply");
    return NULL;
}

static Node *parse_primary(Parser *P)
{
    const Token *t = cur(P);
    Node *n, *inner;

    switch (t->type) {
    case T_NUM:
        P->pos++;
        n = new_node(P, N_NUM, NULL, NULL);
        n->num = t->num;
        return n;
    case T_ANS:
        P->pos++;
        return new_node(P, N_ANS, NULL, NULL);
    case T_SQRT:
    case T_ABS: {
        const char *fn = t->type == T_SQRT ? "sqrt" : "abs";
        P->pos++;
        if (cur(P)->type != T_LPAREN) {
            ar_error_set(P->err, AR_INVALID_EXPRESSION, "%s needs parentheses, like %s(4)", fn, fn);
            return NULL;
        }
        P->pos++;
        if (++P->depth > MAX_DEPTH) return fail_depth(P);
        inner = parse_additive(P);
        P->depth--;
        if (!inner) return NULL;
        if (cur(P)->type != T_RPAREN) {
            ar_error_set(P->err, AR_INVALID_EXPRESSION, "Missing closing parenthesis");
            return NULL;
        }
        P->pos++;
        return new_node(P, t->type == T_SQRT ? N_SQRT : N_ABS, inner, NULL);
    }
    case T_LPAREN:
        P->pos++;
        if (++P->depth > MAX_DEPTH) return fail_depth(P);
        inner = parse_additive(P);
        P->depth--;
        if (!inner) return NULL;
        if (cur(P)->type != T_RPAREN) {
            ar_error_set(P->err, AR_INVALID_EXPRESSION, "Missing closing parenthesis");
            return NULL;
        }
        P->pos++;
        return new_node(P, N_GROUP, inner, NULL);
    case T_OF:
        ar_error_set(P->err, AR_INVALID_EXPRESSION, "Unexpected 'of'");
        return NULL;
    case T_END:
        ar_error_set(P->err, AR_INVALID_EXPRESSION, "The expression ends too early");
        return NULL;
    default:
        ar_error_set(P->err, AR_INVALID_EXPRESSION, "Unexpected symbol");
        return NULL;
    }
}

static Node *parse_postfix(Parser *P)
{
    Node *n = parse_primary(P);
    while (n && cur(P)->type == T_PERCENT) {
        P->pos++;
        n = new_node(P, N_PCT, n, NULL);
    }
    return n;
}

static Node *parse_unary(Parser *P);

static Node *parse_power(Parser *P)
{
    Node *base = parse_postfix(P), *expo;
    if (!base) return NULL;
    if (cur(P)->type == T_CARET) {
        P->pos++;
        expo = parse_unary(P);
        if (!expo) return NULL;
        return new_node(P, N_POW, base, expo);
    }
    return base;
}

static Node *parse_unary(Parser *P)
{
    TokType t = cur(P)->type;
    Node *child, *n;
    if (t == T_PLUS || t == T_MINUS) {
        P->pos++;
        if (++P->depth > MAX_DEPTH) return fail_depth(P);
        child = parse_unary(P);
        P->depth--;
        if (!child) return NULL;
        n = new_node(P, t == T_MINUS ? N_NEG : N_POS, child, NULL);
        return n;
    }
    return parse_power(P);
}

static Node *parse_multiplicative(Parser *P)
{
    Node *l = parse_unary(P);
    while (l) {
        TokType t = cur(P)->type;
        Node *r;
        if (t != T_STAR && t != T_SLASH && t != T_OF) break;
        P->pos++;
        r = parse_unary(P);
        if (!r) return NULL;
        l = new_node(P, t == T_SLASH ? N_DIV : N_MUL, l, r); /* `of` is sugar for * */
    }
    return l;
}

static Node *parse_additive(Parser *P)
{
    Node *l = parse_multiplicative(P);
    while (l) {
        TokType t = cur(P)->type;
        Node *r;
        if (t != T_PLUS && t != T_MINUS) break;
        P->pos++;
        r = parse_multiplicative(P);
        if (!r) return NULL;
        l = new_node(P, t == T_PLUS ? N_ADD : N_SUB, l, r);
    }
    return l;
}

/* ---------- evaluator ---------- */

typedef struct {
    double v;
    int pct; /* 1 only when the node is a direct percent (not grouped, negated, ...) */
} Val;

static int check_finite(double v, ArError *err)
{
    if (isnan(v)) return ar_error_set(err, AR_DOMAIN_ERROR, "The result is not a number");
    if (isinf(v)) return ar_error_set(err, AR_OVERFLOW, "The result is too large");
    return 0;
}

static int eval(const Node *n, double ans, Val *out, ArError *err)
{
    Val a, b;
    out->pct = 0;

    switch (n->type) {
    case N_NUM:
        out->v = n->num;
        return check_finite(out->v, err);
    case N_ANS:
        out->v = ans;
        return 0;
    case N_PCT:
        if (eval(n->l, ans, &a, err)) return -1;
        out->v = a.v / 100.0;
        out->pct = 1;
        return 0;
    case N_NEG:
        if (eval(n->l, ans, &a, err)) return -1;
        out->v = -a.v;
        return 0;
    case N_POS:
    case N_GROUP:
        if (eval(n->l, ans, &a, err)) return -1;
        out->v = a.v;
        return 0;
    case N_SQRT:
        if (eval(n->l, ans, &a, err)) return -1;
        if (a.v < 0)
            return ar_error_set(err, AR_DOMAIN_ERROR, "Cannot take the square root of a negative number");
        out->v = sqrt(a.v);
        return check_finite(out->v, err);
    case N_ABS:
        if (eval(n->l, ans, &a, err)) return -1;
        out->v = fabs(a.v);
        return 0;
    default:
        break;
    }

    if (eval(n->l, ans, &a, err)) return -1;
    if (eval(n->r, ans, &b, err)) return -1;

    switch (n->type) {
    case N_ADD:
    case N_SUB: {
        double rhs = b.pct ? a.v * b.v : b.v; /* relative percent */
        out->v = n->type == N_ADD ? a.v + rhs : a.v - rhs;
        break;
    }
    case N_MUL:
        out->v = a.v * b.v;
        break;
    case N_DIV:
        if (b.v == 0.0) return ar_error_set(err, AR_DIV_BY_ZERO, "Cannot divide by zero");
        out->v = a.v / b.v;
        break;
    case N_POW:
        if (a.v == 0.0 && b.v == 0.0)
            return ar_error_set(err, AR_UNDEFINED, "0^0 is undefined");
        if (a.v == 0.0 && b.v < 0.0)
            return ar_error_set(err, AR_DIV_BY_ZERO, "Zero cannot be raised to a negative power");
        if (a.v < 0.0 && b.v != floor(b.v))
            return ar_error_set(err, AR_DOMAIN_ERROR, "A negative number cannot have a fractional power");
        out->v = pow(a.v, b.v);
        break;
    default:
        return ar_error_set(err, AR_INVALID_EXPRESSION, "Malformed expression");
    }
    return check_finite(out->v, err);
}

/* ---------- public API ---------- */

void calc_session_init(CalcSession *s) { s->ans = 0.0; }

int calc_evaluate(const CalcSession *s, const char *line, double *result, ArError *err)
{
    size_t len = strlen(line), count = 0;
    Token *toks = (Token *)malloc((len + 2) * sizeof *toks);
    Node *pool = (Node *)malloc((len + 2) * sizeof *pool);
    Parser P;
    Node *root;
    Val v;
    int rc = -1;

    if (!toks || !pool) {
        ar_error_set(err, AR_INVALID_EXPRESSION, "Out of memory");
        goto done;
    }
    if (tokenize(line, toks, &count, err)) goto done;
    if (count == 0) {
        ar_error_set(err, AR_INVALID_EXPRESSION, "Nothing to calculate");
        goto done;
    }

    P.toks = toks;
    P.pos = 0;
    P.pool = pool;
    P.used = 0;
    P.depth = 0;
    P.err = err;
    root = parse_additive(&P);
    if (!root) goto done;
    if (cur(&P)->type != T_END) {
        ar_error_set(err, AR_INVALID_EXPRESSION, "Unexpected symbol");
        goto done;
    }
    if (eval(root, s->ans, &v, err)) goto done;
    *result = v.v;
    rc = 0;
done:
    free(toks);
    free(pool);
    return rc;
}

int calc_run(CalcSession *s, const char *line, char *out, size_t cap, ArError *err)
{
    double v;
    if (calc_evaluate(s, line, &v, err)) return -1;
    if (ar_format_number(v, out, cap, err)) return -1;
    s->ans = v;
    return 0;
}
