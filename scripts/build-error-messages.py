#!/usr/bin/env python3
"""Builds docs/error-messages.md straight from the JavaScript and Python engines.

Every user-facing error in both editions goes through `fail(CODE, message)`, the
parser's `bad(message)`, or the one `ArithmosError(...)` in the pick helper. This
script finds those call sites in the source, normalises the message templates,
checks that the two editions agree, and writes one table (code, situation, wording).

Usage:
  python3 scripts/build-error-messages.py            write docs/error-messages.md
  python3 scripts/build-error-messages.py --check    exit 1 if the file is stale or the editions disagree
  python3 scripts/build-error-messages.py --verify   also run both engines on an example for each
                                                     wording and compare what they really print
                                                     (needs node and python3)

The Situation text and example inputs live in SITUATIONS below. They are the only
hand-written part: a call site with no entry here (or an entry with no call site)
stops the script, so a new error cannot be added to an engine without being
documented.
"""
import difflib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "error-messages.md"
JS_SRC = ROOT / "javascript" / "src"
PY_SRC = ROOT / "python" / "arithmos"

# Spec §2.2 order.
CODE_ORDER = [
    "INVALID_EXPRESSION", "INVALID_NUMBER", "DIV_BY_ZERO", "DOMAIN_ERROR", "UNDEFINED",
    "OVERFLOW", "INVALID_DIGIT", "INVALID_BASE", "OUT_OF_RANGE", "INVALID_SHIFT",
    "UNKNOWN_UNIT", "INCOMPATIBLE_UNITS", "BELOW_ABSOLUTE_ZERO", "UNKNOWN_COMMAND",
]

# (JavaScript file, Python file), relative to each edition's source root. The order is
# the order rows first appear in the table within a code.
MODULES = [
    ("calculator/tokenizer.js", "calculator/tokenizer.py"),
    ("calculator/parser.js", "calculator/parser.py"),
    ("calculator/evaluator.js", "calculator/evaluator.py"),
    ("shared/format-number.js", "shared/format_number.py"),
    ("programmer/parse.js", "programmer/parse.py"),
    ("programmer/index.js", "programmer/__init__.py"),
    ("converter/session.js", "converter/session.py"),
    ("converter/convert.js", "converter/convert.py"),
    ("converter/temperature.js", "converter/temperature.py"),
    ("cli/pick.js", "cli/pick.py"),
]

# ---------------------------------------------------------------- extraction

_JS_STR = r"""'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`"""
_PY_STR = r'''f?"(?:[^"\\\n]|\\.)*"'''
# (regex, fixed code or None to read it from group 1, which group holds the string)
JS_PATTERNS = [
    (re.compile(r"\bfail\(\s*'([A-Z_]+)'\s*,\s*(" + _JS_STR + ")"), None),
    (re.compile(r"\bbad\(\s*(" + _JS_STR + ")"), "INVALID_EXPRESSION"),
    (re.compile(r"new ArithmosError\(\s*errorCode\s*,\s*(" + _JS_STR + ")"), "@pick"),
]
PY_PATTERNS = [
    (re.compile(r'\bfail\(\s*"([A-Z_]+)"\s*,\s*(' + _PY_STR + ")"), None),
    (re.compile(r'\bbad\(\s*(' + _PY_STR + ")"), "INVALID_EXPRESSION"),
    (re.compile(r'ArithmosError\(\s*error_code\s*,\s*(' + _PY_STR + ")"), "@pick"),
]
# Lines that define or forward through the helpers rather than raise an error.
HELPER_LINE = (r"\bdef \w+\(|=>\s*fail|const (?:fail|bad)\b|"
               r"\bfail\(\s*[\"']INVALID_EXPRESSION[\"']\s*,\s*(?:msg|message)\s*\)")
JS_ANY_CALL = re.compile(r"\b(?:fail|bad)\(|new ArithmosError\(\s*errorCode")
PY_ANY_CALL = re.compile(r"\b(?:fail|bad)\(|ArithmosError\(\s*error_code")

