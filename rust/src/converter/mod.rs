//! Unit Converter (spec §5): data-driven, `value x from.factor / to.factor`.
pub mod units;

pub use units::{categories, Category, Unit};

use crate::shared::{fail, format_number, Res};

/// Symbols are unique across categories and case-insensitive.
pub fn find_unit(sym: &str) -> Option<(&'static Category, &'static Unit)> {
    let s = sym.to_lowercase();
    for cat in categories() {
        for u in &cat.units {
            if u.symbol == s {
                return Some((cat, u));
            }
        }
    }
    None
}

fn unknown_unit<T>(sym: &str) -> Res<T> {
    fail("UNKNOWN_UNIT", format!("'{}' is not a known unit. Try: list", sym))
}

/// A plain decimal only: optional sign, digits, optional dot. No `1e3`, no `1,000` (R16).
pub fn parse_value(s: &str) -> Res<f64> {
    let bad = || fail::<f64>("INVALID_NUMBER", format!("'{}' is not a number", s));
    let b = s.strip_prefix('-').or_else(|| s.strip_prefix('+')).unwrap_or(s);
    let (mut dot, mut digits) = (false, 0);
    for ch in b.chars() {
        if ch.is_ascii_digit() {
            digits += 1;
        } else if ch == '.' && !dot {
            dot = true;
        } else {
            return bad();
        }
    }
    if digits == 0 {
        return bad();
    }
    match s.parse::<f64>() {
        Ok(v) if v.is_finite() => Ok(v),
        Ok(_) => fail("OVERFLOW", "That number is too large"),
        Err(_) => bad(),
    }
}

/// Temperature goes through direct formulas (offsets, not factors). Only the input is
/// checked against absolute zero; the formulas are arranged so the limit maps exactly.
fn temperature(v: f64, from: &str, to: &str) -> Res<f64> {
    let limit = match from {
        "c" => -273.15,
        "f" => -459.67,
        _ => 0.0,
    };
    if v < limit {
        return fail("BELOW_ABSOLUTE_ZERO", "That is below absolute zero");
    }
    Ok(match (from, to) {
        (a, b) if a == b => v,
        ("c", "f") => v * 9.0 / 5.0 + 32.0,
        ("f", "c") => (v - 32.0) * 5.0 / 9.0,
        ("c", "k") => v + 273.15,
        ("k", "c") => v - 273.15,
        ("f", "k") => (v + 459.67) * 5.0 / 9.0,
        _ => v * 9.0 / 5.0 - 459.67, // k -> f
    })
}

fn convert_f64(v: f64, cat: &Category, from: &Unit, to: &Unit) -> Res<f64> {
    let r = if cat.name == "temperature" {
        temperature(v, from.symbol, to.symbol)?
    } else {
        v * from.factor / to.factor
    };
    if r.is_finite() {
        Ok(r)
    } else {
        fail("OVERFLOW", "Result is too large to represent")
    }
}

/// Guided-flow helper: the units are already chosen. Returns `100 m = 109.361329834 yd`.
pub fn convert_units(value: &str, from: &Unit, to: &Unit, cat: &Category) -> Res<String> {
    let v = parse_value(value)?;
    let r = convert_f64(v, cat, from, to)?;
    Ok(format!("{} {} = {} {}", format_number(v)?, from.symbol, format_number(r)?, to.symbol))
}

fn convert_symbols(value: &str, from: &str, to: &str) -> Res<String> {
    let v = parse_value(value)?;
    let (fc, fu) = match find_unit(from) {
        Some(x) => x,
        None => return unknown_unit(from),
    };
    if to.eq_ignore_ascii_case("all") {
        // Every unit of the source's category, table order, source included (R18).
        let mut lines = Vec::new();
        for u in &fc.units {
            lines.push(format!("{}: {}", u.symbol, format_number(convert_f64(v, fc, fu, u)?)?));
        }
        return Ok(lines.join("\n"));
    }
    let (tc, tu) = match find_unit(to) {
        Some(x) => x,
        None => return unknown_unit(to),
    };
    if fc.name != tc.name {
        return fail("INCOMPATIBLE_UNITS", format!("Cannot convert {} to {}", fc.name, tc.name));
    }
    format_number(convert_f64(v, fc, fu, tu)?)
}

/// One-line forms: `convert <v> <from> <to>`, `<v> <from> <to>`, `list`, `list <category>`.
pub fn run_line(line: &str) -> Res<String> {
    let w: Vec<&str> = line.split_whitespace().collect();
    if w.is_empty() {
        return fail("UNKNOWN_COMMAND", "Type a value, e.g. 100");
    }
    let first = w[0].to_lowercase();
    if first == "list" {
        return match w.len() {
            1 => Ok(categories().iter().map(|c| c.name).collect::<Vec<_>>().join(", ")),
            2 => match categories().iter().find(|c| c.name == w[1].to_lowercase()) {
                Some(c) => Ok(c.units.iter().map(|u| u.symbol).collect::<Vec<_>>().join(", ")),
                None => fail("UNKNOWN_COMMAND", format!("'{}' is not a category. Try: list", w[1])),
            },
            _ => fail("UNKNOWN_COMMAND", "Use: list  or  list <category>"),
        };
    }
    if first == "convert" {
        if w.len() != 4 {
            return fail("UNKNOWN_COMMAND", "Use: convert <value> <from> <to>");
        }
        return convert_symbols(w[1], w[2], w[3]);
    }
    if w.len() == 3 {
        return convert_symbols(w[0], w[1], w[2]);
    }
    fail("UNKNOWN_COMMAND", "Not a command. Try: convert 100 cm in")
}