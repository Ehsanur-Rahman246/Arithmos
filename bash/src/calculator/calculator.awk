# calculator.awk — Standard Calculator engine: tokenize → parse (AST) → evaluate.
# Input  (environment): AR_EXPR (the expression), AR_ANS (previous result).
# Output (one line):    OK<TAB>display<TAB>raw   or   ERR<TAB>CODE<TAB>message
# The expression travels in the environment (never as awk source or -v) so no
# character in it can be interpreted as code or as an escape sequence.

function fail(code, msg) { ERRC = code; ERRM = msg; failed = 1; return 0 }

# ---------------------------------------------------------------- tokenizer
function add_tok(t, v) { ntok++; tt[ntok] = t; tv[ntok] = v }

# Returns 1 on success, 0 (via fail) on a bad character or word.
function tokenize(s,    i, n, c, j, w, lw, dots) {
    ntok = 0; i = 1; n = length(s)
    while (i <= n) {
        c = substr(s, i, 1)
        if (c == " " || c == "\t") { i++; continue }
        if (c ~ /[0-9.]/) {                        # number: 12  12.5  .5  5.
            j = i; dots = 0
            while (j <= n && substr(s, j, 1) ~ /[0-9.]/) {
                if (substr(s, j, 1) == ".") dots++
                j++
            }
            w = substr(s, i, j - i)
            if (dots > 1 || w == ".") return fail("INVALID_EXPRESSION", "Unexpected character '.'")
            add_tok("num", w); i = j; continue
        }
        if (c ~ /[A-Za-z_]/) {                     # word: only sqrt abs ans of
            j = i
            while (j <= n && substr(s, j, 1) ~ /[A-Za-z0-9_]/) j++
            w = substr(s, i, j - i); lw = tolower(w)
            if (lw != "sqrt" && lw != "abs" && lw != "ans" && lw != "of")
                return fail("INVALID_EXPRESSION", "Unknown word '" w "'")
            add_tok("id", lw); i = j; continue
        }
        if (index("+-*/^()%", c) > 0) { add_tok("op", c); i++; continue }
        return fail("INVALID_EXPRESSION", "Unexpected character '" c "'")
    }
    return 1
}

# ------------------------------------------------------------------- parser
# Grammar (spec §3.3, high to low):
#   primary : number | ans | (expr) | sqrt(expr) | abs(expr)
#   post    : primary '%'*
#   pow     : post [ '^' unary ]          right-associative, exponent may be signed
#   unary   : ('-'|'+') unary | pow       so -2^2 = -(2^2)
#   mul     : unary (('*'|'/'|'of') unary)*
#   add     : mul (('+'|'-') mul)*
# AST nodes live in parallel arrays: kind nk[], value nv[], children na[] nb[].
# A parenthesised expression is wrapped in a "group" node, so 200 + (10%) is plain.

function newnode(k, v, a, b) { nn++; nk[nn] = k; nv[nn] = v; na[nn] = a; nb[nn] = b; return nn }
function is_op(o) { return (pos <= ntok && tt[pos] == "op" && tv[pos] == o) }

function p_add(    l, r, o) {
    l = p_mul(); if (!l) return 0
    while (is_op("+") || is_op("-")) {
        o = tv[pos]; pos++
        r = p_mul(); if (!r) return 0
        l = newnode("bin", o, l, r)
    }
    return l
}

function p_mul(    l, r, o) {
    l = p_unary(); if (!l) return 0
    while (is_op("*") || is_op("/") || (pos <= ntok && tt[pos] == "id" && tv[pos] == "of")) {
        o = (tv[pos] == "of") ? "*" : tv[pos]      # "of" is sugar for *
        pos++
        r = p_unary(); if (!r) return 0
        l = newnode("bin", o, l, r)
    }
    return l
}

function p_unary(    o, r) {
    if (is_op("-") || is_op("+")) {
        o = tv[pos]; pos++
        r = p_unary(); if (!r) return 0
        return newnode("un", o, r, 0)
    }
    return p_pow()
}

function p_pow(    b, e) {
    b = p_post(); if (!b) return 0
    if (is_op("^")) {
        pos++
        e = p_unary(); if (!e) return 0            # 2^3^2 = 2^(3^2); 2^-1 allowed
        return newnode("bin", "^", b, e)
    }
    return b
}