# Raw expression inside ${...} / {...}  ->  placeholder name used in the table.
PLACEHOLDERS = {
    "symbol": "input", "text": "input", "name": "input", "category": "input",
    "ch.toUpperCase()": "digit", "ch.upper()": "digit", "base": "base",
    "ch": "char",
    "a.category.name": "from_category", "src[0].name": "from_category",
    "b.category.name": "to_category", "dst[0].name": "to_category",
    "m[0]": "word", "m.group()": "word", "n.op": "op",
}
PLACEHOLDER_HELP = [
    ("input", "The text exactly as the user typed it, case preserved (a unit symbol, base name, category name, or number)."),
    ("word", "An unrecognised or misplaced word from an expression, case preserved."),
    ("char", "The single unexpected character."),
    ("fn", "A function name: `sqrt` or `abs`."),
    ("digit", "The offending digit, uppercased."),
    ("base", "The base being read: `bin`, `oct`, `dec` or `hex`."),
    ("from_category", "Category name of the source unit, lowercase (`length`, `mass`, ...)."),
    ("to_category", "Category name of the target unit, lowercase."),
    ("op", "An operator symbol (JavaScript-only message)."),
]


def _unescape(body, quote):
    return body.replace("\\" + quote, quote).replace("\\\\", "\\")


def _template(literal, js):
    """String literal source text -> canonical template like "Unknown word '{word}'"."""
    if js:
        quote = literal[0]
        body = _unescape(literal[1:-1], quote)
        is_template = quote == "`"
        pat = re.compile(r"\$\{([^}]*)\}")
    else:
        is_f = literal.startswith("f")
        body = _unescape(literal[2:-1] if is_f else literal[1:-1], '"')
        is_template = is_f
        pat = re.compile(r"\{([^}]*)\}")
    if not is_template:
        return body

    def swap(m):
        expr = m.group(1).strip()
        if expr in ("t.value", "value"):  # parser: function name vs stray word
            return "{fn}" if "needs parentheses" in body else "{word}"
        if expr not in PLACEHOLDERS:
            sys.exit(f"error: no placeholder name for expression {expr!r} in message {literal}.\n"
                     f"       Add it to PLACEHOLDERS in {Path(__file__).name}.")
        return "{" + PLACEHOLDERS[expr] + "}"

    return pat.sub(swap, body)


def extract(path, js):
    """-> list of (code, template) in file order. Exits if a call site is not understood."""
    text = path.read_text(encoding="utf-8")
    patterns = JS_PATTERNS if js else PY_PATTERNS
    any_call = JS_ANY_CALL if js else PY_ANY_CALL
    found = []
    for rx, fixed in patterns:
        for m in rx.finditer(text):
            if fixed is None:
                code, lit = m.group(1), m.group(2)
            elif fixed == "@pick":
                code, lit = _pick_default_code(text, js), m.group(1)
            else:
                code, lit = fixed, m.group(1)
            found.append((m.start(), code, _template(lit, js)))
    found.sort()
    # Every call must have matched; helper definitions are not calls.
    calls = sum(1 for line in text.splitlines()
                if not re.search(HELPER_LINE, line)
                for _ in any_call.finditer(line))
    if calls != len(found):
        sys.exit(f"error: {path.relative_to(ROOT)} has {calls} fail()/bad() call(s) but only "
                 f"{len(found)} have a literal message the script understands. A new pattern?")
    return [(c, t) for _, c, t in found]


def _pick_default_code(text, js):
    m = re.search(r"errorCode = '([A-Z_]+)'" if js else r'error_code: str = "([A-Z_]+)"', text)
    if not m:
        sys.exit("error: could not read the default error code of pick()")
    return m.group(1)


def check_pick_not_overridden():
    """pick() takes an error code argument; the table assumes nobody passes one."""
    bad = []
    for path in JS_SRC.rglob("*.js"):
        if path.name != "pick.js" and re.search(r"\berrorCode\s*:", path.read_text(encoding="utf-8")):
            bad.append(path)
    for path in PY_SRC.rglob("*.py"):
        if path.name != "pick.py" and re.search(r"\berror_code\s*=", path.read_text(encoding="utf-8")):
            bad.append(path)
    if bad:
        sys.exit("error: a caller overrides pick()'s error code (" +
                 ", ".join(str(p.relative_to(ROOT)) for p in bad) + "); the table needs a row for it.")


