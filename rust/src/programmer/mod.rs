//! Programmer Calculator: 64-bit signed two's complement on native `i64` (spec §4).
use crate::shared::{fail, Res};

/// What a command produced. The CLI turns it into text with [`Programmer::run`].
#[derive(Debug, Clone, PartialEq)]
pub enum Output {
    Value(i64),
    Text(String),
    BaseSet(&'static str),
}

pub fn radix_of(name: &str) -> Option<u32> {
    match name.to_ascii_lowercase().as_str() {
        "bin" => Some(2),
        "oct" => Some(8),
        "dec" => Some(10),
        "hex" => Some(16),
        _ => None,
    }
}

fn base_name(radix: u32) -> &'static str {
    match radix {
        2 => "bin",
        8 => "oct",
        16 => "hex",
        _ => "dec",
    }
}

/// HEX/OCT/BIN print the unsigned 64-bit pattern (spec §4.4); DEC the signed value.
pub fn format_in(v: i64, radix: u32) -> String {
    match radix {
        2 => format!("{:b}", v as u64),
        8 => format!("{:o}", v as u64),
        16 => format!("{:X}", v as u64),
        _ => v.to_string(),
    }
}

pub fn format_all(v: i64) -> String {
    format!(
        "HEX: {}\nDEC: {}\nOCT: {}\nBIN: {}",
        format_in(v, 16),
        format_in(v, 10),
        format_in(v, 8),
        format_in(v, 2)
    )
}

/// Parse a literal. Order (ARCHITECTURE.md): prefix -> digit validation -> range.
/// Digits are accumulated in a `u128` (saturating), so nothing passes through floating point.
pub fn parse_literal(text: &str, input_radix: u32) -> Res<i64> {
    let (neg, rest) = match text.strip_prefix('-') {
        Some(r) => (true, r),
        None => (false, text),
    };
    let not_number = || fail::<i64>("INVALID_NUMBER", format!("'{}' is not a number", text));
    if rest.is_empty() {
        return not_number();
    }
    let mut radix = input_radix;
    let mut body = rest;
    let b = rest.as_bytes();
    // A prefix counts only when digits follow it (R30); then it wins over the input base.
    if b.len() > 2 && b[0] == b'0' {
        let p = match b[1].to_ascii_lowercase() {
            b'b' => Some(2),
            b'o' => Some(8),
            b'd' => Some(10),
            b'x' => Some(16),
            _ => None,
        };
        if let Some(r) = p {
            radix = r;
            body = &rest[2..];
        }
    }
    if !body.chars().all(|c| c.is_ascii_alphanumeric()) {
        return not_number();
    }
    let mut acc: u128 = 0;
    for c in body.chars() {
        let d = match c.to_digit(radix) {
            Some(d) => d,
            None => {
                return fail(
                    "INVALID_DIGIT",
                    format!("'{}' is not a {} digit", c.to_ascii_uppercase(), base_name(radix)),
                )
            }
        };
        acc = acc.saturating_mul(radix as u128).saturating_add(d as u128);
    }
    if neg {
        if acc > 1u128 << 63 {
            return fail("OUT_OF_RANGE", "That number does not fit in 64 bits");
        }
        Ok((-(acc as i128)) as i64)
    } else if radix == 10 {
        if acc > i64::MAX as u128 {
            return fail("OUT_OF_RANGE", "That number does not fit in 64 bits");
        }
        Ok(acc as i64)
    } else {
        if acc > u64::MAX as u128 {
            return fail("OUT_OF_RANGE", "That number needs more than 64 bits");
        }
        Ok(acc as u64 as i64) // raw bit pattern reinterpreted as signed
    }
}

fn shift_count(s: &str) -> Res<u32> {
    let bad = || fail::<u32>("INVALID_SHIFT", "A shift count must be a whole number from 0 to 63");
    if s.is_empty() || !s.chars().all(|c| c.is_ascii_digit()) {
        return bad();
    }
    match s.parse::<u64>() {
        Ok(n) if n <= 63 => Ok(n as u32),
        _ => bad(),
    }
}