function p_post(    n) {
    n = p_primary(); if (!n) return 0
    while (is_op("%")) { pos++; n = newnode("pct", "", n, 0) }   # 50%% is allowed
    return n
}

function p_primary(    t, v, r) {
    if (pos > ntok) return fail("INVALID_EXPRESSION", "The expression ends too early")
    t = tt[pos]; v = tv[pos]
    if (t == "num") { pos++; return newnode("num", v + 0, 0, 0) }
    if (t == "id") {
        if (v == "ans") { pos++; return newnode("ans", "", 0, 0) }
        if (v == "sqrt" || v == "abs") {
            pos++
            if (!is_op("(")) return fail("INVALID_EXPRESSION", v " needs parentheses, like " v "(4)")
            pos++
            r = p_add(); if (!r) return 0
            if (!is_op(")")) return fail("INVALID_EXPRESSION", "Missing closing parenthesis")
            pos++
            return newnode("fn", v, r, 0)
        }
        return fail("INVALID_EXPRESSION", "Unexpected '" v "'")      # a stray "of"
    }
    if (v == "(") {
        pos++
        r = p_add(); if (!r) return 0
        if (!is_op(")")) return fail("INVALID_EXPRESSION", "Missing closing parenthesis")
        pos++
        return newnode("group", "", r, 0)
    }
    return fail("INVALID_EXPRESSION", "Unexpected symbol")
}

# ---------------------------------------------------------------- evaluator
# Every arithmetic result passes through chk(): NaN → DOMAIN_ERROR, ±Infinity → OVERFLOW.
function chk(v) {
    if (v != v) return fail("DOMAIN_ERROR", "The result is not a number")
    if (ar_isbad(v)) return fail("OVERFLOW", "The result is too large")
    return v
}

function power(a, b,    r) {
    if (a == 0 && b == 0) return fail("UNDEFINED", "0^0 is undefined")
    if (a == 0 && b < 0)  return fail("DIV_BY_ZERO", "Zero cannot be raised to a negative power")
    if (a < 0 && b != int(b)) return fail("DOMAIN_ERROR", "A negative number cannot have a fractional power")
    r = a ^ b
    return chk(r)
}

function ev(n,    k, a, b, o) {
    k = nk[n]
    if (k == "num") {
        if (ar_isbad(nv[n])) return fail("OVERFLOW", "That number is too large")
        return nv[n]
    }
    if (k == "ans")   return ANS
    if (k == "group") return ev(na[n])
    if (k == "pct")   { a = ev(na[n]); if (failed) return 0; return chk(a / 100) }
    if (k == "un")    { a = ev(na[n]); if (failed) return 0; return (nv[n] == "-") ? -a : a }
    if (k == "fn") {
        a = ev(na[n]); if (failed) return 0
        if (nv[n] == "abs") return (a < 0) ? -a : a
        if (a < 0) return fail("DOMAIN_ERROR", "Cannot take the square root of a negative number")
        return sqrt(a)
    }
    o = nv[n]                                       # binary operator
    a = ev(na[n]); if (failed) return 0
    b = ev(nb[n]); if (failed) return 0
    if (o == "+" || o == "-") {
        # Spec §3.4: a % that is the DIRECT right operand of + or - is relative to the left.
        if (nk[nb[n]] == "pct") b = a * b           # b is already pct/100
        return chk(o == "+" ? a + b : a - b)
    }
    if (o == "*") return chk(a * b)
    if (o == "/") {
        if (b == 0) return fail("DIV_BY_ZERO", "Cannot divide by zero")
        return chk(a / b)
    }
    return power(a, b)                              # o == "^"
}

BEGIN {
    ANS = ENVIRON["AR_ANS"] + 0
    ok = tokenize(ENVIRON["AR_EXPR"])
    if (ok && ntok == 0) ok = fail("INVALID_EXPRESSION", "Nothing to calculate")
    if (ok) { pos = 1; root = p_add(); ok = (root != 0) }
    if (ok && pos <= ntok) ok = fail("INVALID_EXPRESSION", "Unexpected symbol")  # 2(3), 2 3
    if (ok) { v = ev(root); ok = !failed }
    if (ok) printf "OK\t%s\t%.17g\n", ar_format(v), v    # raw value keeps full precision for ans
    else    printf "ERR\t%s\t%s\n", ERRC, ERRM
    exit
}