def check_all_files_covered():
    listed = {("js", m[0]) for m in MODULES} | {("py", m[1]) for m in MODULES}
    for kind, base, glob in (("js", JS_SRC, "*.js"), ("py", PY_SRC, "*.py")):
        for path in base.rglob(glob):
            rel = path.relative_to(base).as_posix()
            if (kind, rel) in listed:
                continue
            text = path.read_text(encoding="utf-8")
            rx = JS_ANY_CALL if kind == "js" else PY_ANY_CALL
            if any(rx.search(l) for l in text.splitlines()
                   if not re.search(HELPER_LINE, l)):
                sys.exit(f"error: {path.relative_to(ROOT)} raises errors but is not listed in MODULES.")


# ---------------------------------------------------------------- comparison

def compare():
    """-> (rows, mismatches, only)
    rows:       ordered unique [(code, js_template)] raised by both editions (JS wording is the reference)
    mismatches: [(module, code, js_template, py_template)] same situation, different wording
    only:       [(edition, module, code, template)] present in one edition only
    """
    rows, mismatches, only, seen = [], [], [], set()
    stats = {"js": 0, "py": 0}
    for js_rel, py_rel in MODULES:
        js_all = extract(JS_SRC / js_rel, True)
        py_all = extract(PY_SRC / py_rel, False)
        stats["js"] += len(js_all)
        stats["py"] += len(py_all)
        js_u = list(dict.fromkeys(js_all))
        py_u = list(dict.fromkeys(py_all))
        only_js = [x for x in js_u if x not in py_u]
        only_py = [x for x in py_u if x not in js_u]
        pairs = []
        for x in list(only_js):
            best = max((y for y in only_py if y[0] == x[0]), default=None,
                       key=lambda y: difflib.SequenceMatcher(None, x[1], y[1]).ratio())
            if best and difflib.SequenceMatcher(None, x[1], best[1]).ratio() >= 0.6:
                pairs.append((x, best))
                only_js.remove(x)
                only_py.remove(best)
        for x in js_u:
            if x in py_u or any(p[0] == x for p in pairs):
                if x not in seen:
                    seen.add(x)
                    rows.append(x)
        for a, b in pairs:
            mismatches.append((js_rel, a[0], a[1], b[1]))
        only += [("JavaScript", js_rel, *x) for x in only_js]
        only += [("Python", py_rel, *x) for x in only_py]
    return rows, mismatches, only, stats