/// Split on whitespace and also around `<<`, `>>`, `>>>` so `1<<3` works (R29).
fn split_tokens(line: &str) -> Vec<String> {
    let chars: Vec<char> = line.chars().collect();
    let (mut out, mut cur, mut i) = (Vec::new(), String::new(), 0);
    while i < chars.len() {
        let c = chars[i];
        if c.is_whitespace() {
            if !cur.is_empty() {
                out.push(std::mem::take(&mut cur));
            }
            i += 1;
        } else if c == '<' || c == '>' {
            if !cur.is_empty() {
                out.push(std::mem::take(&mut cur));
            }
            let s = i;
            while i < chars.len() && chars[i] == c {
                i += 1;
            }
            out.push(chars[s..i].iter().collect());
        } else {
            cur.push(c);
            i += 1;
        }
    }
    if !cur.is_empty() {
        out.push(cur);
    }
    out
}

/// One Programmer Calculator session. It holds the input base (default `dec`).
pub struct Programmer {
    radix: u32,
}

impl Default for Programmer {
    fn default() -> Self {
        Self::new()
    }
}

impl Programmer {
    pub fn new() -> Self {
        Programmer { radix: 10 }
    }

    fn lit(&self, s: &str) -> Res<i64> {
        parse_literal(s, self.radix)
    }

    fn convert(&self, value: &str, from: &str, to: &str) -> Res<Output> {
        let bad = |x: &str| fail::<u32>("INVALID_BASE", format!("'{}' is not a base. Use bin, oct, dec or hex", x));
        let rf = match radix_of(from) {
            Some(r) => r,
            None => return bad(from).map(|_| Output::Value(0)),
        };
        let rt = match radix_of(to) {
            Some(r) => r,
            None => return bad(to).map(|_| Output::Value(0)),
        };
        Ok(Output::Text(format_in(parse_literal(value, rf)?, rt)))
    }

    pub fn execute(&mut self, line: &str) -> Res<Output> {
        let t = split_tokens(line);
        if t.is_empty() {
            return fail("UNKNOWN_COMMAND", "Type a number or a command. Try help");
        }
        let first = t[0].to_ascii_lowercase();
        if first == "base" {
            if t.len() == 2 {
                return match radix_of(&t[1]) {
                    Some(r) => {
                        self.radix = r;
                        Ok(Output::BaseSet(base_name(r)))
                    }
                    None => fail("INVALID_BASE", format!("'{}' is not a base. Use bin, oct, dec or hex", t[1])),
                };
            }
            return fail("INVALID_BASE", "Use: base bin | oct | dec | hex");
        }
        if first == "convert" {
            if t.len() != 4 {
                return fail("UNKNOWN_COMMAND", "Use: convert <value> <from> <to>");
            }
            return self.convert(&t[1], &t[2], &t[3]);
        }
        // `convert` is optional: exactly three words whose last two are base names (R24).
        if t.len() == 3 && radix_of(&t[1]).is_some() && radix_of(&t[2]).is_some() {
            return self.convert(&t[0], &t[1], &t[2]);
        }
        if first == "not" {
            if t.len() == 2 {
                return Ok(Output::Value(!self.lit(&t[1])?));
            }
            return fail("UNKNOWN_COMMAND", "Use: NOT <value>");
        }
        if t.len() == 1 {
            return Ok(Output::Value(self.lit(&t[0])?));
        }
        if t.len() == 3 {
            // The operator is always the middle word (R11).
            let op = t[1].to_ascii_lowercase();
            match op.as_str() {
                "and" | "or" | "xor" => {
                    let (a, b) = (self.lit(&t[0])?, self.lit(&t[2])?);
                    return Ok(Output::Value(match op.as_str() {
                        "and" => a & b,
                        "or" => a | b,
                        _ => a ^ b,
                    }));
                }
                "<<" | ">>" | ">>>" => {
                    let a = self.lit(&t[0])?;
                    let n = shift_count(&t[2])?;
                    return Ok(Output::Value(match op.as_str() {
                        "<<" => ((a as u64) << n) as i64, // bits past 63 are dropped, no error
                        ">>" => a >> n,                   // arithmetic (sign-extending)
                        _ => ((a as u64) >> n) as i64,    // logical (zero-filling)
                    }));
                }
                _ => {}
            }
        }
        fail("UNKNOWN_COMMAND", "Not a command. Try help")
    }

    /// Execute and render for the CLI (all four bases, a converted number, or the base note).
    pub fn run(&mut self, line: &str) -> Res<String> {
        Ok(match self.execute(line)? {
            Output::Value(v) => format_all(v),
            Output::Text(s) => s,
            Output::BaseSet(n) => format!("Input base: {}", n),
        })
    }
}