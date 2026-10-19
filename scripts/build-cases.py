#!/usr/bin/env python3
"""Builds docs/release-1-cases.json from the Section 8 tables of the Release 1 spec.
Usage: python3 scripts/build-cases.py <release-1.md> <out.json>"""
import json, re, sys

ERRORS = {"INVALID_EXPRESSION","INVALID_NUMBER","DIV_BY_ZERO","DOMAIN_ERROR","UNDEFINED","OVERFLOW",
          "INVALID_DIGIT","INVALID_BASE","OUT_OF_RANGE","INVALID_SHIFT","UNKNOWN_UNIT",
          "INCOMPATIBLE_UNITS","BELOW_ABSOLUTE_ZERO","UNKNOWN_COMMAND"}
bt = lambda s: re.findall(r"`([^`]*)`", s)
TOOL = {"S": "standard", "P": "programmer", "C": "converter"}

cases = []
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r"^\|\s*([SPC]\d+)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*$", line)
    if not m:
        continue
    cid, inp, exp = m.groups()
    case = {"id": cid, "tool": TOOL[cid[0]]}
    if cid == "S32":
        a, b = bt(inp); e1, e2 = bt(exp)
        case["steps"] = [{"input": a, "expected": e1}, {"input": b, "expected": e2}]
    elif cid == "S33":
        case["steps"] = [{"input": "7", "expected": "7"},
                         {"input": "10 / 0", "error": "DIV_BY_ZERO"},
                         {"input": "ans", "expected": "7"}]
    else:
        parts = bt(inp)
        case["input"] = parts[0]
        if cid[0] == "P" and len(parts) > 1:
            case["setup"] = [parts[1]]
        ticks = bt(exp)
        if len(ticks) == 1 and ticks[0] in ERRORS:
            case["error"] = ticks[0]
        elif cid in ("C105", "C106"):
            case["expectedContains"] = ticks
        elif cid[0] == "P" and not exp.startswith("`"):
            pairs = dict(re.findall(r"(HEX|DEC|OCT|BIN)\s+`([^`]*)`", exp))
            if "BIN is 64 ones" in exp:
                pairs["BIN"] = "1" * 64
            case["expected"] = pairs
        else:
            case["expected"] = ticks[0]
    cases.append(case)

counts = {t: sum(c["tool"] == t for c in cases) for t in TOOL.values()}
assert counts == {"standard": 33, "programmer": 32, "converter": 110}, counts
assert len({c["id"] for c in cases}) == len(cases), "duplicate case ids"
outcome = lambda x: sum(k in x for k in ("expected", "expectedContains", "error"))
assert all(outcome(s) == 1 for c in cases for s in (c.get("steps") or [c])), "each case or step needs exactly one outcome"
json.dump(cases, open(sys.argv[2], "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print(len(cases), "cases:", {t: sum(c["tool"] == t for c in cases) for t in TOOL.values()})