# ---------------------------------------------------------------- hand-written part
# (code, wording) -> situation text and examples. Example: (tool, line, {placeholder: value}).
# tool is "std", "prog", "conv", or "menu" (drives the interactive main menu).
# No examples = not reachable through the normal CLI / engine entry points.
SITUATIONS = {
    ("INVALID_EXPRESSION", "Unknown word '{word}'"): (
        "Standard — a word that is not `sqrt`, `abs`, `ans` or `of` (matching is case-insensitive).",
        [("std", "abc", {"word": "abc"})]),
    ("INVALID_EXPRESSION", "Unexpected character '{char}'"): (
        "Standard — a character that is not a digit, letter, `+ - * / ^`, parenthesis or `%`: `2 $ 3`, `=`, `,`.",
        [("std", "2 $ 3", {"char": "$"})]),
    ("INVALID_EXPRESSION", "Nothing to calculate"): (
        "Standard — the engine is handed an empty expression. The CLI ignores blank lines, so only a direct engine call reaches this.",
        [("std", "", {})]),
    ("INVALID_EXPRESSION", "The expression ends too early"): (
        "Standard — the line stops where an operand was required: `2 +`, `3 *`, `-`.",
        [("std", "2 +", {})]),
    ("INVALID_EXPRESSION", "{fn} needs parentheses, like {fn}(4)"): (
        "Standard — `sqrt` or `abs` not followed by `(`: `sqrt 4`.",
        [("std", "sqrt 4", {"fn": "sqrt"})]),
    ("INVALID_EXPRESSION", "Missing closing parenthesis"): (
        "Standard — a `(`, `sqrt(` or `abs(` that is never closed: `(2 + 3`, `sqrt(4`.",
        [("std", "(2 + 3", {}), ("std", "sqrt(4", {})]),
    ("INVALID_EXPRESSION", "Unexpected '{word}'"): (
        "Standard — a keyword where an operand was expected: `of 5`. (`ans`, `sqrt` and `abs` are accepted there.)",
        [("std", "of 5", {"word": "of"})]),
    ("INVALID_EXPRESSION", "Unexpected symbol"): (
        "Standard — a token that cannot start an operand (`)`, `*`, `%`), or tokens left over after a complete expression. Implicit multiplication lands here: `2(3)`, `2 3`.",
        [("std", "2(3)", {}), ("std", ")", {})]),
    ("INVALID_EXPRESSION", "Result is not a number"): (
        "Shared number formatter handed NaN. Unreachable in normal use: the evaluator and converter turn NaN into an error first.",
        []),
    ("INVALID_NUMBER", "'{input}' is not a number"): (
        "Programmer — a literal that is empty after its sign/prefix, or contains a character that is not a letter or digit: `1.5`, `-`, `FF!`. "
        "Converter — a value that is not a plain decimal: `abc`, `1e3`, `1,000`.",
        [("prog", "1.5", {"input": "1.5"}), ("prog", "-", {"input": "-"}),
         ("conv", "convert abc m cm", {"input": "abc"}), ("conv", "convert 1e3 m cm", {"input": "1e3"})]),
    ("DIV_BY_ZERO", "Cannot divide by zero"): (
        "Standard — the right side of `/` is zero: `10 / 0`, `1 / (2 - 2)`.",
        [("std", "10 / 0", {}), ("std", "1 / (2 - 2)", {})]),
    ("DIV_BY_ZERO", "Zero cannot be raised to a negative power"): (
        "Standard — `0^-1`.",
        [("std", "0^-1", {})]),
    ("DOMAIN_ERROR", "Cannot take the square root of a negative number"): (
        "Standard — `sqrt(-1)`.",
        [("std", "sqrt(-1)", {})]),
    ("DOMAIN_ERROR", "A negative number cannot have a fractional power"): (
        "Standard — a negative base with a non-integer exponent: `(-8)^(1/3)`.",
        [("std", "(-8)^(1/3)", {})]),
    ("DOMAIN_ERROR", "The result is not a number"): (
        "Standard — safety net if an operation produces NaN. No input reaches it today; every NaN-producing case is rejected earlier with a more specific code.",
        []),
    ("UNDEFINED", "0^0 is undefined"): (
        "Standard — `0^0`.",
        [("std", "0^0", {})]),
    ("OVERFLOW", "The result is too large"): (
        "Standard — a result beyond the double-precision range: `10^400`.",
        [("std", "10^400", {})]),
    ("OVERFLOW", "Result is too large to represent"): (
        "Converter — the typed value is fine but the converted result overflows. "
        "(The shared number formatter also raises it for Standard, but the evaluator rejects overflow first.)",
        [("conv", "convert 1" + "0" * 300 + " ly pm", {})]),
    ("OVERFLOW", "That number is too large"): (
        "Converter — the typed value itself exceeds the double-precision range (about 309+ digits).",
        [("conv", "convert 1" + "0" * 400 + " m cm", {})]),
    ("INVALID_DIGIT", "'{digit}' is not a {base} digit"): (
        "Programmer — a digit that does not exist in the base being read: `2` in binary, `8` in octal, `G` in hex. A prefix chooses the base (`0b102`).",
        [("prog", "convert 102 bin dec", {"digit": "2", "base": "bin"}),
         ("prog", "convert G hex dec", {"digit": "G", "base": "hex"})]),
    ("INVALID_BASE", "'{input}' is not a base. Use bin, oct, dec or hex"): (
        "Programmer — an unknown base name in `base <name>` or `convert <value> <from> <to>`.",
        [("prog", "base xyz", {"input": "xyz"})]),
    ("INVALID_BASE", "Use: base bin | oct | dec | hex"): (
        "Programmer — `base` with no name, or with extra words.",
        [("prog", "base", {})]),
    ("OUT_OF_RANGE", "That number does not fit in 64 bits"): (
        "Programmer — a decimal above 9223372036854775807, or any literal with a leading `-` whose magnitude exceeds 2^63.",
        [("prog", "9223372036854775808", {}), ("prog", "-9223372036854775809", {})]),
    ("OUT_OF_RANGE", "That number needs more than 64 bits"): (
        "Programmer — a bin/oct/hex literal without a minus sign that is wider than 64 bits: `0x10000000000000000`.",
        [("prog", "0x10000000000000000", {})]),
    ("INVALID_SHIFT", "A shift count must be a whole number from 0 to 63"): (
        "Programmer — a shift count that is negative, above 63, or not a plain decimal integer: `1 << 64`, `1 << -1`, `1 << 2.5`.",
        [("prog", "1 << 64", {}), ("prog", "1 << -1", {})]),
    ("UNKNOWN_UNIT", "'{input}' is not a known unit. Try: list"): (
        "Converter — a unit symbol that is not in the tables (`pascal`, `xyz`).",
        [("conv", "convert 5 xyz m", {"input": "xyz"})]),
    ("INCOMPATIBLE_UNITS", "Cannot convert {from_category} to {to_category}"): (
        "Converter — source and target units are in different categories: `convert 5 m kg`.",
        [("conv", "convert 5 m kg", {"from_category": "length", "to_category": "mass"})]),
    ("BELOW_ABSOLUTE_ZERO", "That is below absolute zero"): (
        "Converter — a temperature below 0 K, -273.15 C or -459.67 F, as the input of `convert` or of the `all` target.",
        [("conv", "convert -1 k c", {}), ("conv", "convert -1 k all", {})]),
    ("UNKNOWN_COMMAND", "Type a number or a command. Try help"): (
        "Programmer — the engine is handed an empty line. The CLI ignores blank lines, so only a direct engine call reaches this.",
        [("prog", "", {})]),
    ("UNKNOWN_COMMAND", "Use: convert <value> <from> <to>"): (
        "Programmer and Converter — `convert` with the wrong number of arguments: `convert 1 dec`, `convert 1 m`.",
        [("prog", "convert 1 dec", {}), ("conv", "convert 1 m", {})]),
    ("UNKNOWN_COMMAND", "Use: NOT <value>"): (
        "Programmer — `NOT` with no operand or with extra words.",
        [("prog", "NOT", {})]),
    ("UNKNOWN_COMMAND", "Not a command. Try help"): (
        "Programmer — a line that matches no pattern: `1 foo 2`, `5 AND`.",
        [("prog", "1 foo 2", {}), ("prog", "5 AND", {})]),
    ("UNKNOWN_COMMAND", "Type a value, e.g. 100"): (
        "Converter — the engine is handed an empty line. The CLI ignores blank lines, so only a direct engine call reaches this.",
        [("conv", "", {})]),
    ("UNKNOWN_COMMAND", "Use: list  or  list <category>"): (
        "Converter — `list` with more than one argument. (The two spaces are part of the wording.)",
        [("conv", "list a b", {})]),
    ("UNKNOWN_COMMAND", "Not a command. Try: convert 100 cm in"): (
        "Converter — a line that does not start with `convert` or `list` and is not exactly `<value> <from> <to>`: `foo bar`.",
        [("conv", "foo bar", {})]),
    ("UNKNOWN_COMMAND", "'{input}' is not a category. Try: list"): (
        "Converter — `list <name>` where the name is not one of the twelve categories.",
        [("conv", "list foo", {"input": "foo"})]),
    ("UNKNOWN_COMMAND", "Pick one from the list"): (
        "Main menu and the converter's guided pickers — the typed answer matches no option and is not a one-line command.",
        [("menu", "zzz", {})]),
}

# Wording that only one edition has. Shown in "Where the editions differ".
ENGINE_ONLY_NOTES = {
    ("INVALID_EXPRESSION", "Unknown operator {op}"):
        "Defensive branch for an AST node the parser cannot produce. Python's evaluator has no such branch. New languages do not need it.",
    ("INVALID_EXPRESSION", "Malformed expression"):
        "Defensive branch for an unknown AST node type. Python's evaluator has no such branch. New languages do not need it.",
}


# ---------------------------------------------------------------- rendering

def cell(text):
    return text.replace("|", "\\|")


def code_span(text):
    return "`" + cell(text) + "`"


def render(rows, mismatches, only, stats):
    row_keys = set(rows)
    missing = [k for k in rows if k not in SITUATIONS]
    stale = [k for k in SITUATIONS if k not in row_keys]
    if missing or stale:
        for k in missing:
            print(f"error: no SITUATIONS entry for {k}", file=sys.stderr)
        for k in stale:
            print(f"error: SITUATIONS entry has no call site in both engines: {k}", file=sys.stderr)
        sys.exit(2)
    for code, _ in rows:
        if code not in CODE_ORDER:
            sys.exit(f"error: {code} is not one of the spec §2.2 codes")

    mismatch_keys = {(c, j) for _, c, j, _ in mismatches}
    by_code = {c: [] for c in CODE_ORDER}
    for code, tmpl in rows:
        by_code[code].append(tmpl)

    out = []
    w = out.append
    w("# Arithmos — Error Messages\n")
    w("> **Generated file — do not edit by hand.** Regenerate with `python3 scripts/build-error-messages.py`.")
    w("> It is built from the error call sites in the JavaScript and Python editions; see the end of this file for what was compared.\n")
    w("Every error prints as one line:\n")
    w("```text\nError [CODE]: wording\n```\n")
    w("**Tests check the code, never the wording** (spec §2.2, amendment R26). Even so, a new language should copy the wording below, "
      "so that all editions read the same to a user. Wording in `{braces}` is a placeholder for the value shown in the key below; "
      "everything else is literal, including punctuation and spacing.\n")
    w("The JavaScript edition is the reference. Where the editions disagree, the row shows the JavaScript wording and is marked †.\n")
    w("## Placeholders\n")
    w("| Placeholder | Meaning |\n|---|---|")
    for name, meaning in PLACEHOLDER_HELP:
        w(f"| `{{{name}}}` | {cell(meaning)} |")
    w("")
    w("## Messages\n")
    w("| Code | Situation | Wording |\n|---|---|---|")
    for code in CODE_ORDER:
        for tmpl in by_code[code]:
            situation, _ = SITUATIONS[(code, tmpl)]
            mark = " †" if (code, tmpl) in mismatch_keys else ""
            w(f"| `{code}` | {cell(situation)} | {code_span(tmpl)}{mark} |")
    w("")
    unused = [c for c in CODE_ORDER if not by_code[c]]
    if unused:
        w("Codes with no message in either edition: " + ", ".join(f"`{c}`" for c in unused) + ".\n")

    w("## Outside the spec code list\n")
    w("Both editions print `Error [INTERNAL]: <detail>` if an unexpected exception escapes an engine, and keep the prompt loop running. "
      "`INTERNAL` is not a spec §2.2 code, no shared test expects it, and a new language does not need to reproduce it.\n")

    w("## Where the editions differ\n")
    if not mismatches and not only:
        w("Nothing: both editions raise the same codes with the same wording at every call site.\n")
    if mismatches:
        w("**Same situation, different wording** (the table above shows the JavaScript wording):\n")
        w("| Code | Module | JavaScript | Python |\n|---|---|---|---|")
        for module, code, js_t, py_t in mismatches:
            w(f"| `{code}` | `{module}` | {code_span(js_t)} | {code_span(py_t)} |")
        w("")
    if only:
        w("**Present in one edition only** (not in the table above; a new language does not need these):\n")
        w("| Edition | Code | Wording | Note |\n|---|---|---|---|")
        for edition, module, code, tmpl in only:
            note = ENGINE_ONLY_NOTES.get((code, tmpl), f"Only in `{module}`.")
            w(f"| {edition} | `{code}` | {code_span(tmpl)} | {cell(note)} |")
        w("")

    w("## What was compared\n")
    w(f"{len(rows)} distinct wordings across {len(MODULES)} module pairs. "
      f"Call sites found: {stats['js']} in JavaScript, {stats['py']} in Python. "
      "`python3 scripts/build-error-messages.py --verify` runs both engines on at least one example for each reachable wording "
      "and checks the real output against this table.")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- verification

def fill(tmpl, values):
    out = tmpl
    for k, v in values.items():
        out = out.replace("{" + k + "}", v)
    if re.search(r"\{[a-z_]+\}", out):
        sys.exit(f"error: example for {tmpl!r} does not fill every placeholder ({values})")
    return out


def run_js(cases):
    """cases: [(tool, line)] -> [(code, message) | ('OK', output)] from the JavaScript engines."""
    code = r"""
import { pathToFileURL } from 'node:url';
const root = process.env.ARITHMOS_ROOT;
const imp = (p) => import(pathToFileURL(root + '/javascript/src/' + p).href);
const { createStandardSession } = await imp('calculator/index.js');
const { createProgrammerSession } = await imp('programmer/index.js');
const { createConverterSession } = await imp('converter/session.js');
let input = '';
for await (const chunk of process.stdin) input += chunk;
const out = [];
for (const [tool, line] of JSON.parse(input)) {
  try {
    const s = tool === 'std' ? createStandardSession() : tool === 'prog' ? createProgrammerSession() : createConverterSession();
    s.run(line);
    out.push(['OK', '']);
  } catch (e) { out.push([e.code ?? 'CRASH', e.message]); }
}
console.log(JSON.stringify(out));
"""
    env = dict(os.environ, ARITHMOS_ROOT=str(ROOT))
    p = subprocess.run(["node", "--input-type=module", "-e", code], input=json.dumps(cases),
                       capture_output=True, text=True, env=env)
    if p.returncode != 0:
        sys.exit("error: node failed:\n" + p.stderr)
    return json.loads(p.stdout)


def run_py(cases):
    sys.path.insert(0, str(ROOT / "python"))
    from arithmos.calculator import StandardSession # pyright: ignore[reportMissingImports]
    from arithmos.programmer import ProgrammerSession # pyright: ignore[reportMissingImports]
    from arithmos.converter.session import ConverterSession # pyright: ignore[reportMissingImports]
    out = []
    for tool, line in cases:
        s = {"std": StandardSession, "prog": ProgrammerSession, "conv": ConverterSession}[tool]()
        try:
            s.run(line)
            out.append(["OK", ""])
        except Exception as e:  # noqa: BLE001
            out.append([getattr(e, "code", "CRASH"), getattr(e, "message", str(e))])
    return out


def run_menu(edition, line):
    stdin = f"{line}\nquit\n"
    if edition == "js":
        p = subprocess.run(["node", str(ROOT / "javascript" / "bin" / "arithmos.js")], input=stdin,
                           capture_output=True, text=True)
    else:
        p = subprocess.run([sys.executable, "-m", "arithmos"], input=stdin, capture_output=True,
                           text=True, cwd=ROOT / "python")
    m = re.search(r"Error \[([A-Z_]+)\]: (.*)", p.stdout)
    return [m.group(1), m.group(2).strip()] if m else ["NONE", p.stdout[-200:]]


def verify(rows):
    plan = []  # (code, tmpl, tool, line, expected_message)
    for code, tmpl in rows:
        for tool, line, values in SITUATIONS[(code, tmpl)][1]:
            plan.append((code, tmpl, tool, line, fill(tmpl, values)))
    engine = [(i, p) for i, p in enumerate(plan) if p[2] != "menu"]
    cases = [(p[2], p[3]) for _, p in engine]
    js, py = run_js(cases), run_py(cases)
    results = {}
    for (i, _), j, y in zip(engine, js, py):
        results[i] = {"JavaScript": j, "Python": y}
    for i, p in enumerate(plan):
        if p[2] == "menu":
            results[i] = {"JavaScript": run_menu("js", p[3]), "Python": run_menu("py", p[3])}
    failures = 0
    for i, (code, tmpl, tool, line, expected) in enumerate(plan):
        for edition, (got_code, got_msg) in results[i].items():
            if (got_code, got_msg) != (code, expected):
                failures += 1
                print(f"MISMATCH [{edition}] {tool} {line[:40]!r}\n"
                      f"   table : Error [{code}]: {expected}\n"
                      f"   engine: Error [{got_code}]: {got_msg}", file=sys.stderr)
    print(f"verified {len(plan)} examples in each of 2 engines "
          f"({len(plan) * 2 - failures} of {len(plan) * 2} matched)")
    return failures == 0


# ---------------------------------------------------------------- main

def main():
    args = set(sys.argv[1:])
    if args - {"--check", "--verify"}:
        sys.exit(__doc__)
    check_pick_not_overridden()
    check_all_files_covered()
    rows, mismatches, only, stats = compare()
    text = render(rows, mismatches, only, stats)

    ok = True
    if "--check" in args:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print(f"{OUT.relative_to(ROOT)} is out of date: run python3 scripts/build-error-messages.py", file=sys.stderr)
            ok = False
    else:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(text, encoding="utf-8")
        print(f"wrote {OUT.relative_to(ROOT)}: {len(rows)} wordings")
    if mismatches:
        print(f"{len(mismatches)} wording mismatch(es) between editions:", file=sys.stderr)
        for module, code, js_t, py_t in mismatches:
            print(f"  [{code}] {module}\n    JS: {js_t}\n    PY: {py_t}", file=sys.stderr)
        if "--check" in args:
            ok = False
    if "--verify" in args:
        ok = verify(rows) and ok
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
    